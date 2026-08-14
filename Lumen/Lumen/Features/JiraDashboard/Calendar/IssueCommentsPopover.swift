import SwiftUI

/// ⌘클릭 전용 — 댓글만 보는 popover.
/// 기본 미리보기는 설명을 위한 자리라 둘을 한 팝오버에 넣으면 서로 높이를 뺏는다.
/// 여기선 스레드 전체를 받아 세로를 전부 댓글에 쓴다.
struct IssueCommentsPopover: View {
    let issueKey: String
    /// 주입하면 네트워크를 타지 않는다 — 스냅샷용. 실사용 경로는 nil.
    var injected: (total: Int, comments: [IssueComment])? = nil

    @State private var comments: [IssueComment] = []
    @State private var total = 0
    @State private var errorMessage: String?
    @State private var isLoading = true

    /// 주입값은 `.task`(첫 렌더 이후에 도는)를 기다리지 않고 바로 그린다.
    /// 팝오버는 **첫 프레임의 크기로 고정**되므로, 여기서 한 박자 늦으면 목록이 다 차 있어도
    /// 창은 로딩 크기에 갇힌다.
    private var shownComments: [IssueComment] { injected?.comments ?? comments }
    private var shownTotal: Int { injected?.total ?? total }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let msg = errorMessage, shownComments.isEmpty {
                Text(msg)
                    .font(.system(size: 11.5))
                    .foregroundStyle(LumenTokens.ErrorTone.title)
                    .lineLimit(3)
                    .padding(EdgeInsets(top: 12, leading: 14, bottom: 16, trailing: 14))
            } else if isLoading && shownComments.isEmpty {
                HStack(spacing: 8) {
                    InlineSpinner()
                    Text("댓글 불러오는 중…")
                        .font(.system(size: 11.5))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if shownComments.isEmpty {
                Text("댓글 없음")
                    .font(.system(size: 11.5))
                    .italic()
                    .foregroundStyle(LumenTokens.TextColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 10, leading: 14, bottom: 16, trailing: 14))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(shownComments) { row($0) }
                    }
                    .padding(EdgeInsets(top: 10, leading: 14, bottom: 14, trailing: 14))
                }
                .frame(maxHeight: CalendarPreviewMetrics.commentsPopoverMaxHeight)
            }
        }
        // 내용만큼만 차지하고, 상한을 넘으면 목록이 스크롤된다.
        // 이 상한이 의미를 가지려면 데이터가 있는 채로 떠야 한다 — IssuePopoverPresenter 참고.
        .frame(width: CalendarPreviewMetrics.width)
        .frame(maxHeight: CalendarPreviewMetrics.maxPopoverHeight)
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(LumenTokens.TextColor.muted)
            Text(issueKey)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(LumenTokens.Accent.violetSoft)
            Text("댓글 \(shownTotal)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.secondary)
            if isLoading && !shownComments.isEmpty {
                InlineSpinner(size: 10)
            }
            Spacer()
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 8, trailing: 14))
    }

    private func row(_ comment: IssueComment) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(comment.author)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .lineLimit(1)
                if let created = comment.created {
                    Text(LumenTime.relative(created, granularity: .shortNoSuffix))
                        .font(.system(size: 10))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
            }
            // 전용 팝오버라 줄 수를 제한하지 않는다 — 잘려서 다시 창을 여는 일이 없도록.
            Text(comment.bodyText.isEmpty ? "(첨부만 있는 댓글)" : comment.bodyText)
                .font(.system(size: 11.5))
                .italic(comment.bodyText.isEmpty)
                .foregroundStyle(comment.bodyText.isEmpty
                                 ? LumenTokens.TextColor.muted
                                 : LumenTokens.TextColor.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func load() async {
        if let injected {
            comments = injected.comments
            total = injected.total
            isLoading = false
            return
        }
        isLoading = true
        do {
            let all = try await JiraService.shared.fetchAllComments(key: issueKey)
            comments = all.comments
            total = max(all.total, all.comments.count)
            errorMessage = nil
        } catch {
            errorMessage = error.networkErrorMessage
        }
        isLoading = false
    }
}
