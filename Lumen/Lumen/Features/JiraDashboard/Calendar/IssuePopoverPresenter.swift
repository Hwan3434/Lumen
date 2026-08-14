import SwiftUI

// 이슈 미리보기·댓글 팝오버를 **데이터를 받은 뒤에** 띄우는 modifier.
//
// macOS SwiftUI popover는 표시되는 순간 크기가 고정되고, 그 뒤 내용이 커져도 창이 따라
// 자라지 않는다. 그래서 로딩 상태로 먼저 띄우면 본문이 도착해도 로딩 크기(약 160pt)에
// 갇힌다 — 높이 상한을 아무리 손봐도 소용이 없다.
//
// 내용에 맞춰 크기가 정해지려면 뜨는 시점에 이미 내용이 있어야 한다. 그래서 클릭 →
// 조회 → (도착하면) 표시 순서로 간다. 대신 클릭과 표시 사이에 네트워크 왕복이 그대로
// 보이므로, JiraService가 짧게 캐시해 같은 이슈를 다시 열 때는 즉시 뜨게 한다.

extension View {
    /// 이슈 미리보기 팝오버. `isPresented`가 true가 되면 조회를 시작하고, 도착한 뒤에 뜬다.
    func issuePreviewPopover(issueKey: String?,
                             isPresented: Binding<Bool>,
                             arrowEdge: Edge = .top) -> some View {
        modifier(PreloadedIssuePopover(issueKey: issueKey,
                                       isRequested: isPresented,
                                       arrowEdge: arrowEdge,
                                       kind: .preview))
    }

    /// ⌘클릭 댓글 팝오버. 동작 방식은 위와 같다.
    func issueCommentsPopover(issueKey: String?,
                              isPresented: Binding<Bool>,
                              arrowEdge: Edge = .top) -> some View {
        modifier(PreloadedIssuePopover(issueKey: issueKey,
                                       isRequested: isPresented,
                                       arrowEdge: arrowEdge,
                                       kind: .comments))
    }
}

private struct PreloadedIssuePopover: ViewModifier {
    enum Kind { case preview, comments }

    let issueKey: String?
    @Binding var isRequested: Bool
    let arrowEdge: Edge
    let kind: Kind

    @State private var payload: Payload?
    @State private var errorMessage: String?
    @State private var isShowing = false
    @State private var loadingKey: String?

    private enum Payload {
        case preview(IssueDetail)
        case comments(total: Int, comments: [IssueComment])
    }

    func body(content: Content) -> some View {
        content
            .popover(isPresented: $isShowing, arrowEdge: arrowEdge) { popoverContent }
            .onChange(of: isRequested) { _, requested in
                if requested {
                    load()
                } else {
                    isShowing = false
                }
            }
            .onChange(of: isShowing) { _, showing in
                // 팝오버를 닫으면 호출부 상태도 정리한다. 다음 클릭이 다시 조회를 걸도록.
                if !showing {
                    isRequested = false
                    payload = nil
                    errorMessage = nil
                }
            }
    }

    @ViewBuilder
    private var popoverContent: some View {
        switch payload {
        case .preview(let detail):
            IssuePreviewPopover(issueKey: detail.key, injectedDetail: detail)
        case .comments(let total, let comments):
            IssueCommentsPopover(issueKey: issueKey ?? "",
                                 injected: (total: total, comments: comments))
        case nil:
            failureView
        }
    }

    private var failureView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(issueKey ?? "")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(LumenTokens.Accent.violetSoft)
            Text(errorMessage ?? "내용을 불러오지 못했습니다.")
                .font(.system(size: 11.5))
                .foregroundStyle(LumenTokens.ErrorTone.title)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: CalendarPreviewMetrics.width, alignment: .leading)
    }

    private func load() {
        guard let key = issueKey, !key.isEmpty else { return }
        // 조회 중 같은 대상을 다시 누르면 무시 — 두 번 받아올 이유가 없다.
        guard loadingKey != key else { return }
        loadingKey = key

        Task { @MainActor in
            defer { loadingKey = nil }
            do {
                switch kind {
                case .preview:
                    let detail = try await JiraService.shared.fetchIssueDetail(key: key)
                    payload = .preview(detail)
                case .comments:
                    let page = try await JiraService.shared.fetchAllComments(key: key)
                    payload = .comments(total: page.total, comments: page.comments)
                }
                errorMessage = nil
            } catch {
                payload = nil
                errorMessage = error.networkErrorMessage
            }
            // 그 사이 사용자가 다른 곳을 눌러 요청이 취소됐으면 띄우지 않는다.
            guard isRequested else { return }
            isShowing = true
        }
    }
}
