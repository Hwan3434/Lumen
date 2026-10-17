import SwiftUI

/// 창 크기. 화면 밀도(`LumenDensity`)에 따라 정해진다 — 아주 촘촘은 예전 Lumen 크기, 넓게는 Still 크기.
extension Constants {
    private static func size(_ compact: (CGFloat, CGFloat), _ cozy: (CGFloat, CGFloat),
                             _ regular: (CGFloat, CGFloat), _ spacious: (CGFloat, CGFloat)) -> NSSize {
        let s = LumenDensity.current.pick(compact: compact, cozy: cozy, regular: regular, spacious: spacious)
        return NSSize(width: s.0, height: s.1)
    }

    // MARK: - Search Window
    static let searchWindowSize     = size((680, 600), (680, 600), (720, 640), (760, 680))
    static let searchWindowWidth    = searchWindowSize.width
    static let searchWindowHeight   = searchWindowSize.height

    // MARK: - Translator Window
    static let translatorWindowSize   = size((760, 620), (760, 640), (820, 680), (880, 720))
    static let translatorWindowWidth  = translatorWindowSize.width
    static let translatorWindowHeight = translatorWindowSize.height

    // MARK: - Other panels
    static let noteWindowSize       = size((720, 680), (760, 680), (820, 700), (880, 720))
    static let clipboardWindowSize  = size((720, 560), (760, 600), (800, 640), (800, 640))
    static let jiraWindowSize       = size((1160, 840), (1200, 840), (1260, 860), (1320, 860))
    static let resourceWindowSize   = size((560, 680), (600, 720), (660, 800), (720, 860))
    static let magnetWindowSize     = size((300, 350), (340, 400), (360, 440), (400, 480))
    static let settingsWindowSize   = size((600, 540), (660, 580), (700, 600), (760, 640))
    static let agendaPanelSize      = size((320, 420), (340, 460), (360, 480), (380, 520))

    // MARK: - Jira dashboard columns
    static let jiraPastColumnWidth   = LumenDensity.current.pick(compact: CGFloat(280), cozy: 300, regular: 320, spacious: 340)
    static let jiraFutureColumnWidth = LumenDensity.current.pick(compact: CGFloat(320), cozy: 340, regular: 360, spacious: 380)
}

extension NSScreen {
    static var underMouse: NSScreen {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
