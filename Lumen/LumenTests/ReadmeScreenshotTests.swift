import AppKit
import SwiftUI
import XCTest
@testable import Lumen

/// README 스크린샷을 예시 데이터로 그린다. 실제 앱 화면을 찍으면 클립보드·노트·설정 값이 그대로 찍히기 때문이다.
/// `TEST_RUNNER_LUMEN_SNAPSHOT_DIR=<폴더>` 를 주고 돌릴 때만 실행된다.
@MainActor
final class ReadmeScreenshotTests: XCTestCase {

    private var outDir: URL!

    override func setUp() async throws { SnapshotEnvironment.applyUIOverrides() }
    override func tearDown() async throws { SnapshotEnvironment.restoreUI() }

    override func setUpWithError() throws {
        let dir = ProcessInfo.processInfo.environment["LUMEN_SNAPSHOT_DIR"]
        try XCTSkipUnless(dir != nil, "README 스크린샷은 LUMEN_SNAPSHOT_DIR 를 줄 때만 만든다")
        outDir = URL(fileURLWithPath: dir!)
    }

    func testSearch() throws {
        let vm = SearchViewModel()
        vm.query = "100 usd"
        try render(SearchView(viewModel: vm), size: Constants.searchWindowSize, named: "Lumen.png")
    }

    func testTranslator() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("readme-translation-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let vm = TranslatorViewModel(savePath: file)
        for (original, translated) in [
            ("오늘 회의는 3시로 옮겼어요.", "Today's meeting has been moved to 3 PM."),
            ("release notes", "릴리스 노트"),
            ("Thanks for the quick review. I'll update the docs today.",
             "빠르게 리뷰해 주셔서 고마워요. 오늘 문서를 고칠게요."),
        ] {
            vm.inputText = original
            vm.handleTranslationResult(original: original, translated: translated)
        }
        try render(TranslatorView(viewModel: vm), size: Constants.translatorWindowSize, named: "Translator.png")
    }

    func testNote() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("readme-notes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let notes = [
            ("1", "# 이번 주 할 일\n\n- [x] 일정 플러그인 문서 정리\n- [ ] 릴리스 노트 쓰기\n- [ ] 클립보드 검색 개선\n\n## 메모\n\n목요일 오후에 **디자인 리뷰**. 화면 시안은 `docs/screenshots` 에 모아 두기."),
            ("2", "# 장보기\n\n- 우유\n- 달걀\n- 커피 원두"),
            ("3", "# 읽을거리\n\n- Swift Concurrency 정리\n- SwiftUI 레이아웃 가이드"),
        ]
        for (id, text) in notes {
            try text.write(to: dir.appendingPathComponent("\(id).md"), atomically: true, encoding: .utf8)
        }
        try JSONEncoder().encode(notes.map(\.0)).write(to: dir.appendingPathComponent(".order.json"))
        try render(NoteView(viewModel: NotesViewModel(notesDir: dir)), size: Constants.noteWindowSize, named: "Note.png")
    }

    /// 공용 `ClipboardStore.shared` 의 메모리 속 기록만 잠깐 바꿔 그리고 되돌린다. 디스크 저장은 부르지 않는다.
    func testClipboard() throws {
        let store = ClipboardStore.shared
        store.stopMonitoring()
        let saved = store.history
        defer { store.history = saved }

        // 이미지 항목은 파일 경로만 들고 있으므로 예시 그림을 임시 파일로 둔다.
        let imageFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("readme-clipboard-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: imageFile) }
        let tiff = try XCTUnwrap(Self.sampleImage().tiffRepresentation)
        try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])).write(to: imageFile)

        let now = Date()
        func text(_ s: String, _ app: String, _ bundle: String, _ minutesAgo: Double) -> ClipboardItem {
            ClipboardItem(date: now.addingTimeInterval(-minutesAgo * 60), text: s, fileURLs: nil,
                          sourceApp: app, sourceAppBundleID: bundle)
        }
        store.history = [
            text("회의는 목요일 오후 3시로 옮겼어요. 장소는 3층 회의실입니다.", "메모", "com.apple.Notes", 1),
            text("https://developer.apple.com/documentation/swiftui", "Safari", "com.apple.Safari", 4),
            text("git switch -c feat/new_panel", "터미널", "com.apple.Terminal", 9),
            ClipboardItem(date: now.addingTimeInterval(-15 * 60), text: nil, fileURLs: nil, imagePath: imageFile.path,
                          sourceApp: "미리보기", sourceAppBundleID: "com.apple.Preview"),
            ClipboardItem(date: now.addingTimeInterval(-30 * 60), text: nil,
                          fileURLs: [URL(fileURLWithPath: "/Users/Shared/기획안.pdf")],
                          sourceApp: "Finder", sourceAppBundleID: "com.apple.finder"),
            text("let total = items.reduce(0) { $0 + $1.price }", "Xcode", "com.apple.dt.Xcode", 42),
            text("서울특별시 중구 세종대로 110", "지도", "com.apple.Maps", 75),
        ]
        try render(ClipboardView(), size: Constants.clipboardWindowSize, named: "Clipboard.png")
    }

    func testSettings() throws {
        // 유리 효과가 켜져 있으면 설정 화면은 배경을 창에 맡겨 투명하다. 창 없이 그리므로 바탕색을 깐다.
        try render(SettingsView().background(LumenTokens.Palette.surface),
                   size: Constants.settingsWindowSize, named: "Settings.png")
    }

    // MARK: - Helpers

    private static func sampleImage() -> NSImage {
        let size = NSSize(width: 480, height: 300)
        return NSImage(size: size, flipped: false) { rect in
            NSGradient(colors: [.systemTeal, .systemIndigo])?.draw(in: rect, angle: 35)
            return true
        }
    }

    private func render(_ view: some View, size: NSSize, named name: String) throws {
        // 토큰 색은 앱 전체 appearance 를 따른다. 창에만 dark 를 주면 설정 화면처럼 배경이 밝게 섞인다.
        let previousAppearance = NSApp.appearance
        NSApp.appearance = SnapshotEnvironment.appearance
        defer { NSApp.appearance = previousAppearance }
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, SnapshotEnvironment.colorScheme))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = SnapshotEnvironment.appearance
        window.contentView = hosting
        window.setIsVisible(true)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))

        let rep = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds), "캡처 실패")
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: outDir.appendingPathComponent(name))
        window.setIsVisible(false)
    }
}
