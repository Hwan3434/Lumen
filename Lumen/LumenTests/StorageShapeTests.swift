import XCTest
@testable import Lumen

/// 저장된 사용자 데이터의 이름과 모양을 고정한다. 키·파일 이름·JSON 필드가 바뀌면 기존 사용자 데이터를 못 읽어 사라진다.
/// 여기가 실패하면 고정값을 고치지 말고, 옛 이름을 읽어 새 이름으로 옮기는 코드를 먼저 두세요.
final class StorageShapeTests: XCTestCase {
    private let appRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Lumen")

    private func source(_ path: String) throws -> String {
        try String(contentsOf: appRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private var allAppSource: String {
        get throws {
            let paths = FileManager.default.enumerator(atPath: appRoot.path)?.compactMap { $0 as? String } ?? []
            return try paths.filter { $0.hasSuffix(".swift") }.map(source).joined(separator: "\n")
        }
    }

    func testUserDefaultsKeysAreUnchanged() throws {
        let text = try allAppSource
        let keys = [
            "lumen.ui.density", "lumen.ui.appearance", "lumen.ui.glass.transparency",
            "memory_trace_enabled", "didPurgeRetiredFilesV1",
            "lidAwake.ownedByLumen", "lidAwake.batteryHours",
            "schedule.showLunar", "schedule.dashboard", "Lumen.appUsageCounts",
        ]
        for key in keys {
            XCTAssertTrue(text.contains("\"\(key)\""), "UserDefaults 키 \(key)가 소스에서 사라졌어요. 기존 키 이름은 바꾸지 마세요.")
        }
        XCTAssertEqual(PluginSettings.key(for: .calendar), "schedule.calendar")
        XCTAssertEqual(PluginSettings.key(for: .local), "schedule.local")
        XCTAssertEqual(PluginSettings.key(for: .jira), "schedule.jira")
    }

    func testStorageFileNamesAreUnchanged() {
        let expected: [(LumenStorage.Slot, String)] = [
            (.translationHistory, "translation_history.json"), (.legacyNote, "note.md"), (.notesDir, "notes"),
            (.clipboardHistory, "clipboard_history.json"), (.clipboardImagesDir, "images"),
            (.hiddenApps, "hidden_apps.json"), (.resourceAnomalies, "resource_anomalies.json"),
            (.currencyRates, "currency_rates.json"), (.localEvents, "local_events.json"),
            (.scheduleCacheDir, "schedule_cache"),
        ]
        for (slot, name) in expected {
            XCTAssertEqual(slot.relativePath, name, "저장 파일 이름이 바뀌었어요. 기존 파일 이름은 바꾸지 마세요.")
        }
    }

    /// 지금 형식의 JSON을 읽고 다시 써서 같은 모양이 나오는지 본다. 필드를 더하거나 빼거나 이름을 바꾸면 실패한다.
    private func assertShape<T: Codable>(_ type: T.Type, _ json: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = Data(json.utf8)
        let decoded: T
        do { decoded = try JSONDecoder().decode(T.self, from: data) } catch {
            return XCTFail("\(T.self)가 기존 형식의 JSON을 못 읽어요: \(error). 새 필드는 옵셔널로 두거나 init(from:)에서 기본값을 주세요.", file: file, line: line)
        }
        let reencoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? NSObject
        let original = try JSONSerialization.jsonObject(with: data) as? NSObject
        XCTAssertEqual(reencoded, original, "\(T.self)를 다시 쓴 JSON 모양이 기존과 달라요. 기존 필드 이름과 형식은 바꾸지 마세요.", file: file, line: line)
    }

    func testSavedSettingsKeepTheirShape() throws {
        try assertShape(DashboardSettings.self, #"{"menuBarLabel":true,"defaultView":"month","weekStartsOn":"sunday"}"#)
        try assertShape(CalendarSettings.self, #"{"enabled":true,"hiddenCalendarIDs":["A"],"useAppColors":false,"inMenuBar":true}"#)
        try assertShape(LocalSettings.self, #"{"isVisible":true}"#)
        try assertShape(JiraSettings.self, #"{"enabled":true,"projects":[{"key":"LUM","alias":"루멘","isVisible":true}],"showSprints":true,"showEpics":true,"showDone":false}"#)
    }

    func testSavedFilesKeepTheirShape() throws {
        try assertShape([LocalEvent].self, #"[{"id":"9A1C5E2B-0000-4000-8000-000000000001","title":"회의","start":700000000,"end":700003600}]"#)
        try assertShape([ResourceAnomaly].self, #"[{"id":"9A1C5E2B-0000-4000-8000-000000000002","timestamp":700000000,"kind":"memoryHigh","message":"m","memoryMB":512.5,"cpuPercent":12.5,"threadCount":30}]"#)
        try assertShape(Set<String>.self, #"["com.apple.Safari"]"#)
    }

    /// 클립보드·번역 기록의 저장 타입은 private이라 테스트가 직접 만들 수 없다. 선언 필드를 고정한다.
    func testPrivateSavedItemFieldsAreUnchanged() throws {
        let expected: [(String, [String])] = [
            ("Features/Clipboard/ClipboardStore.swift", [
                "let id: String", "let date: Date", "let text: String?", "let filePaths: [String]?",
                "let imagePath: String?", "let sourceApp: String?", "let sourceAppBundleID: String?",
            ]),
            ("Features/Translator/TranslatorViewModel.swift", [
                "let id: String", "let original: String", "let translated: String", "let date: Date",
            ]),
        ]
        for (path, fields) in expected {
            let text = try source(path)
            let block = try XCTUnwrap(text.components(separatedBy: "private struct SavedItem: Codable {").dropFirst().first?
                .components(separatedBy: "}").first, "\(path)에서 SavedItem을 못 찾았어요.")
            let actual = block.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            XCTAssertEqual(actual, fields, "\(path)의 SavedItem 필드가 바뀌었어요. 기존 사용자 기록을 못 읽게 돼요. 필드는 바꾸지 말고, 더할 때는 옵셔널로 두고 이 목록도 고치세요.")
        }
    }
}
