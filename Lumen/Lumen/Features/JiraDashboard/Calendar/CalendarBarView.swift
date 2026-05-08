import SwiftUI

/// 캘린더 한 칸을 차지하는 막대의 표시 속성 묶음.
/// MonthGridView·TimelineView가 동일한 모양을 그리도록 둘 다 이걸로 그린다.
/// 데이터 출처(Jira/로컬/EKEvent)는 변환하는 쪽 책임 — 이 모델은 표시 속성만 담는다.
struct CalendarBarSpec {
    let title: String
    let color: Color
    /// true면 stroke를 점선으로 (로컬 이벤트 표식).
    var isDashed: Bool = false
    /// true면 본문 텍스트에 취소선 + muted 색.
    var isDone: Bool = false
    /// 본문 텍스트가 mid-tone이어야 하는지 (로컬 이벤트는 secondary, 그 외 primary).
    var useSecondaryText: Bool = false
    /// 좌측 색 점 표시 여부 — 막대 자체 색이 정체성을 충분히 알려주면 false (EKCalendar 등).
    var showDot: Bool = true
    /// 점에 들어갈 색 — kind별 강조 색이 들어옴. nil이면 막대 색을 그대로 사용.
    var dotColor: Color? = nil
    /// 배경 fill 위에 깔 색 — 로컬 이벤트는 거의 투명한 흰색 톤, 일반은 막대 색의 22%.
    /// nil이면 color.opacity(0.22) 자동.
    var customFill: Color? = nil
    /// stroke 색 오버라이드 — 로컬 이벤트는 muted, 일반은 막대 색의 45%. nil이면 자동.
    var customStroke: Color? = nil
    var help: String? = nil
}

/// 막대 셰이프. cornerRadius/laneHeight는 호출자가 결정 (월간 vs 주간 미세 차이).
struct CalendarBarView: View {
    let spec: CalendarBarSpec
    let cornerRadius: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            if spec.showDot {
                Circle()
                    .fill(spec.dotColor ?? spec.color)
                    .frame(width: 5, height: 5)
            }
            Text(spec.title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(textColor)
                .strikethrough(spec.isDone, color: LumenTokens.TextColor.muted)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .frame(height: height, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(spec.customFill ?? spec.color.opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    spec.customStroke ?? spec.color.opacity(0.45),
                    style: StrokeStyle(lineWidth: 0.5, dash: spec.isDashed ? [3, 2] : [])
                )
        )
        .help(spec.help ?? spec.title)
    }

    private var textColor: Color {
        if spec.isDone { return LumenTokens.TextColor.muted }
        return spec.useSecondaryText ? LumenTokens.TextColor.secondary : LumenTokens.TextColor.primary
    }
}

extension CalendarItem {
    /// CalendarItem → CalendarBarSpec 변환. 막대 자체에 필요한 표시 속성만 추출.
    /// 클릭/popover 등 동작은 호출하는 뷰가 별도로 처리.
    func barSpec() -> CalendarBarSpec {
        let isLocal = (kind == .local)
        let resolvedColor = customColor ?? projectKey.map { jiraProjectColor($0) } ?? kind.color
        // 막대 자체 색(EKEvent의 캘린더 색)이나 표식(로컬의 점선/흰 배경)만으로 구별 가능 →
        // Jira 항목(스프린트/에픽/태스크)에서만 kind 색 점을 점으로 표시.
        let showDot = (customColor == nil) && !isLocal
        return CalendarBarSpec(
            title: title,
            color: resolvedColor,
            isDashed: isLocal,
            isDone: isDone,
            useSecondaryText: isLocal,
            showDot: showDot,
            dotColor: kind.color,
            customFill: isLocal ? Color.white.opacity(0.04) : nil,
            customStroke: isLocal ? LumenTokens.TextColor.muted.opacity(0.55) : nil,
            help: issueKey.map { "\($0) · \(title)" } ?? title
        )
    }
}
