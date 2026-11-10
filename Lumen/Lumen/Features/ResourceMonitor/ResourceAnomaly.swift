import Foundation
import Observation

// MARK: - Model

struct ResourceAnomaly: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let kind: Kind
    let message: String
    // snapshot 당시 수치 (참고용)
    let memoryMB: Double
    let cpuPercent: Double
    let threadCount: Int

    enum Kind: String, Codable {
        case cpuSustained    // 장시간 고부하
        case memoryHigh      // 절대 임계치 돌파
        case memoryGrowth    // baseline 대비 급증
        case memorySpike     // 직전 샘플 대비 순간 점프
        case threadGrowth    // baseline 대비 급증
    }

    var severity: Severity {
        switch kind {
        case .cpuSustained, .memoryGrowth, .memorySpike: return .warning
        case .memoryHigh, .threadGrowth:                 return .alert
        }
    }

    enum Severity { case warning, alert }
}

// MARK: - Store (디스크 영속)

@Observable
final class ResourceAnomalyStore {
    static let shared = ResourceAnomalyStore()

    private(set) var anomalies: [ResourceAnomaly] = []

    private let diskQueue = DispatchQueue(label: "com.lumen.anomaly.disk", qos: .utility)
    private let maxStored = 200

    private init() {
        loadFromDisk()
    }

    func append(_ a: ResourceAnomaly) {
        anomalies.append(a)
        if anomalies.count > maxStored {
            anomalies.removeFirst(anomalies.count - maxStored)
        }
        scheduleSave()
    }

    func clear() {
        anomalies.removeAll()
        scheduleSave()
    }

    /// 최근 순 (desc), 최대 N개
    func recent(_ limit: Int) -> [ResourceAnomaly] {
        Array(anomalies.suffix(limit).reversed())
    }

    private func loadFromDisk() {
        guard let items = LumenStorage.read([ResourceAnomaly].self, from: .resourceAnomalies) else { return }
        anomalies = items
    }

    private func scheduleSave() {
        let snapshot = anomalies
        diskQueue.async {
            LumenStorage.write(snapshot, to: .resourceAnomalies)
        }
    }
}

// MARK: - Detector

/// 새 snapshot이 도착할 때마다 규칙 검사.
/// - cpuSustained: 6샘플 연속 cores × 30% 초과 (패널이 열려 있으면 30초, 닫혀 있으면 6분)
/// - memoryHigh: 500MB / 1024MB 돌파 (각 1회)
/// - memoryGrowth: baseline 대비 +50% (1회)
/// - threadGrowth: baseline 대비 2배 (1회)
///
/// baseline은 앱 시작 60초 후 값으로 고정.
final class ResourceAnomalyDetector {
    static let shared = ResourceAnomalyDetector()

    private let startTime: Date
    private let onAnomaly: (ResourceAnomaly) -> Void

    /// 기본값은 지금 시작해서 저장소에 기록한다. 테스트는 시작 시각과 기록할 곳을 넣어
    /// 실제 `resource_anomalies.json`을 건드리지 않는다.
    init(startTime: Date = Date(),
         onAnomaly: @escaping (ResourceAnomaly) -> Void = { ResourceAnomalyStore.shared.append($0) }) {
        self.startTime = startTime
        self.onAnomaly = onAnomaly
    }

    /// CPU가 "높다"고 보는 기준(코어당 30%). 리소스 모니터의 위험 배지도 이 값을 쓴다.
    static let cpuHighThreshold = Double(ProcessInfo.processInfo.activeProcessorCount) * 30

    private var baselineMemory: Double = 0
    private var baselineThreads: Int = 0
    private var baselineEstablished = false

    private var cpuHighStreak = 0
    private var cpuAlertActive = false     // 한 번 울리면 내려갈 때까지 재알림 안 함

    private var memory500Triggered = false
    private var memory1024Triggered = false
    private var memoryGrowthTriggered = false
    private var threadGrowthTriggered = false

    // Spike 감지용 — 직전 샘플 기억
    private var previousMemory: Double = 0

    func ingest(_ s: ResourceSnapshot) {
        establishBaselineIfNeeded(s)

        detectCPUSustained(s)
        detectMemoryThresholds(s)
        detectMemoryGrowth(s)
        detectMemorySpike(s)
        detectThreadGrowth(s)

        previousMemory = s.memoryMB
    }

    private func establishBaselineIfNeeded(_ s: ResourceSnapshot) {
        guard !baselineEstablished, s.timestamp.timeIntervalSince(startTime) >= 60 else { return }
        baselineMemory = s.memoryMB
        baselineThreads = s.threadCount
        baselineEstablished = true
    }

    private func detectCPUSustained(_ s: ResourceSnapshot) {
        let threshold = Self.cpuHighThreshold
        if s.cpuPercent > threshold {
            cpuHighStreak += 1
            if cpuHighStreak >= 6 && !cpuAlertActive {
                cpuAlertActive = true
                record(.cpuSustained, s,
                       "CPU \(Int(s.cpuPercent))% 6회 연속 초과 (임계 \(Int(threshold))%)")
            }
        } else {
            cpuHighStreak = 0
            cpuAlertActive = false
        }
    }

    private func detectMemoryThresholds(_ s: ResourceSnapshot) {
        if !memory500Triggered, s.memoryMB >= 500 {
            memory500Triggered = true
            record(.memoryHigh, s, "메모리 500MB 돌파 (\(Int(s.memoryMB))MB)")
        }
        if !memory1024Triggered, s.memoryMB >= 1024 {
            memory1024Triggered = true
            record(.memoryHigh, s, "메모리 1GB 돌파 (\(Int(s.memoryMB))MB)")
        }
    }

    private func detectMemoryGrowth(_ s: ResourceSnapshot) {
        guard baselineEstablished, !memoryGrowthTriggered, baselineMemory > 0 else { return }
        let ratio = s.memoryMB / baselineMemory
        if ratio >= 1.5 {
            memoryGrowthTriggered = true
            record(.memoryGrowth, s,
                   "메모리 baseline \(Int(baselineMemory))MB → \(Int(s.memoryMB))MB (+\(Int((ratio - 1) * 100))%)")
        }
    }

    private func detectMemorySpike(_ s: ResourceSnapshot) {
        guard previousMemory > 0 else { return }
        let delta = s.memoryMB - previousMemory
        let ratio = s.memoryMB / previousMemory
        // 절대 +50MB 이상 AND 상대 +25% 이상이면 기록 (둘 다 만족)
        guard delta >= 50, ratio >= 1.25 else { return }
        record(.memorySpike, s,
               "\(Int(previousMemory))MB → \(Int(s.memoryMB))MB (+\(Int(delta))MB, 직전 측정 대비)")
    }

    private func detectThreadGrowth(_ s: ResourceSnapshot) {
        guard baselineEstablished, !threadGrowthTriggered, baselineThreads > 0 else { return }
        if s.threadCount >= baselineThreads * 2 {
            threadGrowthTriggered = true
            record(.threadGrowth, s,
                   "스레드 \(baselineThreads) → \(s.threadCount) (2배 이상)")
        }
    }

    private func record(_ kind: ResourceAnomaly.Kind, _ s: ResourceSnapshot, _ message: String) {
        onAnomaly(ResourceAnomaly(
            id: UUID(),
            timestamp: s.timestamp,
            kind: kind,
            message: message,
            memoryMB: s.memoryMB,
            cpuPercent: s.cpuPercent,
            threadCount: s.threadCount
        ))
    }
}
