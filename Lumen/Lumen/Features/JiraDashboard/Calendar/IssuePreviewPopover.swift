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
                    extraContent: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 10, weight: .medium))
                            Text("\(d.commentCount)")
                                .font(.system(size: 11, design: .monospaced))
                        }
                        .foregroundStyle(LumenTokens.TextColor.muted)
                    },
                    footer: { jiraOpenFooter }
                )
            } else {
                Color.clear.frame(width: 340, height: 80)
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
        .frame(width: 340, height: 120)
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
        .frame(width: 340, alignment: .leading)
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
