import SwiftUI

struct TrendChart: View {
    let created: [JiraIssue]
    let completed: [JiraIssue]

    var body: some View {
        let createdCounts = dailyCounts(created, dateOf: { $0.created })
        let completedCounts = dailyCounts(completed, dateOf: { $0.resolutionDate })
        let max = Swift.max(1, (createdCounts + completedCounts).max() ?? 1)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dates = (0..<30).map { cal.date(byAdding: .day, value: $0 - 29, to: today) ?? today }

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                Text("30일 일별 추이")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.0)
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .textCase(.uppercase)
            }

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach([0.33, 0.67], id: \.self) { frac in
                        Path { p in
                            let y = geo.size.height * (1 - CGFloat(frac))
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(LumenTokens.JiraTrendTone.grid)
                    }

                    Canvas { ctx, size in
                        let slotW = size.width / 30
                        let barW = Swift.max((slotW - 5) / 2, 2)
                        for i in 0..<30 {
                            let cx = CGFloat(i) * slotW + slotW / 2
                            if createdCounts[i] > 0 {
                                let bh = Swift.max(size.height * CGFloat(createdCounts[i]) / CGFloat(max), 1.5)
                                ctx.fill(
                                    Path(roundedRect: CGRect(x: cx - barW - 1, y: size.height - bh, width: barW, height: bh),
                                         cornerSize: CGSize(width: 1.5, height: 1.5)),
                                    with: .color(LumenTokens.JiraTrendTone.created.opacity(0.85))
                                )
                            }
                            if completedCounts[i] > 0 {
                                let bh = Swift.max(size.height * CGFloat(completedCounts[i]) / CGFloat(max), 1.5)
                                ctx.fill(
                                    Path(roundedRect: CGRect(x: cx + 1, y: size.height - bh, width: barW, height: bh),
                                         cornerSize: CGSize(width: 1.5, height: 1.5)),
                                    with: .color(LumenTokens.JiraTrendTone.completed.opacity(0.85))
                                )
                            }
                        }
                    }
                }
            }
            .frame(height: 60)

            HStack(spacing: 0) {
                ForEach(0..<30) { i in
                    if i % 5 == 0 || i == 29 {
                        Text(LumenDateFormat.monthDay.string(from: dates[i]))
                            .font(.system(size: 8.5, design: .monospaced))
                            .tracking(0.2)
                            .foregroundStyle(LumenTokens.TextColor.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 12)
        }
        .padding(EdgeInsets(top: 8, leading: 18, bottom: 12, trailing: 18))
        .frame(height: 102)
        .background(Color.black.opacity(0.10))
        .overlay(alignment: .top) {
            Rectangle().fill(LumenTokens.divider).frame(height: 0.5)
        }
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
