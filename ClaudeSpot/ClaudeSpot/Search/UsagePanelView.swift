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
        .onAppear {
            Task { await service.fetchLive() }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView().scaleEffect(0.7).tint(.gray)
            Text("불러오는 중...").font(.system(size: 11)).foregroundColor(.gray)
        }
    }

    private var emptyView: some View {
        Text("데이터 없음").font(.system(size: 11)).foregroundColor(.gray.opacity(0.5))
    }

    // MARK: - Content

    private func contentView(heavy: HeavyUsageData, live: LiveUsageData) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
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
            .padding(12)
        }
    }

    private var divider: some View {
        Divider().background(Color.gray.opacity(0.2))
    }

    // MARK: - Summary

    private func summarySection(heavy: HeavyUsageData, live: LiveUsageData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("AI 사용량")
            HStack(spacing: 6) {
                statBox(title: "오늘", value: live.todayCalls.formatted, sub: "\(heavy.todaySessions) sessions")
                statBox(title: "이번달", value: heavy.monthCalls.formatted, sub: "30일")
            }
        }
    }

    private func statBox(title: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundColor(.gray)
            Text(value).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            Text(sub).font(.system(size: 10)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Sparkline

    private func sparklineSection(_ heavy: HeavyUsageData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionLabel("30일 호출 추이")
                Spacer()
                if let max = heavy.dailyHistory.max(by: { $0.calls < $1.calls }) {
                    Text("최대 \(max.calls.formatted)")
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
            }
            SparklineView(values: heavy.dailyHistory.map { Double($0.calls) })
                .frame(height: 50)
            HStack {
                Text(heavy.dailyHistory.first?.date.suffix(5).description ?? "")
                    .font(.system(size: 9)).foregroundColor(.gray)
                Spacer()
                Text("오늘").font(.system(size: 9)).foregroundColor(.gray)
            }
        }
    }

    // MARK: - Projects

    private func projectsSection(_ heavy: HeavyUsageData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("프로젝트별 (30일)")
            let maxCalls = heavy.projects.first?.calls ?? 1
            ForEach(heavy.projects) { proj in
                barRow(label: proj.name, value: proj.calls, max: maxCalls, color: .blue.opacity(0.6))
            }
        }
    }

    // MARK: - Models

    private func modelsSection(_ heavy: HeavyUsageData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("모델별 (30일)")
            let maxCalls = heavy.models.first?.calls ?? 1
            ForEach(heavy.models) { model in
                barRow(
                    label: model.name,
                    value: model.calls,
                    max: maxCalls,
                    color: model.name.contains("Opus") ? .purple.opacity(0.7) : .cyan.opacity(0.6)
                )
            }
        }
    }

    private func barRow(label: String, value: Int, max: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                Text(value.formatted)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / CGFloat(max))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Gauge (Claude Max 잔여) — 최하단

    private func gaugeSection(_ live: LiveUsageData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Claude Max 잔여")
            gaugeRow(label: "세션", pct: live.sessionPct)
            gaugeRow(label: "주간", pct: live.weeklyPct)
        }
    }

    private func gaugeRow(label: String, pct: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11)).foregroundColor(.gray)
                .frame(width: 28, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gaugeColor(pct))
                        .frame(width: geo.size.width * CGFloat(pct) / 100)
                }
            }
            .frame(height: 6)
            Text("\(pct)%")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func gaugeColor(_ pct: Int) -> Color {
        if pct >= 80 { return .red.opacity(0.8) }
        if pct >= 50 { return .orange.opacity(0.8) }
        return .green.opacity(0.7)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
    }
}

// MARK: - SparklineView

struct SparklineView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let maxV = values.max() ?? 1
            let range = maxV == 0 ? 1.0 : maxV
            let count = values.count

            ZStack {
                Path { path in
                    for frac in [0.25, 0.75] {
                        let y = size.height * (1 - frac)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)

                Path { path in
                    guard count > 1 else { return }
                    let pts = points(size: size, range: range)
                    path.move(to: CGPoint(x: pts[0].x, y: size.height))
                    pts.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: pts.last!.x, y: size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.3), .blue.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))

                Path { path in
                    guard count > 1 else { return }
                    let pts = points(size: size, range: range)
                    path.move(to: pts[0])
                    pts.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(Color.blue.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

                if count > 0 {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 5, height: 5)
                        .position(points(size: size, range: range).last!)
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
        self >= 1000 ? String(format: "%.1fK", Double(self) / 1000) : "\(self)"
    }
}
