import SwiftUI

private typealias P = LumenTokens.Palette

/// 캘린더 한 칸을 차지하는 막대의 표시 속성 묶음.
/// MonthGridView·TimelineView가 동일한 모양을 그리도록 둘 다 이걸로 그린다.
/// 데이터 출처(Jira/로컬/EKEvent)는 변환하는 쪽 책임 — 이 모델은 표시 속성만 담는다.
struct CalendarBarSpec {
    let title: String
    /// 계열 색. Still 차트 규칙대로 막대 앞 점에만 쓴다.
    let color: Color
    /// 막대 맨 앞에 작게 들어가는 시각 prefix (예: "9:30 AM"). nil이면 생략.
    var timePrefix: String? = nil
    /// true면 테두리를 점선으로 (로컬 이벤트 표식).
    var isDashed: Bool = false
    /// true면 본문 텍스트에 취소선 + 흐린 색.
    var isDone: Bool = false
    var help: String? = nil
}

/// 막대 셰이프. 바탕 `surface-raised` + 테두리 `border-subtle`, 앞에 계열 색 점.
/// cornerRadius/height는 호출자가 결정 (월간 vs 주간 미세 차이).
struct CalendarBarView: View {
    let spec: CalendarBarSpec
    let cornerRadius: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: LumenTokens.Space.s1) {
            Circle()
                .fill(spec.color)
                .frame(width: 8, height: 8)
            if let prefix = spec.timePrefix {
                Text(prefix)
                    .font(LumenFont.mono(LumenTextStyle.caption.size))
                    .foregroundStyle(P.inkMuted)
                    .layoutPriority(1)
            }
            Text(spec.title)
                .lumenText(.caption, weight: .medium)
                .foregroundStyle(spec.isDone ? P.inkFaint : P.ink)
                .strikethrough(spec.isDone, color: P.inkFaint)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(height: height, alignment: .leading)
        .background(LumenShape.rect(cornerRadius).fill(P.surfaceRaised))
        .overlay(
            LumenShape.rect(cornerRadius)
                .strokeBorder(
                    spec.isDashed ? P.borderStrong : P.borderSubtle,
                    style: StrokeStyle(lineWidth: 1, dash: spec.isDashed ? [3, 2] : [])
                )
        )
        .help(spec.help ?? spec.title)
    }
}

extension CalendarItem {
    /// CalendarItem → CalendarBarSpec 변환. 막대 자체에 필요한 표시 속성만 추출.
    /// 클릭/popover 등 동작은 호출하는 뷰가 별도로 처리.
    func barSpec() -> CalendarBarSpec {
        let resolvedColor = customColor ?? projectKey.map { jiraProjectColor($0) } ?? kind.color
        let prefix: String? = hasTimeOfDay ? Self.timePrefix(for: start) : nil
        return CalendarBarSpec(
            title: title,
            color: resolvedColor,
            timePrefix: prefix,
            isDashed: kind == .local,
            isDone: isDone,
            help: issueKey.map { "\($0) · \(title)" } ?? title
        )
    }

    /// 분이 0이면 "10 AM", 아니면 "9:30 AM" — 정각은 prefix를 더 짧게.
    private static let timePrefixHourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h a"
        return f
    }()

    private static let timePrefixFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    private static func timePrefix(for date: Date) -> String {
        let minute = Calendar.current.component(.minute, from: date)
        let formatter = (minute == 0) ? timePrefixHourFormatter : timePrefixFormatter
        return formatter.string(from: date)
    }
}
