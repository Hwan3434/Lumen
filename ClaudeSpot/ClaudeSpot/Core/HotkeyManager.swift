import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    private var bindings: [UInt32: () -> Void] = [:]
    private var hotkeyRefs: [EventHotKeyRef?] = []
    private var nextID: UInt32 = 1

    func register(keyCode: UInt16, modifiers: UInt32, action: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        bindings[id] = action

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

        let box = HotkeyManagerBox.shared
        box.bindings = bindings

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            Unmanaged.passUnretained(box).toOpaque(),
            nil
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
    }
}

private class HotkeyManagerBox {
    static let shared = HotkeyManagerBox()
    var bindings: [UInt32: () -> Void] = [:]
}
