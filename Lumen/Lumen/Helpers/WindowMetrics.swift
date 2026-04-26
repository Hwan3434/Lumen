import SwiftUI

extension Constants {
    // MARK: - Search Window
    static let usagePanelWidth: CGFloat = 260
    static let searchWindowBaseWidth: CGFloat = 680
    /// UsagePanel 노출 여부에 따라 너비가 달라진다 — ClaudeUsageService가 없으면 좁은 창.
    static var searchWindowWidth: CGFloat {
        ClaudeUsageService.isAvailable ? searchWindowBaseWidth + usagePanelWidth : searchWindowBaseWidth
    }
    static let searchWindowHeight: CGFloat = 600

    // MARK: - Translator Window
    static let translatorWindowWidth: CGFloat = 760
    static let translatorWindowHeight: CGFloat = 620
}

extension NSScreen {
    static var underMouse: NSScreen {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
