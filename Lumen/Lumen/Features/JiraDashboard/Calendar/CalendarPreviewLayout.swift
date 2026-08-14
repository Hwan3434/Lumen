import SwiftUI

/// 미리보기 popover의 공통 치수. 본 레이아웃뿐 아니라 호출자의 로딩/에러 상태도
/// 같은 폭을 써야 popover가 상태 전환 때 흔들리지 않으므로 한 곳에서 관리한다.
enum CalendarPreviewMetrics {
    static let width: CGFloat = 500
    /// 본문(설명/메모) 스크롤 영역의 최소 높이. ScrollView가 0으로 붕괴하지 않을 만큼만 준다 —
    /// 이걸 키우면 설명이 짧은 이슈에서 팝오버 한가운데가 빈 공간으로 남는다.
    static let bodyMinHeight: CGFloat = 44
    /// 팝오버 전체 높이 상한. 내용이 짧으면 그만큼만 차지하고, 넘어가면 본문이 스크롤된다.
    ///
    /// 주의: macOS SwiftUI `.popover`는 **표시되는 순간 크기가 고정**되고 그 뒤 내용이 커져도
    /// 창이 따라 자라지 않는다(내부에서 강제로 늘려도 SwiftUI가 되돌린다). 그래서 이 상한이
    /// 의미를 가지려면 팝오버가 뜨는 시점에 이미 내용이 있어야 한다 —
    /// 로딩 상태로 먼저 띄우면 상한과 무관하게 로딩 크기(약 160pt)에 갇힌다.
    /// 조회를 먼저 하고 띄우는 책임은 `IssuePopoverPresenter`에 있다.
    static let maxPopoverHeight: CGFloat = 550
    /// 스크롤 영역의 상한. 전체 상한과 같은 값을 준다 —
    /// 헤더·제목·푸터가 쓰는 높이를 여기서 미리 빼면 그 추정이 틀리는 만큼 세로를 버리게 된다
    /// (161로 잡았을 때 실제 크롬은 113이라 팝오버가 502에서 멈췄다).
    /// 최종 절단은 레이아웃 바깥의 `maxPopoverHeight`가 하고, 스크롤 영역은 남는 만큼 가져간다.
    static let bodyMaxHeight: CGFloat = maxPopoverHeight
    /// ⌘클릭 댓글 팝오버의 목록 높이 — 위와 같은 이유로 전체 상한과 같다.
    static let commentsPopoverMaxHeight: CGFloat = maxPopoverHeight
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
        // 메타 행이 많은 호출자(캘린더 이벤트)는 크롬만으로도 두꺼워질 수 있어 전체로도 한 번 막는다.
        .frame(maxHeight: CalendarPreviewMetrics.maxPopoverHeight)
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
