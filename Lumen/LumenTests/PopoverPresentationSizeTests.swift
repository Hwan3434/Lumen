import XCTest
import SwiftUI
import AppKit
@testable import Lumen

/// 실제 `.popover` 표시 경로의 크기를 잰다.
///
/// 스냅샷 테스트(`IssuePreviewSnapshotTests`)는 mock을 동기로 주입하고 `fittingSize`만 재기 때문에
/// 실사용 경로를 밟지 않는다. 실사용에서는 popover가 **로딩 상태로 먼저 뜨고** 나중에 본문이 채워지는데,
/// macOS SwiftUI popover는 표시 시점에 크기가 고정돼 이후 내용이 커져도 창이 자라지 않는다.
/// 그래서 본문 상한을 올려도 앱에서는 계속 작게 보였다.
///
/// 여기서는 진짜 popover를 띄우고, 내용을 나중에 바꿔서 창 크기를 잰다.
@MainActor
final class PopoverPresentationSizeTests: XCTestCase {

    /// 내용이 나중에 커져도 미리보기는 예약 높이 그대로 — 이게 깨지면 본문이 잘려 보인다.
    ///
    /// 주입값을 nil로 두면 실제 Jira로 요청이 나가므로(`fetchIssueDetail`에는 설정 여부 가드가 없다),
    /// 짧은 내용 → 긴 내용 교체로 "표시 후 내용이 커지는" 상황만 재현한다.
    func testPreviewKeepsReservedHeightWhenBodyGrows() throws {
        let short = IssueDetail.mock(key: "ABC-2001", summary: "제목", status: "진행중",
                                     description: "한 줄.", total: 0, comments: [])
        let long = IssueDetail.mock(
            key: "ABC-2001", summary: "긴 설명 렌더링 확인", status: "진행중",
            description: (1...60).map { "설명 \($0)번째 줄 — 재현 절차와 로그를 길게 적어둔 본문입니다." }
                .joined(separator: "\n"),
            total: 3, comments: [])

        let size = try presentThenFill(name: "popover-preview-grown.png") { filled in
            IssuePreviewPopover(issueKey: long.key, injectedDetail: filled ? long : short)
        }

        XCTAssertEqual(size.before.height, size.after.height, accuracy: 1,
                       "짧은 상태와 긴 상태의 높이가 같아야 한다 (예약 높이의 존재 이유)")
        XCTAssertGreaterThanOrEqual(size.after.height, CalendarPreviewMetrics.reservedHeight,
                                    "예약한 높이만큼 확보되지 않았다 — 긴 본문이 잘린다")
    }

    /// ⌘클릭 댓글 팝오버도 `.task`로 뒤늦게 채워지므로 같은 보장이 필요하다.
    func testCommentsPopoverKeepsReservedHeight() throws {
        let comments = (1...12).map { i in
            IssueComment.mock(id: "\(i)", author: ["김철수", "홍길동", "이영희"][i % 3],
                              minutesAgo: (13 - i) * 120,
                              body: "댓글 \(i)번 — 확인했습니다. 재현 조건과 로그를 함께 남깁니다. "
                                  + "길이가 길어져도 잘리지 않고 보여야 합니다.")
        }
        let size = try presentThenFill(name: "popover-comments.png") { filled in
            // 이 팝오버는 주입값을 `.task`에서 state로 옮기므로, 값만 바꾸면 다시 읽지 않는다.
            // .id로 뷰를 새로 만들어 "댓글이 뒤늦게 도착"을 실제로 재현한다.
            IssueCommentsPopover(issueKey: "ABC-1421",
                                 injected: filled ? (total: 12, comments: comments)
                                                  : (total: 12, comments: Array(comments.prefix(1))))
                .id(filled)
        }
        XCTAssertEqual(size.before.height, size.after.height, accuracy: 1,
                       "댓글이 도착해도 처음 높이에 갇히면 안 된다")
        XCTAssertGreaterThanOrEqual(size.after.height, CalendarPreviewMetrics.reservedHeight,
                                    "예약한 높이만큼 확보되지 않았다 — 댓글이 잘린다")
    }

