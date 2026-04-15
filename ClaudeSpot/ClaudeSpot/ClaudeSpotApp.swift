import SwiftUI

@main
struct ClaudeSpotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 빈 Settings로 기본 윈도우 생성 방지
        Settings {
            EmptyView()
        }
    }
}
