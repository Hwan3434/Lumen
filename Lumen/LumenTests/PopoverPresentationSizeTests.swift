import XCTest
import SwiftUI
import AppKit
@testable import Lumen

/// 실제 `.popover` 표시 경로의 크기를 잰다.
///
/// macOS popover는 **표시되는 순간 크기가 고정**되고 그 뒤 내용이 커져도 창이 자라지 않는다.
/// 그래서 "내용만큼, 단 550까지"를 지키려면 뜨는 시점에 이미 내용이 있어야 한다 —
/// 조회를 먼저 하고 띄우는 책임은 `IssuePopoverPresenter`에 있고, 여기서는 그 결과를 잰다.
@MainActor
final class PopoverPresentationSizeTests: XCTestCase {

    /// popover 창은 SwiftUI content보다 화살표·여백만큼 크다. 비교할 때 이만큼을 감안한다.
    private let popoverChrome: CGFloat = 30

    /// 긴 본문은 상한에서 멈추고 그 안에서 스크롤된다.
    func testLongBodyStopsAtTheCeiling() throws {
        let detail = IssueDetail.mock(
            key: "ABC-2001", summary: "긴 설명 렌더링 확인", status: "진행중",
            description: (1...60).map { "설명 \($0)번째 줄 — 재현 절차와 로그를 길게 적어둔 본문입니다." }
                .joined(separator: "\n"),
            total: 3, comments: [])

        let size = try present(name: "popover-long.png") {
            IssuePreviewPopover(issueKey: detail.key, injectedDetail: detail)
        }
        XCTAssertLessThanOrEqual(size.height,
                                 CalendarPreviewMetrics.maxPopoverHeight + popoverChrome,
                                 "상한을 넘겨 자라면 안 된다")
        XCTAssertGreaterThan(size.height, CalendarPreviewMetrics.maxPopoverHeight - 60,
                             "긴 본문이면 상한 가까이까지는 써야 한다")
    }

    /// 짧은 본문은 내용만큼만 — 예약이 아니라 상한이라는 뜻.
    func testShortBodyStaysSmall() throws {
        let detail = IssueDetail.mock(key: "PPAI-77", summary: "온보딩 화면 카피 최종 검토",
                                      status: "할 일",
                                      description: "디자인 시안 3차 반영본 기준으로 카피만 확정하면 됩니다.",
                                      total: 0, comments: [])
        let size = try present(name: "popover-short.png") {
            IssuePreviewPopover(issueKey: detail.key, injectedDetail: detail)
        }
        XCTAssertLessThan(size.height, 250, "짧은 내용에 큰 창이 뜨면 안 된다")
    }

    /// 댓글 팝오버도 같은 규칙. 주입값이 첫 프레임에 그려지지 않으면 여기서 잡힌다 —
    /// `.task`를 기다리면 로딩 크기로 고정돼 목록이 다 차 있어도 창이 작게 남는다.
    func testCommentsPopoverUsesContentSizeUpToTheCeiling() throws {
        let many = (1...12).map { i in
            IssueComment.mock(id: "\(i)", author: ["김철수", "홍길동", "이영희"][i % 3],
                              minutesAgo: (13 - i) * 120,
                              body: "댓글 \(i)번 — 확인했습니다. 재현 조건과 로그를 함께 남깁니다.")
        }
        let big = try present(name: "popover-comments-many.png") {
            IssueCommentsPopover(issueKey: "ABC-1421", injected: (total: 12, comments: many))
        }
        XCTAssertLessThanOrEqual(big.height,
                                 CalendarPreviewMetrics.maxPopoverHeight + popoverChrome,
                                 "상한을 넘겨 자라면 안 된다")
        XCTAssertGreaterThan(big.height, 300, "댓글 12개가 로딩 크기에 갇히면 안 된다")

        let few = try present(name: "popover-comments-few.png") {
            IssueCommentsPopover(issueKey: "ABC-1421",
                                 injected: (total: 1, comments: Array(many.prefix(1))))
        }
        XCTAssertLessThan(few.height, big.height, "댓글이 적으면 그만큼 작아야 한다")
    }

    /// 값이 이미 있는 캘린더 이벤트 미리보기도 내용만큼만.
    func testCalendarEventPreviewStaysContentSized() throws {
        let event = try XCTUnwrap(ExternalCalendarEvent(
            id: "ev-1", title: "주간 스프린트 회고", startDate: Date(),
            endDate: Date().addingTimeInterval(3600), isAllDay: false,
            calendarTitle: "업무", sourceTitle: "Google",
            calendarColor: NSColor.systemBlue.cgColor,
            notes: "지난 스프린트 회고 안건 정리", location: "회의실 A", urlString: nil))

        let size = try present(name: "popover-ekevent.png") {
            EKEventPreviewPopover(event: event)
        }
        XCTAssertLessThan(size.height, 300)
    }

    // MARK: - Harness

    /// 내용을 갖춘 채로 popover를 띄우고(= 실사용의 선-로딩 이후 상태) 창 크기를 잰다.
    private func present(name: String,
                         @ViewBuilder content: @escaping () -> some View) throws -> NSSize {
        let hosting = NSHostingView(rootView: PopoverHost(content: content))
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let window = NSWindow(contentRect: NSRect(x: screen.visibleFrame.midX - 200,
                                                  y: screen.visibleFrame.midY - 150,
                                                  width: 400, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))

        let popover = try XCTUnwrap((window.childWindows ?? []).first {
            String(describing: type(of: $0)).contains("Popover")
        }, "popover 창을 못 찾음")
        let size = popover.contentView?.bounds.size ?? popover.frame.size

        capture(popover, named: name)
        window.orderOut(nil)
        print("[popover] \(name) \(Int(size.width))x\(Int(size.height))")
        return size
    }

    private func capture(_ window: NSWindow, named name: String) {
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let dir = ProcessInfo.processInfo.environment["LUMEN_SNAPSHOT_DIR"]
            .map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: NSTemporaryDirectory())
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: dir.appendingPathComponent(name))
    }
}

private struct PopoverHost<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var shown = false

    var body: some View {
        Color.gray.opacity(0.2)
            .frame(width: 120, height: 24)
            .popover(isPresented: $shown, arrowEdge: .top) { content() }
            .onAppear { shown = true }
    }
}

// MARK: - Mocks

private extension IssueDetail {
    static func mock(key: String, summary: String, status: String, description: String,
                     total: Int, comments: [IssueComment]) -> IssueDetail {
        IssueDetail(key: key, summary: summary, status: status,
                    descriptionText: description, commentCount: total, recentComments: comments)
    }
}

private extension IssueComment {
    static func mock(id: String, author: String, minutesAgo: Int, body: String) -> IssueComment {
        IssueComment(id: id, author: author,
                     created: Date().addingTimeInterval(-Double(minutesAgo) * 60),
                     bodyText: body)
    }
}
