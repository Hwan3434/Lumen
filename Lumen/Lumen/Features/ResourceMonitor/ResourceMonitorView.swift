import SwiftUI

struct ResourceMonitorView: View {
    private var monitor: AppResourceMonitor { AppResourceMonitor.shared }
    private var store: ResourceAnomalyStore { ResourceAnomalyStore.shared }
    @State private var traceOn = AppResourceMonitor.isTraceEnabled

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.12).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                header
                currentStatsRow
                chartSection(title: "메모리 (MB)", color: .blue,  values: memoryValues, max: max(memoryValues.max() ?? 1, 100))
                chartSection(title: "CPU %",      color: .orange, values: cpuValues,    max: max(cpuValues.max() ?? 1, Double(monitor.coreCount) * 100))
                chartSection(title: "스레드",      color: .green,  values: threadValues, max: max(threadValues.max() ?? 1, 20))
                anomalySection
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(width: 560, height: 680)
    }

    // MARK: - Anomalies

    private var anomalySection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 10)).foregroundColor(.yellow.opacity(0.8))
                Text("감지된 특이사항").font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
                Spacer()
                Text("총 \(store.anomalies.count)건 저장")
                    .font(.system(size: 9)).foregroundColor(.gray.opacity(0.5))
                if !store.anomalies.isEmpty {
                    Button("지우기") { store.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 9))
                        .foregroundColor(.blue.opacity(0.7))
                }
            }
            let recent = store.recent(6)
            if recent.isEmpty {
                Text("이상 없음 · baseline 확립 후 감지 시작 (~60초)")
                    .font(.system(size: 10)).foregroundColor(.gray.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8)
            } else {
                VStack(spacing: 1) {
                    ForEach(recent) { a in anomalyRow(a) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private func anomalyRow(_ a: ResourceAnomaly) -> some View {
        HStack(spacing: 6) {
            Circle().fill(severityColor(a.severity)).frame(width: 5, height: 5)
            Text(kindLabel(a.kind))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(severityColor(a.severity).opacity(0.9))
                .frame(width: 52, alignment: .leading)
            Text(a.message)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Text(relativeTime(a.timestamp))
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.6))
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.white.opacity(0.03))
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

    private func severityColor(_ s: ResourceAnomaly.Severity) -> Color {
        switch s {
        case .alert:   return .red.opacity(0.85)
        case .warning: return .orange.opacity(0.85)
        case .info:    return .blue.opacity(0.7)
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
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 14)).foregroundColor(.orange.opacity(0.85))
            Text("리소스 모니터").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
            Spacer()

            Toggle("trace 로그", isOn: Binding(
                get: { traceOn },
                set: {
                    traceOn = $0
                    AppResourceMonitor.isTraceEnabled = $0
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.system(size: 10))
            .foregroundColor(.gray)
            .help("메모리 구간 델타를 ~/Library/Logs/Lumen/memory_trace.log 에 기록. 끄면 런타임 비용 0.")

            Text("\(monitor.history.count) samples · 5s 간격")
                .font(.system(size: 10)).foregroundColor(.gray.opacity(0.6))
        }
    }

    // MARK: - Current stats

    private var currentStatsRow: some View {
        let c = monitor.current
        return HStack(spacing: 8) {
            statBox(title: "메모리", value: String(format: "%.0f", c.memoryMB), unit: "MB", color: .blue)
            statBox(title: "CPU",    value: String(format: "%.1f", c.cpuPercent), unit: "% (\(monitor.coreCount)c)", color: cpuColor(c.cpuPercent))
            statBox(title: "스레드", value: "\(c.threadCount)", unit: "", color: .green)
        }
    }

    private func statBox(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundColor(.gray)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 10)).foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Chart

    private func chartSection(title: String, color: Color, values: [Double], max: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
                Spacer()
                if let last = values.last {
                    Text(String(format: "%.1f", last)).font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                }
                Text("최대 \(String(format: "%.0f", max))")
                    .font(.system(size: 9)).foregroundColor(.gray.opacity(0.5))
            }
            MiniAreaChart(values: values, maxValue: max, color: color)
                .frame(height: 70)
        }
    }

    // MARK: - Derived series

    private var memoryValues: [Double] { monitor.history.map(\.memoryMB) }
    private var cpuValues: [Double]    { monitor.history.map(\.cpuPercent) }
    private var threadValues: [Double] { monitor.history.map { Double($0.threadCount) } }

    private func cpuColor(_ pct: Double) -> Color {
        let cores = Double(monitor.coreCount)
        if pct > cores * 30 { return .red.opacity(0.9) }
        if pct > cores * 10 { return .orange }
        return .green.opacity(0.8)
    }
}

// MARK: - MiniAreaChart

struct MiniAreaChart: View {
    let values: [Double]
    let maxValue: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let range = maxValue <= 0 ? 1 : maxValue
            let count = values.count

            ZStack {
                Path { p in
                    for frac in [0.25, 0.5, 0.75] {
                        let y = size.height * (1 - frac)
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }.stroke(Color.white.opacity(0.04), lineWidth: 0.5)

                if count > 1 {
                    let pts = points(size: size, range: range)

                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: size.height))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [color.opacity(0.35), color.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ))

                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }.stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))

                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
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
