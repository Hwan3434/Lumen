import SwiftUI

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
                    .frame(minHeight: 60, maxHeight: 200)
                }

                extraContent()
            }
            .padding(14)

            footer()
        }
        .frame(width: 340)
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
        self.extraContent = { EmptyView() }
        self.footer = { EmptyView() }
    }
}
