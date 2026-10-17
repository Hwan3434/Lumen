import SwiftUI

private typealias P = LumenTokens.Palette

/// 30일 생성·완료 막대 차트. 범주 색 chart-1(생성)·chart-2(완료), 가로 격자선만,
/// 막대 끝 4 둥글게(바닥은 각지게), 이웃 막대 사이 2px 틈. 마우스를 올리면 그날 값을 보여준다.
struct TrendChart: View {
    let created: [JiraIssue]
    let completed: [JiraIssue]

    @State private var hoverIndex: Int?

    var body: some View {
        let createdCounts = dailyCounts(created, dateOf: { $0.created })
        let completedCounts = dailyCounts(completed, dateOf: { $0.resolutionDate })
        let max = Swift.max(1, (createdCounts + completedCounts).max() ?? 1)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dates = (0..<30).map { cal.date(byAdding: .day, value: $0 - 29, to: today) ?? today }

        return VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            HStack(spacing: LumenTokens.Space.inline) {
                LumenIcon("chart-column", size: .small)
                    .foregroundStyle(P.inkMuted)
                Text("30일 일별 추이")
                    .lumenText(.label)
                    .foregroundStyle(P.inkMuted)
            }

            GeometryReader { geo in
                let slotW = geo.size.width / 30
                ZStack(alignment: .topLeading) {
                    ForEach([0.0, 0.5, 1.0], id: \.self) { frac in
                        Path { p in
                            let y = geo.size.height * (1 - CGFloat(frac))
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(P.chartGrid, lineWidth: 1)
                    }

                    Canvas { ctx, size in
                        let barW = Swift.max((slotW - 6) / 2, 2)
                        for i in 0..<30 {
                            let cx = CGFloat(i) * slotW + slotW / 2
                            for (count, x, color) in [(createdCounts[i], cx - barW - 1, P.chart1),
                                                      (completedCounts[i], cx + 1, P.chart2)] where count > 0 {
                                let bh = Swift.max(size.height * CGFloat(count) / CGFloat(max), 2)
                                let rect = CGRect(x: x, y: size.height - bh, width: barW, height: bh)
                                let r = Swift.min(4, barW / 2)
                                let path = UnevenRoundedRectangle(cornerRadii: .init(topLeading: r, bottomLeading: 0,
                                                                                    bottomTrailing: 0, topTrailing: r))
                                    .path(in: rect)
                                ctx.fill(path, with: .color(color))
                            }
                        }
                    }

                    if let i = hoverIndex {
                        tooltip(date: dates[i], created: createdCounts[i], completed: completedCounts[i])
                            .fixedSize()
                            .position(x: Swift.min(Swift.max(CGFloat(i) * slotW + slotW / 2, 80), geo.size.width - 80),
                                      y: 0)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let pt):
                        hoverIndex = Swift.min(29, Swift.max(0, Int(pt.x / slotW)))
                    case .ended:
                        hoverIndex = nil
                    }
                }
            }
            .frame(height: LumenTokens.Space.size(80))

            HStack(spacing: 0) {
                ForEach(0..<30) { i in
                    if i % 5 == 0 || i == 29 {
                        Text(LumenDateFormat.monthDay.string(from: dates[i]))
                            .lumenText(.caption)
                            .monospacedDigit()
                            .foregroundStyle(P.chartAxis)
                            .fixedSize()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: LumenTokens.Space.scaled(16))
        }
        .padding(.horizontal, LumenTokens.Space.pad)
        .padding(.vertical, LumenTokens.Space.s4)
        .background(P.panelSurface)
        .overlay(alignment: .top) { LumenHairline() }
    }

    private func tooltip(date: Date, created: Int, completed: Int) -> some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
            Text(LumenDateFormat.monthDay.string(from: date))
                .lumenText(.caption)
                .foregroundStyle(P.inkFaint)
            HStack(spacing: LumenTokens.Space.s3) {
                LegendDot(color: P.chart1, label: "생성 \(created)")
                LegendDot(color: P.chart2, label: "완료 \(completed)")
            }
        }
        .padding(.vertical, LumenTokens.Space.inline)
        .padding(.horizontal, LumenTokens.Space.s3)
        .lumenPopover()
    }

    private func dailyCounts(_ issues: [JiraIssue], dateOf: (JiraIssue) -> Date?) -> [Int] {
        var counts = Array(repeating: 0, count: 30)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for i in issues {
            guard let date = dateOf(i) else { continue }
            let diff = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: today).day ?? -1
            guard diff >= 0 && diff < 30 else { continue }
            counts[29 - diff] += 1
        }
        return counts
    }
}
