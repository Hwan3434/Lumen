import AppKit
import Carbon.HIToolbox

final class NoteFeature: BuiltInFeature {
    let name = "메모"
    let featureDescription = "빠른 메모장"
    let iconName = "note.text"
    let searchKeywords = ["메모", "노트", "note", "memo"]

    let windowController = NoteWindowController()

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: UInt16(kVK_ANSI_X),
                modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
                description: "Cmd+Shift+X",
                action: { [weak self] in
                    self?.activate()
                }
            )
        ]
    }

    func activate() {
        windowController.toggle()
    }

    /// 앱 종료 시 FeatureRegistry.teardownAll()이 부른다 — 디바운스 대기 중인 편집을 잃지 않도록.
    func teardown() {
        windowController.flushPendingWrites()
    }
}
