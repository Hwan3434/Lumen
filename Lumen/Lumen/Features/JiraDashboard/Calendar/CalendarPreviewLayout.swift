import SwiftUI

/// 미리보기 popover의 공통 치수. 본 레이아웃뿐 아니라 호출자의 로딩/에러 상태도
/// 같은 폭을 써야 popover가 상태 전환 때 흔들리지 않으므로 한 곳에서 관리한다.
enum CalendarPreviewMetrics {
    static let width: CGFloat = 500
    /// 본문(설명/메모) 스크롤 영역의 최소 높이. ScrollView가 0으로 붕괴하지 않을 만큼만 준다 —
    /// 이걸 키우면 설명이 짧은 이슈에서 팝오버 한가운데가 빈 공간으로 남는다.
    static let bodyMinHeight: CGFloat = 44
    /// 본문 최대 높이. 화면 크기에 따라 값이 달라지면 같은 버전인데 사람마다 다르게 보이므로
    /// 고정값으로 둔다. 이보다 긴 내용은 스크롤하거나 상세 창에서 본다.
    /// 헤더·제목·푸터가 약 161pt를 더 쓰므로 팝오버 총 높이는 이 값 + 161 근처가 된다.
    static let bodyMaxHeight: CGFloat = 700
    /// ⌘클릭 댓글 팝오버의 목록 높이 — 세로 전부를 댓글에 쓰므로 본문과 같은 여유를 준다.
    static let commentsPopoverMaxHeight: CGFloat = 700
}

/// IssuePreviewPopover · EKEventPreviewPopover가 공유하는 미리보기 레이아웃.
/// header(카테고리 색 점·라벨·뱃지) + title + meta rows + body + footer 구성.
/// 호출자는 데이터만 넘겨 구성한다 — 두 popover의 시각 일관성을 한 곳에서 관리.
struct CalendarPreviewLayout<Body: View, Footer: View>: View {
    /// 좌상단 카테고리 라인의 색 점 — 캘린더 색 또는 Jira 카테고리 색.
    let accentColor: Color
    /// 카테고리 라벨 — "PROJ-123" 같은 키 또는 캘린더 이름.
    let accentLabel: String
    /// 라벨 옆의 작은 뱃지 — Jira 상태 / 캘린더 source 등. nil이면 안 보임.
    var badgeText: String? = nil
    /// 본문 제목 — 굵게 표시.
    let title: String
    /// 시간/위치/URL 같은 한 줄 정보들. 빈 배열이면 영역 자체 생략.
    var metaRows: [MetaRow] = []
    /// 긴 본문(설명/메모) — 스크롤 영역으로 들어감. nil/빈 문자열이면 생략.
    var bodyText: String? = nil
    /// 본문 스크롤 영역의 최대 높이. 아래에 댓글 같은 추가 컨텐츠가 붙는 호출자는
    /// 이 값을 줄여 팝오버 전체 높이를 억제한다.
    var bodyMaxHeight: CGFloat = CalendarPreviewMetrics.bodyMaxHeight
    /// 본문 아래 추가 컨텐츠 (예: 댓글 수). 없으면 EmptyView.
    @ViewBuilder var extraContent: () -> Body
    /// footer 영역 — 외부 열기 버튼 등. 없으면 EmptyView.
    @ViewBuilder var footer: () -> Footer

    struct MetaRow: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                header
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if !metaRows.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(metaRows) { row in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: row.icon)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(LumenTokens.TextColor.muted)
                                    .padding(.top, 2)
                                Text(row.text)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(LumenTokens.TextColor.secondary)
                                    .lineLimit(3)
                                    .truncationMode(.tail)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                if let text = bodyText, !text.isEmpty {
                    ScrollView {
                        Text(text)
                            .font(.system(size: 11.5))
                            .foregroundStyle(LumenTokens.TextColor.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: CalendarPreviewMetrics.bodyMinHeight,
                           maxHeight: bodyMaxHeight)
                }

                extraContent()
            }
            .padding(14)

            footer()
        }
        .frame(width: CalendarPreviewMetrics.width)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accentColor)
                .frame(width: 9, height: 9)
            Text(accentLabel)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(LumenTokens.Accent.violetSoft)
                .lineLimit(1)
            if let badge = badgeText, !badge.isEmpty {
                Text(badge)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(LumenTokens.stroke, lineWidth: 0.5)
                    )
            }
            Spacer()
        }
    }
}

extension CalendarPreviewLayout where Body == EmptyView {
    init(
        accentColor: Color,
        accentLabel: String,
        badgeText: String? = nil,
        title: String,
        metaRows: [MetaRow] = [],
        bodyText: String? = nil,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.accentColor = accentColor
        self.accentLabel = accentLabel
        self.badgeText = badgeText
        self.title = title
        self.metaRows = metaRows
        self.bodyText = bodyText
        self.bodyMaxHeight = CalendarPreviewMetrics.bodyMaxHeight
        self.extraContent = { EmptyView() }
        self.footer = footer
    }
}

extension CalendarPreviewLayout where Footer == EmptyView {
    init(
        accentColor: Color,
        accentLabel: String,
        badgeText: String? = nil,
        title: String,
        metaRows: [MetaRow] = [],
        bodyText: String? = nil,
        @ViewBuilder extraContent: @escaping () -> Body
    ) {
        self.accentColor = accentColor
        self.accentLabel = accentLabel
        self.badgeText = badgeText
        self.title = title
        self.metaRows = metaRows
        self.bodyText = bodyText
        self.bodyMaxHeight = CalendarPreviewMetrics.bodyMaxHeight
        self.extraContent = extraContent
        self.footer = { EmptyView() }
    }
}

extension CalendarPreviewLayout where Body == EmptyView, Footer == EmptyView {
    init(
        accentColor: Color,
        accentLabel: String,
        badgeText: String? = nil,
        title: String,
        metaRows: [MetaRow] = [],
        bodyText: String? = nil
    ) {
        self.accentColor = accentColor
        self.accentLabel = accentLabel
        self.badgeText = badgeText
        self.title = title
        self.metaRows = metaRows
        self.bodyText = bodyText
        self.bodyMaxHeight = CalendarPreviewMetrics.bodyMaxHeight
        self.extraContent = { EmptyView() }
        self.footer = { EmptyView() }
    }
}
