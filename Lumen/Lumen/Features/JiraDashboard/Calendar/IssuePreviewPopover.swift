import SwiftUI

// 캘린더 알약/막대 클릭 시 뜨는 미리보기 popover.
// 호출자가 issueKey를 넘기면 onAppear에서 fetchIssueDetail(key:)을 비동기로 돌리며 progress.
// 사용자가 "Jira에서 열기"를 눌러야만 외부 브라우저로 이동.

struct IssuePreviewPopover: View {
    let issueKey: String
    /// 주입된 값이 있으면 네트워크를 타지 않는다. Jira 연결 없이 레이아웃을 확인하기 위한 구멍 —
    /// 실사용 경로는 항상 nil이라 동작에 영향이 없다.
    var injectedDetail: IssueDetail? = nil

    @State private var detail: IssueDetail?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            // 주입값은 뷰 생명주기(.task)를 기다리지 않고 바로 그린다 — 오프스크린 렌더링에서도 보이도록.
            if let d = injectedDetail ?? detail {
                CalendarPreviewLayout(
                    accentColor: projectColor,
                    accentLabel: d.key,
                    badgeText: d.status,
                    title: d.summary,
                    bodyText: d.descriptionText,
                    bodyMaxHeight: CalendarPreviewMetrics.bodyMaxHeight,
                    extraContent: { commentHint(d) },
                    footer: { jiraOpenFooter }
                )
            } else if isLoading {
                loadingView
            } else if let msg = errorMessage {
                errorView(msg)
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

    /// 댓글은 ⌘클릭 전용 팝오버로 분리했다. 여기엔 "있다"는 사실과 여는 방법만 남긴다 —
    /// 설명과 댓글이 한 팝오버에서 세로를 서로 뺏던 문제를 없애기 위함.
    @ViewBuilder
    private func commentHint(_ detail: IssueDetail) -> some View {
        if detail.commentCount > 0 {
            HStack(spacing: 5) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 10, weight: .medium))
                Text("댓글 \(detail.commentCount)")
                    .font(.system(size: 11, weight: .medium))
                Text("⌘클릭으로 보기")
                    .font(.system(size: 10.5))
                    .foregroundStyle(LumenTokens.TextColor.muted.opacity(0.8))
            }
            .foregroundStyle(LumenTokens.TextColor.muted)
        }
    }

    private var projectColor: Color {
        let prefix = issueKey.split(separator: "-").first.map(String.init) ?? issueKey
        return jiraProjectColor(prefix)
    }

    private var jiraOpenFooter: some View {
        HStack(spacing: 8) {
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
        if let injected = injectedDetail {
            detail = injected
            errorMessage = nil
            isLoading = false
            return
        }
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
