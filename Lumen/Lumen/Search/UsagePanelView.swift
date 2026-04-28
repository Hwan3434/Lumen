import SwiftUI

struct UsagePanelView: View {
    private var service: ClaudeUsageService { ClaudeUsageService.shared }

    var body: some View {
        ZStack {
            if service.isLoadingHeavy && service.heavyData == nil {
                loadingView
            } else if let heavy = service.heavyData {
                contentView(heavy: heavy, live: service.liveData)
            } else {
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(LumenTokens.Accent.violetSoft)
            Text("불러오는 중…")
                .font(.system(size: 11))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
    }

    private var emptyView: some View {
        Text("데이터 없음")
            .font(.system(size: 11))
            .foregroundStyle(LumenTokens.TextColor.muted.opacity(0.7))
    }

    // MARK: - Content

    private func contentView(heavy: HeavyUsageData, live: LiveUsageData) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                summarySection(heavy: heavy, live: live)
                divider
                sparklineSection(heavy)
                divider
                projectsSection(heavy)
                divider
                modelsSection(heavy)
                divider
                gaugeSection(live)
            }
            .padding(14)
        }
    }

    private var divider: some View {
        LumenHairline()
    }

    // MARK: - Summary

    private func summarySection(heavy: HeavyUsageData, live: LiveUsageData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LumenSectionLabel(text: "AI 사용량")
            HStack(spacing: 8) {
                statBox(title: "오늘", value: heavy.todayCalls.formatted, sub: "\(heavy.todaySessions) sessions")
                statBox(title: "이번달 토큰", value: heavy.monthTokens.formatted, sub: "\(heavy.monthCalls.formatted) calls")
            }
        }
    }

    private func statBox(title: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(LumenTokens.TextColor.muted)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.primary)
            Text(sub)
                .font(.system(size: 10))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: LumenTokens.Radius.row)
                .fill(LumenTokens.BG.card)
                .overlay(
                    RoundedRectangle(cornerRadius: LumenTokens.Radius.row)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
        )
    }

    // MARK: - Sparkline

    private func sparklineSection(_ heavy: HeavyUsageData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                LumenSectionLabel(text: "30일 호출 추이")
                Spacer()
                if let max = heavy.dailyHistory.max(by: { $0.calls < $1.calls }) {
                    Text("최대 \(max.calls.formatted)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
            }
            SparklineView(values: heavy.dailyHistory.map { Double($0.calls) })
                .frame(height: 50)
            HStack {
                Text(heavy.dailyHistory.first?.date.suffix(5).description ?? "")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                Spacer()
                Text("오늘")
                    .font(.system(size: 9))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
        }
    }

    // MARK: - Projects

    private func projectsSection(_ heavy: HeavyUsageData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LumenSectionLabel(text: "프로젝트별 토큰 (30일)")
            let maxCalls = heavy.projects.first?.calls ?? 1
            VStack(alignment: .leading, spacing: 7) {
                ForEach(heavy.projects) { proj in
                    barRow(label: proj.name, value: proj.calls, max: maxCalls)
                }
            }
        }
    }

    // MARK: - Models

    private func modelsSection(_ heavy: HeavyUsageData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                LumenSectionLabel(text: "모델별 (30일)")
                Spacer()
                Text("합계 \(formatCost(heavy.models.reduce(0) { $0 + $1.cost }))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.secondary)
            }
            let maxCalls = heavy.models.first?.calls ?? 1
            VStack(alignment: .leading, spacing: 7) {
                ForEach(heavy.models) { model in
                    barRow(
                        label: model.name,
                        value: model.calls,
                        sub: formatCost(model.cost),
                        max: maxCalls
                    )
                }
            }
        }
    }

    private func formatCost(_ cost: Double) -> String {
        if cost >= 1000 { return String(format: "$%.1fK", cost / 1000) }
        if cost >= 10   { return String(format: "$%.1f", cost) }
        if cost >= 1    { return String(format: "$%.2f", cost) }
        return String(format: "$%.3f", cost)
    }

    private func barRow(label: String, value: Int, sub: String? = nil, max: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(LumenTokens.TextColor.secondary)
                    .lineLimit(1)
                Spacer()
                Text(value.formatted)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                if let sub {
                    Text("(\(sub))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.muted.opacity(0.7))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    let ratio = CGFloat(value) / CGFloat(max)
                    Capsule()
                        .fill(barFill(ratio: ratio))
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 4)
        }
    }

    /// 짧은 bar는 그라데이션이 묻혀 보이므로 15% 미만일 땐 단색(violet)으로 둔다.
    private func barFill(ratio: CGFloat) -> AnyShapeStyle {
        if ratio < 0.15 {
            return AnyShapeStyle(LumenTokens.Accent.violet)
        }
        return AnyShapeStyle(LinearGradient(
            colors: [LumenTokens.Accent.violet, LumenTokens.Accent.amber],
            startPoint: .leading, endPoint: .trailing
        ))
    }

    // MARK: - Gauge (Claude Max 잔여)

    private func gaugeSection(_ live: LiveUsageData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LumenSectionLabel(text: "Claude Max 잔여")
            VStack(spacing: 7) {
                gaugeRow(label: "세션", pct: live.sessionPct)
                gaugeRow(label: "주간", pct: live.weeklyPct)
            }
        }
    }

    private func gaugeRow(label: String, pct: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(LumenTokens.TextColor.muted)
                .frame(width: 28, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(barFill(ratio: CGFloat(pct) / 100))
                        .frame(width: geo.size.width * CGFloat(pct) / 100)
                        .shadow(color: pct >= 80 ? LumenTokens.Accent.amberDim : .clear, radius: 4)
                }
            }
            .frame(height: 6)
            Text("\(pct)%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(LumenTokens.TextColor.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

}

