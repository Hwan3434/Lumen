import SwiftUI

/// Jira 이슈 막대를 눌렀을 때 뜨는 미리보기. 데이터는 플러그인이 받아서 넘겨준다 —
/// 팝오버는 뜬 뒤 크기가 안 바뀌어서 로딩 상태로 먼저 띄울 수 없다.
struct IssuePreviewPopover: View {
    let detail: IssueDetail
    let accent: Color
    var openURL: URL? = nil

    var body: some View {
        CalendarPreviewLayout(
            accentColor: accent,
            accentLabel: detail.key,
            badgeText: detail.status,
            title: detail.summary,
            bodyText: detail.descriptionText,
            extraContent: { commentHint },
            footer: { footer }
        )
    }

    /// 댓글은 ⌘클릭 전용 팝오버로 분리했다. 여기엔 "있다"는 사실과 여는 방법만 남긴다 —
    /// 설명과 댓글이 한 팝오버에서 세로를 서로 뺏던 문제를 없애기 위함.
    @ViewBuilder
    private var commentHint: some View {
        if detail.commentCount > 0 {
            HStack(spacing: LumenTokens.Space.scaled(6)) {
                LumenIcon("messages-square", size: .small)
                Text("댓글 \(detail.commentCount)개")
                    .lumenText(.label)
                Text("⌘클릭하면 볼 수 있어요")
                    .lumenText(.caption)
                    .foregroundStyle(LumenTokens.Palette.inkFaint)
            }
            .foregroundStyle(LumenTokens.Palette.inkMuted)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let url = openURL {
            HStack(spacing: LumenTokens.Space.inline) {
                Spacer()
                Button {
                    openScheduleURL(url)
                } label: {
                    Label { Text("Jira에서 열기") } icon: { LumenIcon("external-link", size: .small) }
                }
                .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))
            }
            .padding(.horizontal, LumenTokens.Space.pad)
            .padding(.bottom, LumenTokens.Space.s4)
            .background(LumenTokens.Palette.surfaceRaised)
        }
    }
}
