import XCTest

/// 지침 문장 대신 레포 규칙을 테스트로 막는다. 실패 메시지에 무엇을 대신 할지 적는다.
final class RepoRulesTests: XCTestCase {
    private let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private var pbxproj: String {
        get throws {
            try String(contentsOf: projectRoot.appendingPathComponent("Lumen.xcodeproj/project.pbxproj"), encoding: .utf8)
        }
    }

    private func swiftFiles(in folder: String) throws -> [(name: String, text: String)] {
        let base = projectRoot.appendingPathComponent(folder)
        let paths = FileManager.default.enumerator(atPath: base.path)?.compactMap { $0 as? String } ?? []
        return try paths.filter { $0.hasSuffix(".swift") }.map {
            ($0, try String(contentsOf: base.appendingPathComponent($0), encoding: .utf8))
        }
    }

    func testProjectFileHasNoSourceFileReferences() throws {
        let lines = try pbxproj.split(separator: "\n").filter {
            $0.contains("isa = PBXFileReference") && $0.contains(".swift")
        }
        XCTAssertEqual(lines, [], """
            project.pbxproj에 Swift 파일 참조가 생겼어요. 폴더 동기화 프로젝트라 파일은 폴더에 만들기만 하면 타겟에 들어가요. \
            project.pbxproj를 되돌리고 파일만 두세요.
            """)
    }

    // 서명이 바뀌면 macOS가 다른 앱으로 보고 손쉬운 사용 권한을 다시 묻는다(docs/decisions.md).
    func testEveryTargetConfigSignsWithPersonalTeam() throws {
        let text = try pbxproj
        let message = """
            앱·테스트 타겟의 Debug·Release 네 구성 모두 무료 개발자 팀 928X8H4B4T의 Apple Development 인증서로 서명해야 해요. \
            DEVELOPMENT_TEAM과 CODE_SIGN_IDENTITY를 되돌리세요.
            """
        XCTAssertEqual(text.components(separatedBy: "DEVELOPMENT_TEAM = 928X8H4B4T;").count - 1, 4, message)
        XCTAssertEqual(text.components(separatedBy: "\"CODE_SIGN_IDENTITY[sdk=macosx*]\" = \"Apple Development\";").count - 1, 4, message)
        XCTAssertFalse(text.contains("CODE_SIGN_IDENTITY = \"-\""), message)
        XCTAssertFalse(text.range(of: "DEVELOPMENT_TEAM = (?!928X8H4B4T;)", options: .regularExpression) != nil, message)
    }

    // 테스트 호스트가 실제 앱이라 공유 저장소에 쓰면 설치된 Lumen의 데이터가 바뀐다.
    func testTestsDoNotWriteSharedAppStorage() throws {
        let forbidden = [
            ("UserDefaults.standard", "UserDefaults(suiteName:)에 테스트 전용 이름을 주세요"),
            ("LumenStorage.baseURL = ", "저장 경로를 임시 폴더로 주입하세요"),
            (".saved = ", "LumenUIStore.shared의 메모리 값만 바꾸세요(SnapshotEnvironment)"),
        ]
        for file in try swiftFiles(in: "LumenTests") where file.name != "RepoRulesTests.swift" {
            for (pattern, fix) in forbidden {
                XCTAssertFalse(file.text.contains(pattern), "\(file.name)에서 \(pattern)를 써요. 테스트 호스트는 실제 앱이라 \(fix).")
            }
        }
    }

    func testAppCodeUsesDesignTokensForColorAndFont() throws {
        let forbidden = ["Color(red:", "Color(.sRGB", "NSColor(red:", ".font(.system(size:", "NSFont.systemFont(ofSize:"]
        for file in try swiftFiles(in: "Lumen") where !file.name.hasPrefix("DesignSystem/") {
            for pattern in forbidden {
                XCTAssertFalse(file.text.contains(pattern), "\(file.name)에서 \(pattern)를 써요. DESIGN.md의 색·글꼴 토큰을 쓰고, 없으면 DesignSystem/에 토큰을 더하세요.")
            }
        }
    }
}
