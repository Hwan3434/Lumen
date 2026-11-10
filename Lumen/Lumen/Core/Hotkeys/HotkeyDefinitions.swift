import AppKit
import Carbon.HIToolbox

/// 패널 키 처리에서 자주 쓰는 키의 짧은 이름. 값은 Carbon `kVK_*` 그대로다.
enum KeyCode {
    static let downArrow = kVK_DownArrow
    static let upArrow = kVK_UpArrow
    static let enter = kVK_Return
    static let escape = kVK_Escape
    static let delete = kVK_Delete        // backspace
    static let forwardDelete = kVK_ForwardDelete
}

extension Constants {
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
}
