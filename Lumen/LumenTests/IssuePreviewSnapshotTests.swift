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

        // ImageRenderer는 ScrollView 컨텐츠를 그리지 못한다(설명·댓글이 통째로 빈다).
        // 실제 창에 올려 레이아웃을 태운 뒤 그 뷰를 캡처해야 눈에 보이는 것과 같아진다.
        let hosting = NSHostingView(rootView: panel)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        window.setIsVisible(true)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        XCTAssertGreaterThan(hosting.bounds.width, 1000, "3개 변형이 가로로 배치돼야 함")
        let rep = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds), "캡처 실패")
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        let dir = ProcessInfo.processInfo.environment["LUMEN_SNAPSHOT_DIR"]
            .map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let out = dir.appendingPathComponent("issue-preview-panel.png")
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: out)
        window.setIsVisible(false)
        print("[snapshot] \(out.path) (\(png.count) bytes, \(Int(hosting.bounds.width))x\(Int(hosting.bounds.height)))")
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
