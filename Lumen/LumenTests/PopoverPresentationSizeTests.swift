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

    /// 응답이 늦게 와도 미리보기는 예약 높이 그대로 — 이게 깨지면 본문이 잘려 보인다.
    func testPreviewKeepsReservedHeightWhenDetailArrivesLate() throws {
        let long = (1...60).map { "설명 \($0)번째 줄 — 재현 절차와 로그를 길게 적어둔 본문입니다." }
            .joined(separator: "\n")
        let detail = IssueDetail.mock(key: "ABC-2001", summary: "긴 설명 렌더링 확인", status: "진행중",
                                      description: long, total: 3, comments: [])

        let size = try presentThenFill(name: "popover-preview-late-detail.png") { filled in
            IssuePreviewPopover(issueKey: detail.key, injectedDetail: filled ? detail : nil)
        }

        XCTAssertEqual(size.after.height, CalendarPreviewMetrics.reservedHeight, accuracy: 1,
                       "본문 도착 후 높이가 예약값과 달라졌다 — popover는 뜬 뒤 못 커지므로 잘린다")
        XCTAssertEqual(size.before.height, size.after.height, accuracy: 1,
                       "로딩 상태와 본문 상태의 높이가 같아야 한다")
    }

    /// 짧은 설명도 같은 높이 — 예약 방식의 대가(아래가 빔)를 명시적으로 박아둔다.
    func testShortDescriptionAlsoUsesReservedHeight() throws {
        let detail = IssueDetail.mock(key: "PPAI-77", summary: "온보딩 화면 카피 최종 검토",
                                      status: "할 일",
                                      description: "디자인 시안 3차 반영본 기준으로 카피만 확정하면 됩니다.",
                                      total: 0, comments: [])
        let size = try presentThenFill(name: "popover-preview-short.png") { filled in
            IssuePreviewPopover(issueKey: detail.key, injectedDetail: filled ? detail : nil)
        }
        XCTAssertEqual(size.after.height, CalendarPreviewMetrics.reservedHeight, accuracy: 1)
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
            IssueCommentsPopover(issueKey: "ABC-1421",
                                 injected: filled ? (total: 12, comments: comments) : nil)
        }
        XCTAssertEqual(size.after.height, CalendarPreviewMetrics.reservedHeight, accuracy: 1,
                       "댓글이 도착해도 로딩 높이에 갇히면 안 된다")
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
