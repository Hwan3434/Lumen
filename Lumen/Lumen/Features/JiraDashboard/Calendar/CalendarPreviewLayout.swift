import SwiftUI
import AppKit

/// 미리보기 popover의 공통 치수. 본 레이아웃뿐 아니라 호출자의 로딩/에러 상태도
/// 같은 폭을 써야 popover가 상태 전환 때 흔들리지 않으므로 한 곳에서 관리한다.
enum CalendarPreviewMetrics {
    static let width: CGFloat = 500
    /// 본문(설명/메모) 스크롤 영역의 최소 높이. ScrollView가 0으로 붕괴하지 않을 만큼만 준다 —
    /// 이걸 키우면 설명이 짧은 이슈에서 팝오버 한가운데가 빈 공간으로 남는다.
    static let bodyMinHeight: CGFloat = 44

    /// 본문 최대 높이의 희망치. 팝오버는 대시보드 패널이 아니라 별도 윈도우라
    /// 패널(840pt)이 아닌 화면 높이가 한계이므로, 아래에서 화면 여유로 다시 조인다.
    private static let desiredBodyMaxHeight: CGFloat = 2080
    private static let desiredBodyMaxHeightWithComments: CGFloat = 1040
    /// 헤더·제목·푸터·패딩이 쓰는 몫. 화면 여유에서 본문 몫을 계산할 때 뺀다.
    private static let chromeAllowance: CGFloat = 200
    /// 댓글 영역(최대 3개 × 3줄)이 쓰는 몫.
    private static let commentsAllowance: CGFloat = 220

    /// 본문만 있을 때의 최대 높이.
    static var bodyMaxHeight: CGFloat {
        clamped(min(desiredBodyMaxHeight, availableHeight - chromeAllowance))
    }

    /// 댓글이 함께 붙을 때의 본문 최대 높이 — 댓글 몫을 먼저 떼고 남는 만큼.
    static var bodyMaxHeightWithComments: CGFloat {
        clamped(min(desiredBodyMaxHeightWithComments,
                    availableHeight - chromeAllowance - commentsAllowance))
    }

    /// 아주 작은 화면에서도 최소 높이 아래로는 내려가지 않게.
    private static func clamped(_ value: CGFloat) -> CGFloat { max(bodyMinHeight, value) }

    /// 팝오버가 잘리지 않고 쓸 수 있는 세로 여유. 화면을 못 읽으면 보수적인 기본값.
    private static var availableHeight: CGFloat {
        max(480, NSScreen.main?.visibleFrame.height ?? 900)
    }
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
