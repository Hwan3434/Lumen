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
        VStack(alignment: .leading, spacing: 0) {
            content
            footer
        }
        .frame(width: 340)
        .frame(minHeight: 180)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("불러오는 중…")
                    .font(.system(size: 11.5))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 30)
        } else if let msg = errorMessage {
            VStack(alignment: .leading, spacing: 6) {
                header
                Text(msg)
                    .font(.system(size: 11.5))
                    .foregroundStyle(LumenTokens.ErrorTone.title)
                    .lineLimit(3)
            }
            .padding(14)
        } else if let d = detail {
            VStack(alignment: .leading, spacing: 8) {
                header(detail: d)
                Text(d.summary)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if !d.descriptionText.isEmpty {
                    ScrollView {
                        Text(d.descriptionText)
                            .font(.system(size: 11.5))
                            .foregroundStyle(LumenTokens.TextColor.secondary)
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 220)
                }

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 10, weight: .medium))
                        Text("\(d.commentCount)")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundStyle(LumenTokens.TextColor.muted)
                }
            }
            .padding(14)
        } else {
            // 이론상 도달 안 함 — 안전장치.
            Color.clear
        }
    }

    /// 데이터 미존재(에러/로딩 화면용) 헤더 — 키만.
    @ViewBuilder
    private var header: some View {
        Text(issueKey)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(LumenTokens.Accent.violetSoft)
    }

    private func header(detail: IssueDetail) -> some View {
        HStack(spacing: 8) {
            Text(detail.key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(LumenTokens.Accent.violetSoft)
            Text(detail.status)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LumenTokens.TextColor.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
            Spacer()
        }
    }

    private var footer: some View {
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