    /// 반대 방향 보장 — 값이 이미 있는 캘린더 이벤트 미리보기까지 예약 높이를 쓰면 안 된다.
    /// 얘는 늦게 채워질 게 없으므로 내용만큼만 떠야 한다.
    func testCalendarEventPreviewStaysContentSized() throws {
        let event = try XCTUnwrap(ExternalCalendarEvent(
            id: "ev-1", title: "주간 스프린트 회고", startDate: Date(),
            endDate: Date().addingTimeInterval(3600), isAllDay: false,
            calendarTitle: "업무", sourceTitle: "Google",
            calendarColor: NSColor.systemBlue.cgColor,
            notes: "지난 스프린트 회고 안건 정리", location: "회의실 A", urlString: nil))

        let size = try presentThenFill(name: "popover-ekevent.png") { _ in
            EKEventPreviewPopover(event: event)
        }
        XCTAssertLessThan(size.after.height, 300,
                          "동기 데이터 팝오버까지 예약 높이를 쓰면 빈 공간만 늘어난다")
    }

    // MARK: - Harness

    private struct Sizes { let before: NSSize; let after: NSSize }

    /// popover를 비어 있는 상태로 띄운 뒤 0.6초 후 데이터를 채워 넣고, 전후 창 크기를 잰다.
    /// 실사용의 "클릭 → 로딩 → 응답 도착" 순서를 그대로 흉내낸다.
    private func presentThenFill(name: String,
                                 @ViewBuilder content: @escaping (Bool) -> some View) throws -> Sizes {
        let hosting = NSHostingView(rootView: LatePopoverHost(content: content))
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let window = NSWindow(contentRect: NSRect(x: screen.visibleFrame.midX - 200,
                                                  y: screen.visibleFrame.midY - 150,
                                                  width: 400, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)

        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let before = try popoverSize(of: window)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let after = try popoverSize(of: window)

        capture(window, named: name)
        window.orderOut(nil)
        print("[popover] \(name) \(Int(before.width))x\(Int(before.height))"
              + " → \(Int(after.width))x\(Int(after.height))")
        return Sizes(before: before, after: after)
    }

    /// 반환값은 popover **창**의 contentView 크기 — SwiftUI content보다 화살표·여백만큼(약 26pt) 크다.
    /// 그래서 예약 높이와는 `>=`로 비교한다.
    private func popoverSize(of window: NSWindow) throws -> NSSize {
        let popover = try XCTUnwrap((window.childWindows ?? []).first {
            String(describing: type(of: $0)).contains("Popover")
        }, "popover 창을 못 찾음")
        return popover.contentView?.bounds.size ?? popover.frame.size
    }

    /// 눈으로도 확인할 수 있게 popover 내용을 PNG로 떨군다. 경로는 `LUMEN_SNAPSHOT_DIR`.
    private func capture(_ window: NSWindow, named name: String) {
        guard let view = (window.childWindows ?? []).first(where: {
            String(describing: type(of: $0)).contains("Popover")
        })?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let dir = ProcessInfo.processInfo.environment["LUMEN_SNAPSHOT_DIR"]
            .map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: NSTemporaryDirectory())
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        let out = dir.appendingPathComponent(name)
        try? png.write(to: out)
        print("[snapshot] \(out.path)")
    }
}

/// popover를 먼저 띄우고 0.6초 뒤에 데이터를 채운다 — 네트워크 응답 도착을 흉내내는 앵커 뷰.
private struct LatePopoverHost<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content
    @State private var shown = false
    @State private var filled = false

    var body: some View {
        Color.gray.opacity(0.2)
            .frame(width: 120, height: 24)
            .popover(isPresented: $shown, arrowEdge: .top) { content(filled) }
            .onAppear {
                shown = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { filled = true }
            }
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
