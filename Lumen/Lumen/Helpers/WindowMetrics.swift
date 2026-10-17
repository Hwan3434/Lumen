import SwiftUI

extension Constants {
    // MARK: - Search Window
    static let searchWindowWidth: CGFloat = 760
    static let searchWindowHeight: CGFloat = 680

    // MARK: - Translator Window
    static let translatorWindowWidth: CGFloat = 880
    static let translatorWindowHeight: CGFloat = 720
}

extension NSScreen {
    static var underMouse: NSScreen {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
