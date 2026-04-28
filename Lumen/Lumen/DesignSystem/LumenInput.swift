import SwiftUI
import AppKit

// MARK: - LumenInputField (single-line, borderless)

struct LumenInputField<Leading: View, Trailing: View>: View {
    @Binding var text: String
    let placeholder: String
    var fontSize: CGFloat = 18
    var monospaced: Bool = false
    var onSubmit: (() -> Void)? = nil

    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            leading()
            TintedTextField(
                text: $text,
                placeholder: placeholder,
                fontSize: fontSize,
                monospaced: monospaced,
                onSubmit: onSubmit
            )
            trailing()
        }
    }
}

// MARK: - LumenTextArea (multi-line)
//
// AppKit NSTextView를 SwiftUI로 감싸 caret과 placeholder가 같은 좌표계에서
// 자동 정렬되도록 한다 — 픽셀 보정 없음.

struct LumenTextArea: View {
    @Binding var text: String
    let placeholder: String
    var fontSize: CGFloat = 17
    var monospaced: Bool = false
    /// 뷰가 등장하는 즉시 NSTextView를 first responder로 만들지 여부.
    /// 패널이 이미 key인 상태에서 모드 전환 등으로 새로 mount되는 경우, KeyablePanel.becomeKey
    /// 의 자동 포커스 경로가 다시 호출되지 않으므로 호출자가 명시적으로 켜야 한다.
    var autoFocus: Bool = false

    var body: some View {
        TextAreaRepresentable(
            text: $text,
            placeholder: placeholder,
            fontSize: fontSize,
            monospaced: monospaced,
            autoFocus: autoFocus
        )
    }
}

private struct TextAreaRepresentable: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let fontSize: CGFloat
    let monospaced: Bool
    let autoFocus: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true

        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.usesInspectorBar = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.insertionPointColor = NSColor(LumenTokens.Accent.violetSoft)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude
        )

        context.coordinator.bind(parent: self)
        applyAttributes(to: textView, coordinator: context.coordinator)
        scroll.documentView = textView
        if autoFocus {
            DispatchQueue.main.async { [weak textView] in
                guard let textView, let window = textView.window else { return }
                window.makeFirstResponder(textView)
            }
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? PlaceholderTextView else { return }
        context.coordinator.bind(parent: self)
        if textView.string != text {
            textView.string = text
        }
        applyAttributes(to: textView, coordinator: context.coordinator)
    }

    private func applyAttributes(to textView: PlaceholderTextView, coordinator: Coordinator) {
        let key = AttrKey(fontSize: fontSize, monospaced: monospaced, placeholder: placeholder)
        guard coordinator.lastAttrKey != key else { return }
        coordinator.lastAttrKey = key

        let font = monospaced
            ? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            : NSFont.systemFont(ofSize: fontSize)
        textView.font = font
        textView.textColor = NSColor(LumenTokens.TextColor.primary)
        textView.placeholderString = placeholder
        textView.placeholderColor = NSColor(LumenTokens.TextColor.placeholder)
        textView.placeholderFont = font
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextAreaRepresentable?
        var lastAttrKey: AttrKey?

        func bind(parent: TextAreaRepresentable) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent?.text = textView.string
        }
    }

    struct AttrKey: Equatable {
        let fontSize: CGFloat
        let monospaced: Bool
        let placeholder: String
    }
}

/// NSTextView가 빈 상태일 때 placeholder를 자기 좌표계에서 직접 그린다.
/// caret(insertion point)이 그려지는 자리 = textContainerOrigin + lineFragmentPadding.
/// 첫 글자도 같은 자리에서 시작하므로 placeholder를 거기 그리면 caret과 자동 정렬.
private final class PlaceholderTextView: NSTextView {
    var placeholderString: String = ""
    var placeholderColor: NSColor = .placeholderTextColor
    var placeholderFont: NSFont = .systemFont(ofSize: 13)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderString.isEmpty else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: placeholderColor,
            .font: placeholderFont,
        ]
        let attributed = NSAttributedString(string: placeholderString, attributes: attrs)
        let pad = textContainer?.lineFragmentPadding ?? 0
        let origin = textContainerOrigin
        attributed.draw(at: NSPoint(x: origin.x + pad, y: origin.y))
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }
}

// MARK: - TintedTextField (NSViewRepresentable for placeholder color)

private struct TintedTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var fontSize: CGFloat = 13
    var monospaced: Bool = false
    var onSubmit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.delegate = context.coordinator
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.bezelStyle = .squareBezel
        tf.lineBreakMode = .byTruncatingTail
        tf.cell?.usesSingleLineMode = true
        tf.cell?.wraps = false
        tf.cell?.isScrollable = true
        context.coordinator.bind(parent: self)
        applyAttributes(to: tf, coordinator: context.coordinator)
        // KeyablePanel.becomeKey 가 findFirstEditableField()로 이 NSTextField를 찾아
        // makeFirstResponder 한다. 패널 생명주기에 맡기는 게 옳다.
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.bind(parent: self)
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        applyAttributes(to: nsView, coordinator: context.coordinator)
    }

    private func applyAttributes(to tf: NSTextField, coordinator: Coordinator) {
        let key = AttrKey(fontSize: fontSize, monospaced: monospaced, placeholder: placeholder)
        guard coordinator.lastAttrKey != key else { return }
        coordinator.lastAttrKey = key

        let font = monospaced
            ? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            : NSFont.systemFont(ofSize: fontSize)
        tf.font = font
        tf.textColor = NSColor(LumenTokens.TextColor.primary)

        let placeholderColor = NSColor(LumenTokens.TextColor.placeholder)
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: placeholderColor,
            .font: font,
        ]
        tf.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: attrs)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TintedTextField?
        var lastAttrKey: AttrKey?

        func bind(parent: TintedTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ note: Notification) {
            guard let tf = note.object as? NSTextField else { return }
            parent?.text = tf.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)),
               let onSubmit = parent?.onSubmit {
                onSubmit()
                return true
            }
            return false
        }
    }

    struct AttrKey: Equatable {
        let fontSize: CGFloat
        let monospaced: Bool
        let placeholder: String
    }
}
