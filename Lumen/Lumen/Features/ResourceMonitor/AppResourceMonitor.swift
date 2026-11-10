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
    /// 백그라운드에서 5초마다 task_threads()를 부를 이유는 없다 —
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
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sampleAndStore()
        }
        // 정확한 시각이 필요 없는 측정이라, 시스템이 다른 깨어남과 묶을 수 있게 여유를 준다.
        timer.tolerance = interval / 5
        self.timer = timer
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
        let usage = threadUsage()
        return ResourceSnapshot(
            timestamp: Date(),
            memoryMB:    MemoryTrace.residentMemoryMB(),
            cpuPercent:  usage.cpuPercent,
            threadCount: usage.threadCount
        )
    }

    /// 스레드 목록을 한 번만 받아 CPU 합계(쉬는 스레드 제외)와 스레드 수를 같이 낸다.
    private static func threadUsage() -> (cpuPercent: Double, threadCount: Int) {
        var threadList: thread_act_array_t?
        var count = mach_msg_type_number_t(0)
        guard task_threads(mach_task_self_, &threadList, &count) == KERN_SUCCESS,
              let threads = threadList else { return (0, 0) }

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
        return (totalUsage, Int(count))
    }
}
