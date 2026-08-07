import SwiftUI

// 캘린더 알약/막대 클릭 시 뜨는 미리보기 popover.
// 호출자가 issueKey를 넘기면 onAppear에서 fetchIssueDetail(key:)을 비동기로 돌리며 progress.
// 사용자가 "Jira에서 열기"를 눌러야만 외부 브라우저로 이동.

struct IssuePreviewPopover: View {
    let issueKey: String

    @State private var detail: IssueDetail?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let msg = errorMessage {
                errorView(msg)
            } else if let d = detail {
                CalendarPreviewLayout(
                    accentColor: projectColor,
                    accentLabel: d.key,
                    badgeText: d.status,
                    title: d.summary,
                    bodyText: d.descriptionText,
                    bodyMaxHeight: d.recentComments.isEmpty
                        ? CalendarPreviewMetrics.bodyMaxHeight
                        : CalendarPreviewMetrics.bodyMaxHeightWithComments,
                    extraContent: { commentSection(d) },
                    footer: { jiraOpenFooter }
                )
            } else {
                Color.clear.frame(width: CalendarPreviewMetrics.width, height: 100)
            }
        }
        .task { await load() }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("불러오는 중…")
                .font(.system(size: 11.5))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
        .frame(width: CalendarPreviewMetrics.width, height: 160)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(issueKey)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(LumenTokens.Accent.violetSoft)
            Text(msg)
                .font(.system(size: 11.5))
                .foregroundStyle(LumenTokens.ErrorTone.title)
                .lineLimit(3)
        }
        .padding(14)
        .frame(width: CalendarPreviewMetrics.width, alignment: .leading)
    }

    /// 좁은 미리보기 팝오버에서는 스레드를 페이지네이션하거나 무한스크롤하지 않는 것이 통례다.
    /// 최신 몇 개만 보여주고 나머지는 "더 보기"로 Jira 본문에 넘긴다.
    @ViewBuilder
    private func commentSection(_ detail: IssueDetail) -> some View {
        if detail.recentComments.isEmpty {
            // 본문을 못 가져왔어도 개수는 알 수 있는 경우 — 기존처럼 개수만 노출.
            if detail.commentCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 10, weight: .medium))
                    Text("\(detail.commentCount)")
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(LumenTokens.TextColor.muted)
            }
        } else {
            VStack(alignment: .leading, spacing: 7) {
                Rectangle()
                    .fill(LumenTokens.divider)
                    .frame(height: 0.5)

                HStack(spacing: 5) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                    Text("댓글 \(detail.commentCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LumenTokens.TextColor.secondary)
                    Spacer()
                    if hiddenCommentCount(detail) > 0 {
                        Button {
                            openJira(issueKey)
                        } label: {
                            Text("이전 \(hiddenCommentCount(detail))개 더 보기")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(LumenTokens.Accent.violetSoft)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(detail.recentComments) { commentRow($0) }
                    }
                }
                .frame(maxHeight: CalendarPreviewMetrics.commentsMaxHeight)
            }
        }
    }

    private func hiddenCommentCount(_ detail: IssueDetail) -> Int {
        max(0, detail.commentCount - detail.recentComments.count)
    }

    private func commentRow(_ comment: IssueComment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(comment.author)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.secondary)
                    .lineLimit(1)
                if let created = comment.created {
                    Text(LumenTime.relative(created, granularity: .shortNoSuffix))
                        .font(.system(size: 10))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
            }
            Text(comment.bodyText.isEmpty ? "(첨부만 있는 댓글)" : comment.bodyText)
                .font(.system(size: 11))
                .italic(comment.bodyText.isEmpty)
                .foregroundStyle(comment.bodyText.isEmpty
                                 ? LumenTokens.TextColor.muted
                                 : LumenTokens.TextColor.secondary)
                .lineSpacing(1.5)
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var projectColor: Color {
        let prefix = issueKey.split(separator: "-").first.map(String.init) ?? issueKey
        return jiraProjectColor(prefix)
    }

    private var jiraOpenFooter: some View {
        HStack {
            Spacer()
            Button {
                openJira(issueKey)
            } label: {
                HStack(spacing: 5) {
                    Text("Jira에서 열기")
                        .font(.system(size: 11.5, weight: .medium))
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(LumenTokens.TextColor.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LumenTokens.Accent.violet.opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(LumenTokens.Accent.violet.opacity(0.45), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .padding(.top, 4)
    }

    private func load() async {
        isLoading = true
        do {
            let d = try await JiraService.shared.fetchIssueDetail(key: issueKey)
            detail = d
            errorMessage = nil
        } catch {
            errorMessage = error.networkErrorMessage
        }
        isLoading = false
    }
}
