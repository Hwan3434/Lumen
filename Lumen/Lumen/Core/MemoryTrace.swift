import Foundation
import Darwin

/// 진단용 메모리 추적 로그 (구간별 RSS 델타 로깅).
/// 리소스 모니터 화면에서 켜고 끈다. 어느 층에서든 부를 수 있도록 Core 에 둔다.
enum MemoryTrace {
    private static let enabledKey = "memory_trace_enabled"
    private static let queue = DispatchQueue(label: "com.lumen.memory.trace", qos: .utility)
    private static var lastMB: Double = 0
    private static var start: Date = Date()

    /// 로그 파일 경로 (UI에서 보여주고 싶을 때).
    static let logURL: URL = LumenStorage.logsURL.appendingPathComponent("memory_trace.log")

    // record() hot path에서 UserDefaults를 매번 읽지 않기 위한 in-memory mirror.
    // 관측된 이슈: 외부 프로세스가 plist를 업데이트한 뒤에도 내 프로세스 UserDefaults 캐시가
    // 값을 반영하지 않아 `defaults read`와 앱 내부 읽기가 어긋나는 상황이 있었음.
    private static var _isEnabled: Bool = UserDefaults.standard.bool(forKey: enabledKey)

    static var isEnabled: Bool {
        get { _isEnabled }
        set {
            _isEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }

    /// 현재 프로세스 RSS를 측정하고, 이전 기록 대비 델타와 함께 파일에 기록한다.
    /// 앱 시작부터의 누적 시간(초)도 같이 남겨 타임라인 확인 가능.
    /// `isEnabled=false`면 즉시 리턴(RSS 측정도 스킵) → 런타임 비용 0에 가까움.
    static func record(_ tag: String) {
        guard isEnabled else { return }
        let mb = residentMemoryMB()
        queue.async {
            let elapsed = Date().timeIntervalSince(start)
            let delta = mb - lastMB
            let deltaStr = delta == mb ? "   start" : String(format: "%+7.1f", delta)
            let line = String(format: "T+%6.2fs  %7.1fMB  Δ%@  %@\n", elapsed, mb, deltaStr, tag)
            lastMB = mb
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
    static func reset() {
        guard isEnabled else { return }
        queue.async {
            start = Date()
            lastMB = 0
            let header = "=== trace session started at \(Date()) ===\n"
            try? header.data(using: .utf8)?.write(to: logURL)
        }
    }

    /// 현재 프로세스의 resident size (MB). 리소스 모니터 샘플링도 이 함수를 쓴다.
    static func residentMemoryMB() -> Double {
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
}