// MARK: - Sparkline

struct SparklineView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let maxV = values.max() ?? 1
            let range = maxV == 0 ? 1.0 : maxV
            let count = values.count

            ZStack {
                // Subtle horizontal grid lines at 25% / 75%.
                Path { path in
                    for frac in [0.25, 0.75] {
                        let y = size.height * (1 - frac)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)

                // Filled area under the line (violet → transparent).
                Path { path in
                    guard count > 1 else { return }
                    let pts = points(size: size, range: range)
                    path.move(to: CGPoint(x: pts[0].x, y: size.height))
                    pts.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: pts.last!.x, y: size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [
                        LumenTokens.Accent.violet.opacity(0.30),
                        LumenTokens.Accent.violet.opacity(0.02),
                    ],
                    startPoint: .top, endPoint: .bottom
                ))

                // The line itself — left-to-right gradient (deep violet → soft violet).
                Path { path in
                    guard count > 1 else { return }
                    let pts = points(size: size, range: range)
                    path.move(to: pts[0])
                    pts.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            LumenTokens.Accent.violet,
                            LumenTokens.Accent.amber,
                        ],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: LumenTokens.Accent.violet.opacity(0.5), radius: 3)

                // Endpoint dot — matches the line's terminal hue (amber).
                if count > 0 {
                    let last = points(size: size, range: range).last!
                    Circle()
                        .fill(LumenTokens.Accent.amber)
                        .frame(width: 5, height: 5)
                        .shadow(color: LumenTokens.Accent.amberDim, radius: 4)
                        .position(last)
                }
            }
        }
    }

    private func points(size: CGSize, range: Double) -> [CGPoint] {
        let count = values.count
        return values.enumerated().map { i, v in
            let x = count == 1 ? size.width / 2 : size.width * CGFloat(i) / CGFloat(count - 1)
            let y = size.height * (1 - CGFloat(v / range))
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Int formatting

private extension Int {
    var formatted: String {
        let d = Double(self)
        if abs(d) >= 1e9 { return String(format: "%.1fB", d / 1e9) }
        if abs(d) >= 1e6 { return String(format: "%.1fM", d / 1e6) }
        if abs(d) >= 1e3 { return String(format: "%.1fK", d / 1e3) }
        return "\(self)"
    }
}
