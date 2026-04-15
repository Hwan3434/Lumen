import AppKit
import SwiftUI

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    var viewModel: SearchViewModel?
    var dismissAction: ((Bool) -> Void)?
    var onKeyEvent: ((Int) -> Bool)?
    var previousApp: NSRunningApplication?
    var autoFocusTextField = true

    var activatePreviousAppOnClose = true

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
            } else if let tv = self.contentView?.findFirstResponderCandidate(ofType: "TerminalView") {
                self.makeFirstResponder(tv)
            }
        }
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            let keyCode = Int(event.keyCode)

            if let handler = onKeyEvent {
                if handler(keyCode) {
                    return
                }
            }

            if let vm = viewModel {
                switch keyCode {
                case KeyCode.downArrow:
                    vm.moveDown()
                    return
                case KeyCode.upArrow:
                    vm.moveUp()
                    return
                case KeyCode.enter:
                    vm.executeSelected(onDismiss: { [weak self] activatePrev in
                        self?.dismissAction?(activatePrev)
                    })
                    return
                case KeyCode.escape:
                    orderOut(nil)
                    return
                default:
                    break
                }
            }
        }
        super.sendEvent(event)
    }
}

final class SearchWindowController {
    private var panel: KeyablePanel?
    private var viewModel: SearchViewModel?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil {
            createPanel()
        }
        guard let panel = panel, let screen = NSScreen.main else { return }

        viewModel?.reset()

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - Constants.searchWindowWidth / 2
        let y = screenFrame.midY - Constants.searchWindowHeight / 2

        panel.previousApp = NSWorkspace.shared.frontmostApplication
        panel.setFrame(
            NSRect(x: x, y: y, width: Constants.searchWindowWidth, height: Constants.searchWindowHeight),
            display: true
        )
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide(activatePreviousApp: Bool = true) {
        panel?.activatePreviousAppOnClose = activatePreviousApp
        panel?.orderOut(nil)
        panel?.activatePreviousAppOnClose = true
    }

    private func createPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Constants.searchWindowWidth, height: Constants.searchWindowHeight),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = .canJoinAllSpaces
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false

        let vm = SearchViewModel()
        self.viewModel = vm
        panel.viewModel = vm
        panel.dismissAction = { [weak self] activatePrev in
            self?.hide(activatePreviousApp: activatePrev)
        }

        let searchView = SearchView(viewModel: vm) { [weak self] in
            self?.hide()
        }

        panel.contentView = NSHostingView(rootView: searchView)
        self.panel = panel
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

    func findFirstResponderCandidate(ofType typeName: String) -> NSView? {
        let viewType = String(describing: type(of: self))
        if viewType.contains(typeName) { return self }
        for subview in subviews {
            if let found = subview.findFirstResponderCandidate(ofType: typeName) { return found }
        }
        return nil
    }
}
