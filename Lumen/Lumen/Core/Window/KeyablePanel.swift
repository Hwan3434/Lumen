import AppKit

/// Borderless floating panel that can become key and gets first responder routed
/// to the first editable field on becomeKey. Each subclass-bound controller wires
/// its own `onKeyEvent` for hotkeys; the panel itself is feature-agnostic.
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// 키 이벤트 가로채기 — true 반환 시 super.sendEvent를 건너뛴다.
    var onKeyEvent: ((Int) -> Bool)?

    /// hide 후에 이전 앱으로 포커스 복귀시킬지 여부. PanelWindowController가
    /// space 전환을 감지해 false로 내릴 수 있다.
    var activatePreviousAppOnClose = true
    var previousApp: NSRunningApplication?

    /// becomeKey 시 첫 editable text field에 자동으로 makeFirstResponder 할지 여부.
    var autoFocusTextField = true

    override func orderOut(_ sender: Any?) {
        let wasVisible = isVisible
        super.orderOut(sender)
        if wasVisible && activatePreviousAppOnClose, let app = previousApp {
            app.activate()
        }
    }

    override func becomeKey() {
        super.becomeKey()
        guard autoFocusTextField else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isKeyWindow else { return }
            if let tf = self.contentView?.findFirstEditableField() {
                self.makeFirstResponder(tf)
            }
        }
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if let handler = onKeyEvent, handler(Int(event.keyCode)) {
                return
            }
        }
        super.sendEvent(event)
    }
}

extension NSView {
    func findFirstEditableField() -> NSView? {
        for subview in subviews {
            if let tf = subview as? NSTextField, tf.isEditable { return tf }
            if let tv = subview as? NSTextView, tv.isEditable { return tv }
            if let found = subview.findFirstEditableField() { return found }
        }
        return nil
    }
}
