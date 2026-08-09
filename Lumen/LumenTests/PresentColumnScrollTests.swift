import XCTest
import SwiftUI
import AppKit
@testable import Lumen

/// 가운데 컬럼이 실제로 스크롤되는지 뷰 계층에서 직접 측정한다.
/// SwiftUI ScrollView는 macOS에서 NSScrollView로 내려가므로,
/// documentView 높이 > clip 높이면 스크롤 가능한 상태다.
@MainActor
final class PresentColumnScrollTests: XCTestCase {

    /// 대시보드 패널 실제 크기 기준 — 가운데 컬럼은 1160에서 좌우 컬럼(280/320)을 뺀 폭을 쓴다.
    private let columnWidth: CGFloat = 1160 - 280 - 320
    private let panelHeight: CGFloat = 840

    func testPresentColumnScrollsWhenContentOverflows() throws {
        // 한 화면에 절대 안 들어갈 분량.
        let many = (1...40).map { i in
            JiraIssue.scrollMock(key: "ABC-\(1000 + i)", summary: "밀린 작업 \(i)번 — 확인 필요")
        }
        let data = JiraDashboardData.scrollMock(overdue: many, thisWeek: many)

        let (scrollView, hosting) = try hostColumn(data: data)
        let docHeight = try XCTUnwrap(scrollView.documentView?.frame.height)
        let clipHeight = scrollView.contentView.bounds.height

        print("[scroll] 컬럼=\(Int(hosting.bounds.width))x\(Int(hosting.bounds.height)) "
              + "content=\(Int(docHeight)) clip=\(Int(clipHeight))")

        XCTAssertEqual(clipHeight, panelHeight, accuracy: 1,
                       "스크롤 영역이 패널 높이에 맞춰져야 한다")
        XCTAssertGreaterThan(docHeight, clipHeight,
                             "내용이 넘치면 documentView가 clip보다 커야 스크롤된다")

        // 실제로 스크롤이 먹는지 — 맨 아래로 보냈을 때 원점이 움직여야 한다.
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: docHeight - clipHeight))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        XCTAssertGreaterThan(scrollView.contentView.bounds.origin.y, 0, "스크롤 위치가 반영되지 않음")
    }

    func testPresentColumnDoesNotScrollWhenContentFits() throws {
        let data = JiraDashboardData.scrollMock(overdue: [], thisWeek: [
            JiraIssue.scrollMock(key: "ABC-1", summary: "짧은 목록"),
        ])

        let (scrollView, _) = try hostColumn(data: data)
        let docHeight = try XCTUnwrap(scrollView.documentView?.frame.height)
        XCTAssertLessThanOrEqual(docHeight, scrollView.contentView.bounds.height + 1,
                                 "내용이 짧으면 스크롤 영역이 생기지 않아야 한다")
    }

    /// 실제 대시보드 계층(3-column HStack + 하단 TrendChart)에 올렸을 때도 스크롤되는지.
    /// 컬럼만 떼어 높이를 직접 준 경우와 달리, 여기서는 부모가 높이를 어떻게 나눠주는지가 관건이다.
    func testPresentColumnScrollsInsideDashboardContent() throws {
        let many = (1...40).map { i in
            JiraIssue.scrollMock(key: "ABC-\(2000 + i)", summary: "밀린 작업 \(i)번 — 확인 필요")
        }
        let data = JiraDashboardData.scrollMock(overdue: many, thisWeek: many)

        let content = DashboardContent(data: data, selectedProject: .constant(PresentColumn.allKey))
            .frame(width: 1160, height: 840)

        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 1160, height: 840)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        window.setIsVisible(true)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        addTeardownBlock { window.setIsVisible(false) }

        let scrollViews = hosting.allScrollViews()
        for sv in scrollViews {
            let origin = sv.convert(NSPoint.zero, to: hosting)
            let doc = sv.documentView?.frame.height ?? -1
            print("[scroll] x=\(Int(origin.x)) w=\(Int(sv.bounds.width)) "
                  + "clip=\(Int(sv.contentView.bounds.height)) content=\(Int(doc))")
        }

        // 가운데 컬럼 = 좌우 고정폭(280/320)이 아닌 것.
        let middle = try XCTUnwrap(
            scrollViews.first { abs($0.bounds.width - 280) > 1 && abs($0.bounds.width - 320) > 1 },
            "가운데 컬럼의 ScrollView를 찾지 못함")

        let docHeight = try XCTUnwrap(middle.documentView?.frame.height)
        let clipHeight = middle.contentView.bounds.height
        XCTAssertGreaterThan(clipHeight, 0, "가운데 컬럼에 높이가 배분되지 않았다")
        XCTAssertGreaterThan(docHeight, clipHeight, "내용이 넘치는데 스크롤 영역이 생기지 않았다")
    }

    // MARK: - Helpers

    private func hostColumn(data: JiraDashboardData) throws -> (NSScrollView, NSHostingView<some View>) {
        let column = PresentColumn(data: data, selectedProject: .constant(PresentColumn.allKey))
            .frame(width: columnWidth, height: panelHeight)

        let hosting = NSHostingView(rootView: column)
        hosting.frame = NSRect(x: 0, y: 0, width: columnWidth, height: panelHeight)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        window.setIsVisible(true)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        addTeardownBlock { window.setIsVisible(false) }

        let found = try XCTUnwrap(hosting.firstScrollView(), "NSScrollView를 찾지 못함 — ScrollView가 안 붙었다는 뜻")
        return (found, hosting)
    }
}

private extension NSView {
    func firstScrollView() -> NSScrollView? {
        if let s = self as? NSScrollView { return s }
        for sub in subviews {
            if let found = sub.firstScrollView() { return found }
        }
        return nil
    }

    func allScrollViews() -> [NSScrollView] {
        var out: [NSScrollView] = []
        if let s = self as? NSScrollView { out.append(s) }
        for sub in subviews { out += sub.allScrollViews() }
        return out
    }
}

private extension JiraIssue {
    static func scrollMock(key: String, summary: String) -> JiraIssue {
        JiraIssue(id: key, key: key, summary: summary, status: "진행중",
                  statusCategory: .indeterminate, priority: "Medium",
                  startDate: nil, dueDate: Date().addingTimeInterval(-86_400),
                  resolutionDate: nil, created: nil, issueType: "Task",
                  projectKey: key.split(separator: "-").first.map(String.init) ?? "ABC")
    }
}

private extension JiraDashboardData {
    static func scrollMock(overdue: [JiraIssue], thisWeek: [JiraIssue]) -> JiraDashboardData {
        JiraDashboardData(
            thisWeekCounts: JiraStatusCounts(),
            projectStats: [],
            todayIssues: [],
            thisWeekIssues: thisWeek,
            highestIncomplete: [],
            overdueIncomplete: overdue,
            completedLast30: [],
            createdLast30: [],
            nextWeekIssues: [],
            backlogCountByProject: [:],
            sprintInfos: [],
            epicInfos: [],
            allIssuesInWindow: [],
            lastUpdated: Date()
        )
    }
}
