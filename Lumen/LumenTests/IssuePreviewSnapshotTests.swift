import XCTest
import SwiftUI
import AppKit
@testable import Lumen

/// Jira 연결 없이 미리보기 팝오버의 실제 레이아웃을 눈으로 확인하기 위한 패널.
/// mock IssueDetail을 주입해 오프스크린 렌더링하고 PNG로 떨군다.
///
/// 출력 경로는 환경변수 `LUMEN_SNAPSHOT_DIR`, 없으면 임시 디렉터리.
@MainActor
final class IssuePreviewSnapshotTests: XCTestCase {

    func testRenderIssuePreviewVariants() throws {
        let variants: [(String, IssueDetail)] = [
            ("01-댓글3개", .mock(
                key: "ABC-1421",
                summary: "결제 모듈 타임아웃 재현 및 원인 분석",
                status: "진행중",
                description: """
                결제 승인 요청이 간헐적으로 30초 타임아웃에 걸립니다.
                재현 조건은 동시 요청 50건 이상이며, PG사 응답 지연과 겹칠 때 발생합니다.
                우선 커넥션 풀 설정부터 확인이 필요합니다.
                """,
                total: 5,
                comments: [
                    .mock(id: "1", author: "김철수", minutesAgo: 60 * 26,
                          body: "커넥션 풀 max가 8로 잡혀 있었습니다. 우선 32로 올려봤어요."),
                    .mock(id: "2", author: "홍길동", minutesAgo: 60 * 3,
                          body: "@김철수 그 설정 스테이징에도 반영됐나요? 어제 테스트에선 여전히 재현됐습니다."),
                    .mock(id: "3", author: "이영희", minutesAgo: 25,
                          body: "PG사에서 회신 왔습니다. 자기네 배치 시간대(02:00~02:30)와 겹치는 구간이라고 하네요."),
                ])),
            ("02-댓글없음", .mock(
                key: "PPAI-77",
                summary: "온보딩 화면 카피 최종 검토",
                status: "할 일",
                description: "디자인 시안 3차 반영본 기준으로 카피만 확정하면 됩니다.",
                total: 0,
                comments: [])),
            ("03-첨부만-긴제목", .mock(
                key: "ABC-999",
                summary: "월간 리포트 자동 생성 파이프라인 구축 — 데이터 수집부터 배포까지 전 구간",
                status: "코드 리뷰",
                description: "",
                total: 12,
                comments: [
                    .mock(id: "1", author: "박민수", minutesAgo: 60 * 24 * 3, body: ""),
                    .mock(id: "2", author: "최지우", minutesAgo: 5,
                          body: "스크린샷 첨부합니다. 두 번째 그래프 축 라벨이 잘리네요."),
                ])),
        ]

        let panel = HStack(alignment: .top, spacing: 24) {
            ForEach(Array(variants.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.0)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    // 실제 popover는 형제가 없으므로 이상 높이를 갖는다. 이걸 빼면 옆 패널
                    // 높이에 맞춰 ScrollView가 늘어나 없는 여백이 있는 것처럼 보인다.
                    IssuePreviewPopover(issueKey: item.1.key, injectedDetail: item.1)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.12), lineWidth: 0.5))
                }
            }
        }
        .padding(28)
        .background(Color(red: 0.05, green: 0.05, blue: 0.06))
        .environment(\.colorScheme, .dark)

        try render(panel, named: "issue-preview-panel.png")
    }

    /// 기한 초과 섹션의 펼침/접힘 두 상태를 나란히 확인한다.
    func testRenderOverdueSectionCollapsedAndExpanded() throws {
        let items = [
            JiraIssue.mock(key: "ABC-1180", summary: "결제 실패 로그 수집기 배포", priority: "Highest",
                           status: "진행중", category: .indeterminate, dueDaysAgo: 12),
            JiraIssue.mock(key: "ABC-1204", summary: "정산 배치 재실행 스크립트 정리", priority: "High",
                           status: "할 일", category: .new, dueDaysAgo: 5),
            JiraIssue.mock(key: "PPAI-31", summary: "온보딩 A/B 결과 리포트", priority: "Medium",
                           status: "진행중", category: .indeterminate, dueDaysAgo: 2),
        ]

        let panel = HStack(alignment: .top, spacing: 24) {
            ForEach([true, false], id: \.self) { expanded in
                VStack(alignment: .leading, spacing: 8) {
                    Text(expanded ? "펼침" : "접힘")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    let key = "snapshotOverdueExpanded-\(expanded)"
                    IssueListSection(
                        icon: "exclamationmark.triangle",
                        iconColor: LumenTokens.ErrorTone.icon,
                        title: "기한 초과 미완료",
                        items: items,
                        emptyText: "기한 초과 없음",
                        hideWhenEmpty: true,
                        collapseKey: key
                    )
                    .frame(width: 380, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(28)
        .background(Color(red: 0.05, green: 0.05, blue: 0.06))
        .environment(\.colorScheme, .dark)

        // @AppStorage가 읽어갈 값을 렌더 전에 심어둔다.
        UserDefaults.standard.set(true, forKey: "snapshotOverdueExpanded-true")
        UserDefaults.standard.set(false, forKey: "snapshotOverdueExpanded-false")
        defer {
            UserDefaults.standard.removeObject(forKey: "snapshotOverdueExpanded-true")
            UserDefaults.standard.removeObject(forKey: "snapshotOverdueExpanded-false")
        }

        try render(panel, named: "overdue-section.png")
    }

    /// 세 컬럼의 모든 섹션이 접기 가능한지 — 전부 펼친 상태와 전부 접은 상태를 나란히.
    func testRenderAllSectionsCollapsedAndExpanded() throws {
        let issues = (1...4).map {
            JiraIssue.mock(key: "ABC-\(1300 + $0)", summary: "작업 \($0)", priority: "High",
                           status: "진행중", category: .indeterminate, dueDaysAgo: $0)
        }
        let data = JiraDashboardData.sectionMock(issues: issues)
        let keys = [JiraSectionKey.overdue, JiraSectionKey.thisWeek, JiraSectionKey.highest,
                    JiraSectionKey.nextWeek, JiraSectionKey.backlog, JiraSectionKey.sprints,
                    JiraSectionKey.epics]

        for expanded in [true, false] {
            keys.forEach { UserDefaults.standard.set(expanded, forKey: $0) }
            let content = DashboardContent(data: data,
                                           selectedProject: .constant(PresentColumn.allKey))
                .frame(width: 1160, height: 840)
                .environment(\.colorScheme, .dark)
            try render(content, named: "sections-\(expanded ? "expanded" : "collapsed").png")
        }
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    /// 본문이 길 때 실제로 커지는지 — 화면 여유에 맞춰 상한이 정해지므로 값도 같이 남긴다.
    func testLongDescriptionUsesEnlargedBody() throws {
        let screen = NSScreen.main?.visibleFrame.height ?? 0
        print("[metrics] 화면여유=\(Int(screen)) 본문최대=\(Int(CalendarPreviewMetrics.bodyMaxHeight)) "
              + "댓글동반=\(Int(CalendarPreviewMetrics.bodyMaxHeightWithComments))")

        XCTAssertGreaterThan(CalendarPreviewMetrics.bodyMaxHeight, 520,
                             "본문 상한이 이전(520)보다 커져야 한다")
        XCTAssertGreaterThan(CalendarPreviewMetrics.bodyMaxHeightWithComments, 260,
                             "댓글이 있어도 이전(260)보다 커져야 한다")

        let long = (1...60).map { "설명 \($0)번째 줄 — 재현 절차와 로그를 길게 적어둔 본문입니다." }
            .joined(separator: "\n")
        let detail = IssueDetail.mock(key: "ABC-2001", summary: "긴 설명 렌더링 확인",
                                      status: "진행중", description: long, total: 0, comments: [])

        let popover = IssuePreviewPopover(issueKey: detail.key, injectedDetail: detail)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            .padding(24)
            .background(Color(red: 0.05, green: 0.05, blue: 0.06))
            .environment(\.colorScheme, .dark)

        let hosting = NSHostingView(rootView: popover)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        XCTAssertGreaterThan(hosting.bounds.height, 700,
                             "긴 설명이면 팝오버가 이전 상한 근처보다 확실히 커져야 한다")
        print("[metrics] 긴 설명 팝오버 = \(Int(hosting.bounds.width))x\(Int(hosting.bounds.height))")

        try render(popover, named: "long-description.png")
    }

    // MARK: - Rendering

    private func render(_ view: some View, named name: String) throws {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        window.setIsVisible(true)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        let rep = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds), "캡처 실패")
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let dir = ProcessInfo.processInfo.environment["LUMEN_SNAPSHOT_DIR"]
            .map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let out = dir.appendingPathComponent(name)
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: out)
        window.setIsVisible(false)
        print("[snapshot] \(out.path) (\(png.count) bytes, \(Int(hosting.bounds.width))x\(Int(hosting.bounds.height)))")
    }
}

private extension JiraIssue {
    static func mock(key: String, summary: String, priority: String, status: String,
                     category: JiraStatusCategory, dueDaysAgo: Int) -> JiraIssue {
        JiraIssue(
            id: key, key: key, summary: summary, status: status, statusCategory: category,
            priority: priority, startDate: nil,
            dueDate: Calendar.current.date(byAdding: .day, value: -dueDaysAgo, to: Date()),
            resolutionDate: nil, created: nil, issueType: "Task",
            projectKey: key.split(separator: "-").first.map(String.init) ?? "ABC"
        )
    }
}

private extension JiraDashboardData {
    /// 세 컬럼의 섹션이 모두 그려지도록 각 목록을 채운 mock.
    static func sectionMock(issues: [JiraIssue]) -> JiraDashboardData {
        JiraDashboardData(
            thisWeekCounts: JiraStatusCounts(),
            projectStats: [],
            todayIssues: [],
            thisWeekIssues: issues,
            highestIncomplete: issues,
            overdueIncomplete: issues,
            completedLast30: [],
            createdLast30: [],
            nextWeekIssues: issues,
            backlogCountByProject: [:],
            sprintInfos: [],
            epicInfos: [],
            allIssuesInWindow: [],
            lastUpdated: Date()
        )
    }
}

// MARK: - Mock builders

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
