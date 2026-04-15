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
}
