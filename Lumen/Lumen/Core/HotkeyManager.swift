import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    private var bindings: [UInt32: () -> Void] = [:]
    private var hotkeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1

    /// 등록에 실패한 핫키들 — 다른 앱이 이미 선점한 경우(⌘Space는 Spotlight 기본값이다).
    /// 설정 화면에서 사용자에게 알려줄 수 있도록 남겨둔다.
    private(set) var failedRegistrations: [String] = []

    func register(keyCode: UInt16, modifiers: UInt32, action: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        bindings[id] = action
        // start() 이후에 등록되는 핫키도 동작하도록 box에 바로 반영한다.
        // (start()가 bindings를 스냅샷으로 복사하므로 여기서 채우지 않으면 조용히 무시된다.)
        HotkeyManagerBox.shared.bindings[id] = action

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C5350) // "CLSP"
        hotKeyID.id = id

        var carbonModifiers: UInt32 = 0
        if modifiers & UInt32(NSEvent.ModifierFlags.command.rawValue) != 0 { carbonModifiers |= UInt32(cmdKey) }
        if modifiers & UInt32(NSEvent.ModifierFlags.shift.rawValue) != 0 { carbonModifiers |= UInt32(shiftKey) }
        if modifiers & UInt32(NSEvent.ModifierFlags.option.rawValue) != 0 { carbonModifiers |= UInt32(optionKey) }
        if modifiers & UInt32(NSEvent.ModifierFlags.control.rawValue) != 0 { carbonModifiers |= UInt32(controlKey) }

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            hotkeyRefs.append(hotKeyRef)
        } else {
            // 실패해도 예외가 없어 그동안 완전히 조용했다 — 사용자는 "핫키가 안 먹는다"만 겪는다.
            // 가장 흔한 원인은 다른 앱과의 충돌(⌘Space = Spotlight).
            let label = Self.describe(keyCode: keyCode, modifiers: modifiers)
            failedRegistrations.append(label)
            bindings.removeValue(forKey: id)
            HotkeyManagerBox.shared.bindings.removeValue(forKey: id)
            NSLog("[Lumen] 핫키 등록 실패: %@ (OSStatus=%d) — 다른 앱이 이미 쓰고 있는지 확인하세요.",
                  label, status)
        }
    }

    /// "⌘⇧X" 형태의 사람이 읽는 라벨. 로그와 설정 화면 안내에 쓴다.
    private static func describe(keyCode: UInt16, modifiers: UInt32) -> String {
        var label = ""
        if modifiers & UInt32(NSEvent.ModifierFlags.control.rawValue) != 0 { label += "⌃" }
        if modifiers & UInt32(NSEvent.ModifierFlags.option.rawValue)  != 0 { label += "⌥" }
        if modifiers & UInt32(NSEvent.ModifierFlags.shift.rawValue)   != 0 { label += "⇧" }
        if modifiers & UInt32(NSEvent.ModifierFlags.command.rawValue) != 0 { label += "⌘" }
        return label + keyName(keyCode)
    }

    private static func keyName(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Space:          return "Space"
        case kVK_LeftArrow:      return "←"
        case kVK_RightArrow:     return "→"
        case kVK_UpArrow:        return "↑"
        case kVK_DownArrow:      return "↓"
        default:
            // 문자 키는 현재 키보드 레이아웃과 무관하게 US 기준 이름으로 충분하다.
            let letters: [Int: String] = [
                kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
                kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
                kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
                kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
                kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
                kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
                kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            ]
            return letters[Int(keyCode)] ?? "key\(keyCode)"
        }
    }

    func start() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManagerBox>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if let action = manager.bindings[hotKeyID.id] {
                DispatchQueue.main.async {
                    action()
                }
            }

            return noErr
        }

        // bindings는 register()에서 이미 box에 반영돼 있다 — 여기선 핸들러만 건다.
        let box = HotkeyManagerBox.shared

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            Unmanaged.passUnretained(box).toOpaque(),
            &eventHandlerRef
        )
    }

    func stop() {
        for ref in hotkeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotkeyRefs.removeAll()
        bindings.removeAll()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        HotkeyManagerBox.shared.bindings.removeAll()
    }
}

private class HotkeyManagerBox {
    static let shared = HotkeyManagerBox()
    var bindings: [UInt32: () -> Void] = [:]
}
