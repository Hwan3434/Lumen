import SwiftUI

private typealias P = LumenTokens.Palette

/// ⌘클릭 전용 — 댓글만 보는 팝오버. 스레드 전체를 받아 세로를 전부 댓글에 쓴다.
/// 데이터는 플러그인이 받아서 넘겨준다(팝오버는 첫 프레임 크기로 고정되므로).
struct IssueCommentsPopover: View {
    let issueKey: String
    let total: Int
    let comments: [IssueComment]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if comments.isEmpty {
                Text("댓글이 없어요")
                    .lumenText(.label, weight: .regular)
                    .foregroundStyle(P.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal, .bottom], LumenTokens.Space.pad)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(comments.enumerated()), id: \.element.id) { idx, comment in
                            if idx > 0 { LumenHairline().padding(.vertical, LumenTokens.Space.s3) }
                            row(comment)
                        }
                    }
                    .padding([.horizontal, .bottom], LumenTokens.Space.pad)
                }
                .frame(maxHeight: CalendarPreviewMetrics.maxPopoverHeight)
            }
        }
        // 내용만큼만 차지하고, 상한을 넘으면 목록이 스크롤된다.
        .frame(width: CalendarPreviewMetrics.width)
        .frame(maxHeight: CalendarPreviewMetrics.maxPopoverHeight)
        .background(P.surfaceRaised)
    }

    private var header: some View {
        HStack(spacing: LumenTokens.Space.inline) {
            LumenIcon("messages-square", size: .small)
                .foregroundStyle(P.inkMuted)
            Text(issueKey)
                .font(LumenFont.mono(LumenTextStyle.caption.size, .medium))
                .foregroundStyle(P.inkMuted)
            Text("댓글 \(total)개")
                .lumenText(.label, weight: .semibold)
                .foregroundStyle(P.ink)
            Spacer()
        }
        .padding(.horizontal, LumenTokens.Space.pad)
        .padding(.top, LumenTokens.Space.pad)
        .padding(.bottom, LumenTokens.Space.stack)
    }

    private func row(_ comment: IssueComment) -> some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
            HStack(spacing: LumenTokens.Space.inline) {
                Text(comment.author)
                    .lumenText(.label, weight: .semibold)
                    .foregroundStyle(P.ink)
                    .lineLimit(1)
                if let created = comment.created {
                    Text(LumenTime.relative(created, granularity: .shortNoSuffix))
                        .lumenText(.caption)
                        .foregroundStyle(P.inkFaint)
                }
            }
            // 전용 팝오버라 줄 수를 제한하지 않는다 — 잘려서 다시 창을 여는 일이 없도록.
            Text(comment.bodyText.isEmpty ? "(첨부만 있는 댓글)" : comment.bodyText)
                .lumenText(.label, weight: .regular)
                .foregroundStyle(comment.bodyText.isEmpty ? P.inkFaint : P.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}
