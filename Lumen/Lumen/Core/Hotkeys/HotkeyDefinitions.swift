import AppKit
import Carbon.HIToolbox

/// 키보드 키 식별자. Carbon kVK_*에 매핑되지 않은 일부 SwiftUI 호환 코드.
enum KeyCode {
    static let downArrow = 125
    static let upArrow = 126
    static let enter = 36
    static let escape = 53
    static let comma = 43
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
