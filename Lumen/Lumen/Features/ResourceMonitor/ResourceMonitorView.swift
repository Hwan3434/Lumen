import SwiftUI

private typealias P = LumenTokens.Palette

struct ResourceMonitorView: View {
    private var monitor: AppResourceMonitor { AppResourceMonitor.shared }
    private var store: ResourceAnomalyStore { ResourceAnomalyStore.shared }
    @State private var traceOn = AppResourceMonitor.isTraceEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
                header
                currentStatsRow
                chartSection(title: "메모리", unit: "MB", values: memoryValues, max: max(memoryValues.max() ?? 1, 100))
                chartSection(title: "CPU", unit: "%", values: cpuValues, max: max(cpuValues.max() ?? 1, Double(monitor.coreCount) * 100))
                chartSection(title: "스레드", unit: "개", values: threadValues, max: max(threadValues.max() ?? 1, 20))
                anomalySection
            }
            .padding(LumenTokens.Space.s6)
        }
        .scrollIndicators(.hidden)
        .frame(width: 720, height: 860)
        .background(P.bg)
    }

    // MARK: - Anomalies

    private var anomalySection: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            HStack(spacing: LumenTokens.Space.inline) {
                Text("감지된 특이사항")
                    .lumenText(.title3)
                    .foregroundStyle(P.ink)
                Spacer()
                Text("\(store.anomalies.count)건 저장")
                    .lumenText(.caption)
                    .monospacedDigit()
                    .foregroundStyle(P.inkFaint)
                if !store.anomalies.isEmpty {
                    Button("지우기") { store.clear() }
                        .buttonStyle(LumenButtonStyle(variant: .ghost, size: .small))
                }
            }
            let recent = store.recent(6)
            if recent.isEmpty {
                HStack(spacing: LumenTokens.Space.s3) {
                    LumenIcon("circle-check")
                        .foregroundStyle(P.success)
                    VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
                        Text("이상 없어요")
                            .lumenText(.body, weight: .medium)
                            .foregroundStyle(P.ink)
                        Text("기준값을 잡은 뒤(약 60초) 감지를 시작해요.")
                            .lumenText(.caption)
                            .foregroundStyle(P.inkFaint)
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, LumenTokens.Space.s4)
                .lumenCard()
            } else {
                LumenList(recent) { anomalyRow($0) }
            }
        }
    }

    private func anomalyRow(_ a: ResourceAnomaly) -> some View {
        HStack(spacing: LumenTokens.Space.s3) {
            LumenBadge(text: kindLabel(a.kind), tone: a.severity == .alert ? .danger : .warning)
            Text(a.message)
                .lumenText(.label, weight: .regular)
                .foregroundStyle(P.ink)
                .lineLimit(1)
            Spacer()
            Text(relativeTime(a.timestamp))
                .lumenText(.caption)
                .foregroundStyle(P.inkFaint)
        }
        .padding(.vertical, LumenTokens.Space.s3)
        .padding(.horizontal, LumenTokens.Space.s4)
    }

    private func kindLabel(_ k: ResourceAnomaly.Kind) -> String {
        switch k {
        case .cpuSustained: return "CPU지속"
        case .memoryHigh:   return "메모리↑"
        case .memoryGrowth: return "메모리증가"
        case .memorySpike:  return "메모리점프"
        case .threadGrowth: return "스레드증가"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "\(s)초 전" }
        let m = s / 60
        if m < 60 { return "\(m)분 전" }
        let h = m / 60
        if h < 24 { return "\(h)시간 전" }
        return "\(h / 24)일 전"
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            HStack(spacing: LumenTokens.Space.inline) {
                LumenIcon("gauge", size: .large)
                    .foregroundStyle(P.inkMuted)
                Text("리소스 모니터")
                    .lumenText(.title2)
                    .foregroundStyle(P.ink)
                Spacer()
            }
            Text("\(monitor.history.count)개 샘플 · 5초 간격")
                .lumenText(.caption)
                .foregroundStyle(P.inkFaint)
            Toggle(isOn: Binding(
                get: { traceOn },
                set: {
                    traceOn = $0
                    AppResourceMonitor.isTraceEnabled = $0
                }
            )) {
                Text("추적 로그 기록")
            }
            .toggleStyle(LumenSwitchStyle())
            .help("메모리 구간 델타를 ~/Library/Logs/Lumen/memory_trace.log 에 기록해요. 끄면 런타임 비용이 없어요.")
        }
    }

    // MARK: - Current stats

    private var currentStatsRow: some View {
        let c = monitor.current
        return HStack(spacing: LumenTokens.Space.group) {
            statBox(title: "메모리", value: String(format: "%.0f", c.memoryMB), unit: "MB")
            statBox(title: "CPU", value: String(format: "%.1f", c.cpuPercent), unit: "% (\(monitor.coreCount)코어)",
                    warning: cpuLevel(c.cpuPercent))
            statBox(title: "스레드", value: "\(c.threadCount)", unit: "개")
        }
    }

    private func statBox(title: String, value: String, unit: String, warning: LumenTone? = nil) -> some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            HStack {
                Text(title)
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
                Spacer()
                if let warning {
                    LumenBadge(text: warning == .danger ? "높음" : "주의", tone: warning)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: LumenTokens.Space.s1) {
                Text(value)
                    .lumenText(.title2)
                    .monospacedDigit()
                    .foregroundStyle(P.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .lumenText(.label, weight: .regular)
                        .foregroundStyle(P.inkMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LumenTokens.Space.pad)
        .lumenCard()
    }

    // MARK: - Chart

    private func chartSection(title: String, unit: String, values: [Double], max: Double) -> some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .lumenText(.label)
                    .foregroundStyle(P.inkMuted)
                Spacer()
                if let last = values.last {
                    Text("\(String(format: "%.1f", last))\(unit)")
                        .lumenText(.label)
                        .monospacedDigit()
                        .foregroundStyle(P.ink)
                }
                Text("최대 \(String(format: "%.0f", max))\(unit)")
                    .lumenText(.caption)
                    .monospacedDigit()
                    .foregroundStyle(P.inkFaint)
            }
            MiniAreaChart(values: values, maxValue: max)
                .frame(height: 96)
        }
    }

    // MARK: - Derived series

    private var memoryValues: [Double] { monitor.history.map(\.memoryMB) }
    private var cpuValues: [Double]    { monitor.history.map(\.cpuPercent) }
    private var threadValues: [Double] { monitor.history.map { Double($0.threadCount) } }

    /// CPU가 높으면 상태 배지로 알린다(색만으로 구분하지 않음).
    private func cpuLevel(_ pct: Double) -> LumenTone? {
        let cores = Double(monitor.coreCount)
        if pct > cores * 30 { return .danger }
        if pct > cores * 10 { return .warning }
        return nil
    }
}

