import SwiftUI

/// 이슈 상세 창의 본문. 팝오버가 "빠른 훑기"라면 이쪽은 "읽기" 용도 —
/// 설명 전문과 댓글 스레드 전체를 크기 조절 가능한 창에서 스크롤하며 본다.
/// 그래서 여기엔 팝오버 같은 높이 상한이 없다. 창 크기가 곧 상한이다.
struct IssueDetailView: View {
    let issueKey: String
    /// 주입하면 네트워크를 타지 않는다 — 스냅샷·프리뷰용. 실사용 경로는 nil.
    var injected: (detail: IssueDetail, comments: [IssueComment])? = nil

    @State private var detail: IssueDetail?
    @State private var comments: [IssueComment] = []
    @State private var totalComments = 0
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(LumenTokens.divider).frame(height: 0.5)

            if let msg = errorMessage, detail == nil {
                errorView(msg)
            } else if isLoading && detail == nil {
                loadingView
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 20) {
                        descriptionSection
                        commentsSection
                    }
                    .padding(EdgeInsets(top: 18, leading: 22, bottom: 24, trailing: 22))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LumenTokens.BG.windowSolid)
        .task { await load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ProjectChip(key: projectKey)
                    Text(issueKey)
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(LumenTokens.Accent.violetSoft)
                        .textSelection(.enabled)
                    if let d = detail {
                        StatusBadge(label: d.status, category: .undefined)
                    }
                }
                Text(detail?.summary ?? "불러오는 중…")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

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
        .padding(EdgeInsets(top: 16, leading: 22, bottom: 14, trailing: 22))
    }

    // MARK: - Sections

    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(icon: "text.alignleft", title: "설명")
            if let text = detail?.descriptionText, !text.isEmpty {
                Text(text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(LumenTokens.TextColor.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                Text("설명 없음")
                    .font(.system(size: 12))
                    .italic()
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
        }
    }

    @ViewBuilder
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                sectionLabel(icon: "bubble.left.and.bubble.right", title: "댓글")
                Text("\(totalComments)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                if isLoading {
                    InlineSpinner(size: 10)
                }
                Spacer()
                if let msg = errorMessage, !comments.isEmpty || detail != nil {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(LumenTokens.ErrorTone.title)
                        .lineLimit(1)
                }
            }

            if comments.isEmpty && !isLoading {
                Text("댓글 없음")
                    .font(.system(size: 12))
                    .italic()
                    .foregroundStyle(LumenTokens.TextColor.muted)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(comments) { commentRow($0) }
                }
            }
        }
    }

    private func commentRow(_ comment: IssueComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(comment.author)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                if let created = comment.created {
                    Text(LumenTime.relative(created, granularity: .shortNoSuffix))
                        .font(.system(size: 10.5))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
            }
            Text(comment.bodyText.isEmpty ? "(첨부만 있는 댓글)" : comment.bodyText)
                .font(.system(size: 12))
                .italic(comment.bodyText.isEmpty)
                .foregroundStyle(comment.bodyText.isEmpty
                                 ? LumenTokens.TextColor.muted
                                 : LumenTokens.TextColor.secondary)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.leading, 2)
    }

    private func sectionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.muted)
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.secondary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("불러오는 중…")
                .font(.system(size: 12))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LumenTokens.ErrorTone.icon)
            Text(msg)
                .font(.system(size: 12))
                .foregroundStyle(LumenTokens.ErrorTone.title)
                .multilineTextAlignment(.center)
            Button("다시 시도") { Task { await load(force: true) } }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(LumenTokens.Accent.violetSoft)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var projectKey: String {
        issueKey.split(separator: "-").first.map(String.init) ?? issueKey
    }

    // MARK: - Loading

    private func load(force: Bool = false) async {
        if let injected {
            detail = injected.detail
            comments = injected.comments
            totalComments = injected.comments.count
            isLoading = false
            return
        }
        if detail != nil && !force { return }

        isLoading = true
        errorMessage = nil
        do {
            // 본문이 먼저 도착하면 그것부터 보여준다 — 댓글이 많으면 전체 조회가 오래 걸린다.
            let d = try await JiraService.shared.fetchIssueDetail(key: issueKey)
            detail = d
            totalComments = d.commentCount
            comments = d.recentComments

            let all = try await JiraService.shared.fetchAllComments(key: issueKey)
            comments = all.comments
            totalComments = max(all.total, all.comments.count)
        } catch {
            // 본문이라도 받았으면 화면을 지우지 않고 경고만 띄운다.
            errorMessage = error.networkErrorMessage
        }
        isLoading = false
    }
}
