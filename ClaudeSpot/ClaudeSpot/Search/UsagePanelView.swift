import SwiftUI

struct UsagePanelView: View {
    @State private var service = ClaudeUsageService()

    var body: some View {
        ZStack {
            if service.isLoading && service.data == nil {
                loadingView
            } else if let data = service.data {
                contentView(data)
            } else {
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await service.fetch()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.gray)
            Text("불러오는 중...")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }

    private var emptyView: some View {
        Text("데이터 없음")
            .font(.system(size: 11))
            .foregroundColor(.gray.opacity(0.5))
    }

    // MARK: - Content

    private func contentView(_ data: ClaudeUsageData) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                summarySection(data)
                Divider().background(Color.gray.opacity(0.2))
                sparklineSection(data)
                Divider().background(Color.gray.opacity(0.2))
                projectsSection(data)
                Divider().background(Color.gray.opacity(0.2))
                gaugeSection(data)
            }
            .padding(12)
        }
    }

    // MARK: - Summary

    private func summarySection(_ data: ClaudeUsageData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("AI 사용량")
            HStack(spacing: 0) {
                statBox(title: "오늘", value: "\(data.todayCalls)", sub: "\(data.todaySessions) sessions")
                statBox(title: "이번달", value: "\(data.monthCalls.formatted)", sub: "30일")
            }
        }
    }

    private func statBox(title: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text(sub)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Sparkline

    private func sparklineSection(_ data: ClaudeUsageData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionLabel("30일 호출 추이")
                Spacer()
                if let max = data.dailyHistory.max(by: { $0.calls < $1.calls }) {
                    Text("최대 \(max.calls.formatted)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            SparklineView(values: data.dailyHistory.map { Double($0.calls) })
                .frame(height: 50)
            HStack {
                Text(data.dailyHistory.first?.date.suffix(5).description ?? "")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                Spacer()
                Text(data.dailyHistory.last?.date.suffix(5).description ?? "오늘")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Projects

    private func projectsSection(_ data: ClaudeUsageData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("프로젝트별 (30일)")
            let maxCalls = data.projects.first?.calls ?? 1
            ForEach(data.projects) { proj in
                projectRow(proj, maxCalls: maxCalls)
            }
        }
    }

    private func projectRow(_ proj: ProjectUsage, maxCalls: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(proj.name)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                Text(proj.calls.formatted)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(proj.calls) / CGFloat(maxCalls))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Gauge (session / weekly)

    private func gaugeSection(_ data: ClaudeUsageData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Claude Max 잔여")
            gaugeRow(label: "세션", pct: data.sessionPct)
            gaugeRow(label: "주간", pct: data.weeklyPct)
        }
    }

    private func gaugeRow(label: String, pct: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .frame(width: 28, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
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
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.gray)
            .textCase(.uppercase)
    }
}

// MARK: - SparklineView

struct SparklineView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let maxV = values.max() ?? 1
            let minV = 0.0
            let range = maxV - minV == 0 ? 1 : maxV - minV
            let count = values.count

            ZStack {
                // 배경 그리드 (선 2개)
                Path { path in
                    for frac in [0.25, 0.75] {
                        let y = size.height * (1 - frac)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)

                // 채우기 영역
                Path { path in
                    guard count > 1 else { return }
                    let points = chartPoints(values: values, size: size, minV: minV, range: range)
                    path.move(to: CGPoint(x: points[0].x, y: size.height))
                    for pt in points { path.addLine(to: pt) }
                    path.addLine(to: CGPoint(x: points.last!.x, y: size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // 선
                Path { path in
                    guard count > 1 else { return }
                    let points = chartPoints(values: values, size: size, minV: minV, range: range)
                    path.move(to: points[0])
                    for pt in points.dropFirst() { path.addLine(to: pt) }
                }
                .stroke(Color.blue.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

                // 마지막 점 강조
                if count > 0 {
                    let points = chartPoints(values: values, size: size, minV: minV, range: range)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 5, height: 5)
                        .position(points.last!)
                }
            }
        }
    }

    private func chartPoints(values: [Double], size: CGSize, minV: Double, range: Double) -> [CGPoint] {
        let count = values.count
        return values.enumerated().map { i, v in
            let x = count == 1 ? size.width / 2 : size.width * CGFloat(i) / CGFloat(count - 1)
            let y = size.height * (1 - CGFloat((v - minV) / range))
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Int formatting

private extension Int {
    var formatted: String {
        if self >= 1000 { return String(format: "%.1fK", Double(self) / 1000) }
        return "\(self)"
    }
}
