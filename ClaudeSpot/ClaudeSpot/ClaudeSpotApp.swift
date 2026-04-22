import SwiftUI

@main
struct ClaudeSpotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Cmd+, 로 열리는 기본 설정창 — API 키 입력 UI.
        Settings {
            SettingsView()
        }
    }
}
