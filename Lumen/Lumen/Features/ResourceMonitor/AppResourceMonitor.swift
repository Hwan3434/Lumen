import Foundation
import Darwin
import Observation

struct ResourceSnapshot: Identifiable {
    var id: Date { timestamp }
    let timestamp: Date
    let memoryMB: Double      // Resident size
    let cpuPercent: Double    // 전체 코어 합산 (0 ~ cores × 100)
    let threadCount: Int
}

/// 자기 프로세스의 CPU/메모리/스레드를 주기적으로 샘플링한다.
/// 메인 UI는 `current` 및 `history` 관측으로 실시간/히스토리 표시.
@Observable
final class AppResourceMonitor {
    static let shared = AppResourceMonitor()

    private(set) var current: ResourceSnapshot = ResourceSnapshot(
        timestamp: Date(), memoryMB: 0, cpuPercent: 0, threadCount: 0
    )

    private(set) var history: [ResourceSnapshot] = []
    private let capacity = 720

    /// 패널이 떠 있을 때의 샘플링 간격 — 실시간 그래프가 움직여야 하므로 촘촘하게.
    private let foregroundInterval: TimeInterval = 5
    /// 패널이 닫혀 있을 때의 간격. 메뉴바 상주 앱이라 이 타이머는 앱 수명 내내 돈다.
    /// 백그라운드에서 5초마다 task_threads()를 두 번씩 부를 이유는 없다 —
    /// 이때 필요한 건 실시간성이 아니라 누수 추세 감지뿐이라 1분이면 충분하다.
    private let backgroundInterval: TimeInterval = 60

    private var timer: Timer?
    private var isForeground = false
    private let cores: Int = ProcessInfo.processInfo.activeProcessorCount

    /// 코어 수 (UI에서 CPU% 스케일 표시용)
    var coreCount: Int { cores }

    private init() {}

    func start() {
        guard timer == nil else { return }
        sampleAndStore()
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 모니터 패널이 열리고 닫힐 때 호출 — 샘플링 간격을 전환한다.
    func setForeground(_ foreground: Bool) {
        guard isForeground != foreground else { return }
        isForeground = foreground
        guard timer != nil else { return }
        if foreground { sampleAndStore() }   // 패널을 열자마자 최신 값이 보이도록
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = isForeground ? foregroundInterval : backgroundInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sampleAndStore()
        }
    }

    private func sampleAndStore() {
        let snap = Self.snapshot()
        current = snap
        history.append(snap)
        if history.count > capacity {
            history.removeFirst(history.count - capacity)
        }
        ResourceAnomalyDetector.shared.ingest(snap)
    }

    // MARK: - Mach API sampling

    static func snapshot() -> ResourceSnapshot {
        ResourceSnapshot(
            timestamp: Date(),
            memoryMB:    residentMemoryMB(),
            cpuPercent:  taskCPUPercent(),
            threadCount: threadCount()
        )
    }

    private static func residentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1024 / 1024
    }

    private static func taskCPUPercent() -> Double {
        var threadList: thread_act_array_t?
        var count = mach_msg_type_number_t(0)
        guard task_threads(mach_task_self_, &threadList, &count) == KERN_SUCCESS,
              let threads = threadList else { return 0 }

        defer {
            for i in 0..<Int(count) {
                mach_port_deallocate(mach_task_self_, threads[i])
            }
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: threads)),
                          vm_size_t(Int(count) * MemoryLayout<thread_t>.size))
        }

        var totalUsage: Double = 0
        for i in 0..<Int(count) {
            var thInfo = thread_basic_info()
            var thCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            let kr = withUnsafeMutablePointer(to: &thInfo) { ptr -> kern_return_t in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(thCount)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &thCount)
                }
            }
            guard kr == KERN_SUCCESS else { continue }
            if (thInfo.flags & TH_FLAGS_IDLE) == 0 {
                totalUsage += Double(thInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }
        return totalUsage
    }

    // MARK: - Memory trace (구간별 델타 로깅)

    private static let traceEnabledKey = "memory_trace_enabled"
    private static let traceQueue = DispatchQueue(label: "com.lumen.memory.trace", qos: .utility)
    private static var lastTraceMB: Double = 0
    private static var traceStart: Date = Date()
    private static let logURL: URL = LumenStorage.logsURL.appendingPathComponent("memory_trace.log")

    // trace() hot path에서 UserDefaults를 매번 읽지 않기 위한 in-memory mirror.
    // 관측된 이슈: 외부 프로세스가 plist를 업데이트한 뒤에도 내 프로세스 UserDefaults 캐시가
    // 값을 반영하지 않아 `defaults read`와 앱 내부 읽기가 어긋나는 상황이 있었음.
    private static var _isTraceEnabled: Bool = UserDefaults.standard.bool(forKey: traceEnabledKey)

    static var isTraceEnabled: Bool {
        get { _isTraceEnabled }
        set {
            _isTraceEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: traceEnabledKey)
        }
    }

    /// 로그 파일 경로 (UI에서 보여주고 싶을 때).
    static var traceLogURL: URL { logURL }

    /// 현재 프로세스 RSS를 측정하고, 이전 trace 대비 델타와 함께 파일에 기록한다.
    /// 앱 시작부터의 누적 시간(초)도 같이 남겨 타임라인 확인 가능.
    /// `isTraceEnabled=false`면 즉시 리턴(RSS 측정도 스킵) → 런타임 비용 0에 가까움.
    static func trace(_ tag: String) {
        guard isTraceEnabled else { return }
        let mb = residentMemoryMB()
        traceQueue.async {
            let elapsed = Date().timeIntervalSince(traceStart)
            let delta = mb - lastTraceMB
            let deltaStr = delta == mb ? "   start" : String(format: "%+7.1f", delta)
            let line = String(format: "T+%6.2fs  %7.1fMB  Δ%@  %@\n", elapsed, mb, deltaStr, tag)
            lastTraceMB = mb
            if let data = line.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                } else {
                    try? data.write(to: logURL)
                }
            }
        }
    }

    /// 새 세션 시작 — 로그 파일 초기화 + 타이머 리셋
    static func resetTrace() {
        guard isTraceEnabled else { return }
        traceQueue.async {
            traceStart = Date()
            lastTraceMB = 0
            let header = "=== trace session started at \(Date()) ===\n"
            try? header.data(using: .utf8)?.write(to: logURL)
        }
    }

    private static func threadCount() -> Int {
        var threadList: thread_act_array_t?
        var count = mach_msg_type_number_t(0)
        guard task_threads(mach_task_self_, &threadList, &count) == KERN_SUCCESS,
              let threads = threadList else { return 0 }
        defer {
            for i in 0..<Int(count) {
                mach_port_deallocate(mach_task_self_, threads[i])
            }
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: threads)),
                          vm_size_t(Int(count) * MemoryLayout<thread_t>.size))
        }
        return Int(count)
    }
}
