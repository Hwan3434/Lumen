import AppKit
import Carbon.HIToolbox
import SwiftUI

struct JiraProject {
    let key: String
    /// 사용자가 Settings에서 지정한 표시용 별칭. 빈 문자열이면 별칭 없음.
    let name: String
    let color: Color

    /// UI에서 우선 표기할 이름 — 별칭이 있으면 별칭, 없으면 key.
    var displayName: String { name.isEmpty ? key : name }
}

enum KeyCode {
    static let downArrow = 125
    static let upArrow = 126
    static let enter = 36
    static let escape = 53
    static let comma = 43
}

enum Constants {
    // MARK: - Hotkeys
    static let searchHotKeyCode: UInt16 = UInt16(kVK_Space)
    static let searchHotKeyModifiers: UInt32 = UInt32(NSEvent.ModifierFlags.command.rawValue)

    static let translateHotKeyCode: UInt16 = UInt16(kVK_ANSI_C)
    static let translateHotKeyModifiers: UInt32 = UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)

    static let focusHotKeyCode: UInt16 = UInt16(kVK_ANSI_L)
    static let focusHotKeyModifiers: UInt32 = UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)

    static let magnetLeftHotKeyCode: UInt16 = UInt16(kVK_LeftArrow)
    static let magnetLeftHotKeyModifiers: UInt32 = UInt32(NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue)

    static let magnetRightHotKeyCode: UInt16 = UInt16(kVK_RightArrow)
    static let magnetRightHotKeyModifiers: UInt32 = UInt32(NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue)

    // MARK: - Search Window
    static let usagePanelWidth: CGFloat = 260
    static let searchWindowBaseWidth: CGFloat = 680
    // UsagePanel 노출 여부에 따라 너비가 달라진다 — ClaudeUsageService가 없으면 좁은 창.
    static var searchWindowWidth: CGFloat {
        ClaudeUsageService.isAvailable ? searchWindowBaseWidth + usagePanelWidth : searchWindowBaseWidth
    }
    static let searchWindowHeight: CGFloat = 600

    // MARK: - Translator Window
    static let translatorWindowWidth: CGFloat = 760
    static let translatorWindowHeight: CGFloat = 620

    // MARK: - OpenAI
    static let openAIAPIKey = ""
    static let openAIModel = "gpt-4o-mini"

    // MARK: - Jira
    static let jiraCloudId          = ""
    static let jiraEmail            = ""
    static let jiraApiToken         = ""

    /// UserDefaults에 값이 없을 때 쓰이는 기본 프로젝트 목록.
    static let defaultJiraProjectKeys: [String] = ["PPDEV1", "PPAI"]

    /// 프로젝트 색상은 등록 순서에 따라 palette에서 순환 할당된다.
    /// 기존 하드코딩(PPDEV1=cyan, PPAI=purple)과 동일한 결과를 유지하기 위해 선두를 cyan/purple로 둔다.
    static let jiraProjectPalette: [Color] = [.cyan, .purple, .orange, .green, .pink, .yellow, .teal, .red]

    /// 대시보드/서비스가 참조하는 실제 프로젝트 목록.
    /// CredentialsStore(= UserDefaults)의 key 배열과 별칭 매핑 기준으로 매번 생성된다.
    static var jiraProjects: [JiraProject] {
        let store = CredentialsStore.shared
        let keys = store.jiraProjectKeys
        let names = store.jiraProjectNameByKey
        return keys.enumerated().map { idx, key in
            JiraProject(
                key: key,
                name: names[key] ?? "",
                color: jiraProjectPalette[idx % jiraProjectPalette.count]
            )
        }
    }

    static let jiraBrowseURL        = "https://bankx-playplanet.atlassian.net/browse/"
    static let jiraStartDateFieldId = "customfield_10015"   // Jira "Start date" 커스텀 필드 ID
    static let jiraStartDateJQL     = "\"Start date\""      // JQL에서의 동일 필드 표현

    // MARK: - Window Magnet
    static let magnetEnabled = true
    static let magnetSteps: [CGFloat] = [0.2, 0.4, 0.6, 0.8, 1.0]
    static let magnetTolerance: CGFloat = 5.0

    // MARK: - App Search Aliases (bundleID → 검색 키워드)
    // "Code"가 실제 이름인 VSCode를 "vscode"로 검색 가능하게 하는 등의 용도
    static let appAliases: [String: [String]] = [
        "com.microsoft.VSCode":         ["vscode", "vs code"],
        "com.microsoft.VSCodeInsiders": ["vscode insiders", "vs code insiders"],
        "com.apple.finder":             ["finder", "파인더"],
        "com.apple.Terminal":           ["terminal", "터미널"],
        "com.googlecode.iterm2":        ["iterm"],
        "com.apple.dt.Xcode":           ["xcode"],
        "com.tinyspeck.slackmacgap":    ["slack", "슬랙"],
        "com.apple.Safari":             ["safari", "사파리"],
        "com.google.Chrome":            ["chrome", "크롬"],
        "company.thebrowser.Browser":   ["arc", "아크"],
        "com.apple.Notes":              ["notes", "메모"],
        "notion.id":                    ["notion", "노션"],
    ]
}

extension NSScreen {
    static var underMouse: NSScreen {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}

enum DateParsers {
    static let iso8601Full: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
    static let ymd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    static func parseISO8601(_ ts: String) -> Date? {
        iso8601Full.date(from: ts) ?? iso8601Basic.date(from: ts)
    }
}