// MARK: - MiniAreaChart

/// 단일 계열 선 차트. 가로 격자선만, 선 굵기 2, 마지막 점 지름 8, 영역은 단색 옅은 바탕.
struct MiniAreaChart: View {
    let values: [Double]
    let maxValue: Double
    private let color = LumenTokens.Palette.chart1

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let range = maxValue <= 0 ? 1 : maxValue
            let count = values.count

            ZStack {
                Path { p in
                    for frac in [0.0, 0.25, 0.5, 0.75] {
                        let y = size.height * (1 - frac)
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }.stroke(LumenTokens.Palette.chartGrid, lineWidth: 1)

                if count > 1 {
                    let pts = points(size: size, range: range)

                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: size.height))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: size.height))
                        p.closeSubpath()
                    }
                    .fill(LumenTokens.Palette.brandSoft)

                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }.stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    LumenDot(color: color)
                        .position(pts.last!)
                }
            }
        }
    }

    private func points(size: CGSize, range: Double) -> [CGPoint] {
        let count = values.count
        return values.enumerated().map { i, v in
            let x = count == 1 ? size.width / 2 : size.width * CGFloat(i) / CGFloat(count - 1)
            let clamped = Swift.max(0, Swift.min(v, range))
            let y = size.height * (1 - CGFloat(clamped / range))
            return CGPoint(x: x, y: y)
        }
    }
}
