import SwiftUI
import AppKit

// MARK: - LumenInputField (single-line, borderless)

struct LumenInputField<Leading: View, Trailing: View>: View {
    @Binding var text: String
    let placeholder: String
    var fontSize: CGFloat = LumenTextStyle.bodyLarge.size
    var monospaced: Bool = false
    var onSubmit: (() -> Void)? = nil

    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            leading()
            TintedTextField(
                text: $text,
                placeholder: placeholder,
                fontSize: fontSize,
                monospaced: monospaced,
                onSubmit: onSubmit
            )
            // SUIT는 한글 글리프가 높아 NSTextField 기본 높이로는 입력 중 윗부분이 잘린다.
            // 글꼴 줄 높이만큼 칸을 확보하고, 셀이 그 안에서 세로 가운데에 그린다.
            .frame(height: ceil(fontSize * 1.6))
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
    var fontSize: CGFloat = LumenTextStyle.body.size
    var monospaced: Bool = false
    /// 변화가 감지될 때마다 NSTextView를 first responder로 만든다. 0은 "no-op".
    /// 호출자는 단조 증가 카운터를 넘기면 된다 — 같은 값으로 머무르면 포커스 변화 없음.
    /// 호출 사례: preview→edit 토글 시 캐럿이 다시 잡혀야 하는데, 패널이 이미 key라
    /// KeyablePanel.becomeKey의 자동 포커스 경로가 다시 호출되지 않는다.
    var focusToken: Int = 0
    /// caretRestoreToken이 바뀌는 시점에 caretRestoreLocation으로 캐럿을 1회 옮긴다.
    /// 0은 "no-op" 시작값. 호출자는 단조 증가 카운터를 넘기면 된다.
    var caretRestoreToken: Int = 0
    var caretRestoreLocation: Int = 0
    /// 사용자가 selection을 바꿀 때마다 호출(location만). 노트별 캐럿 위치 기억용.
    var onCaretChange: ((Int) -> Void)? = nil

    var body: some View {
        TextAreaRepresentable(
            text: $text,
            placeholder: placeholder,
            fontSize: fontSize,
            monospaced: monospaced,
            focusToken: focusToken,
            caretRestoreToken: caretRestoreToken,
            caretRestoreLocation: caretRestoreLocation,
            onCaretChange: onCaretChange
        )
    }
}

private struct TextAreaRepresentable: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let fontSize: CGFloat
    let monospaced: Bool
    let focusToken: Int
    let caretRestoreToken: Int
    let caretRestoreLocation: Int
    let onCaretChange: ((Int) -> Void)?

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
        textView.insertionPointColor = NSColor(LumenTokens.Palette.brand)
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
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? PlaceholderTextView else { return }
        context.coordinator.bind(parent: self)
        if textView.string != text {
            textView.string = text
        }
        applyAttributes(to: textView, coordinator: context.coordinator)
        if caretRestoreToken != 0 && caretRestoreToken != context.coordinator.lastCaretRestoreToken {
            context.coordinator.lastCaretRestoreToken = caretRestoreToken
            // 텍스트 길이를 넘어가면 끝으로 clamp.
            let clamped = min(max(caretRestoreLocation, 0), (textView.string as NSString).length)
            textView.setSelectedRange(NSRange(location: clamped, length: 0))
            textView.scrollRangeToVisible(NSRange(location: clamped, length: 0))
        }
        if focusToken != 0 && focusToken != context.coordinator.lastFocusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async { [weak textView] in
                guard let textView, let window = textView.window else { return }
                window.makeFirstResponder(textView)
            }
        }
    }

    private func applyAttributes(to textView: PlaceholderTextView, coordinator: Coordinator) {
        let key = AttrKey(fontSize: fontSize, monospaced: monospaced, placeholder: placeholder)
        guard coordinator.lastAttrKey != key else { return }
        coordinator.lastAttrKey = key

        let font = LumenFont.nsFont(family: monospaced ? "Geist Mono" : "SUIT Variable", size: fontSize)
        textView.font = font
        textView.textColor = NSColor(LumenTokens.Palette.ink)
        textView.placeholderString = placeholder
        textView.placeholderColor = NSColor(LumenTokens.Palette.inkFaint)
        textView.placeholderFont = font
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextAreaRepresentable?
        var lastAttrKey: AttrKey?
        var lastFocusToken: Int = 0
        var lastCaretRestoreToken: Int = 0

        func bind(parent: TextAreaRepresentable) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent?.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent?.onCaretChange?(textView.selectedRange().location)
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
    var fontSize: CGFloat = LumenTextStyle.body.size
    var monospaced: Bool = false
    var onSubmit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.cell = CenteredTextFieldCell(textCell: "")
        tf.isEditable = true
        tf.isSelectable = true
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

        let font = LumenFont.nsFont(family: monospaced ? "Geist Mono" : "SUIT Variable", size: fontSize)
        tf.font = font
        tf.textColor = NSColor(LumenTokens.Palette.ink)

        let placeholderColor = NSColor(LumenTokens.Palette.inkFaint)
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: placeholderColor,
            .font: font,
        ]
        (tf.cell as? CenteredTextFieldCell)?.centeredPlaceholder =
            NSAttributedString(string: placeholder, attributes: attrs)
        tf.needsDisplay = true
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

/// 칸 높이가 글자보다 클 때 글자와 편집기(field editor)를 세로 가운데에 놓는 셀.
private final class CenteredTextFieldCell: NSTextFieldCell {
    /// 표준 placeholder 속성에 넣으면 편집기가 칸 위쪽에 한 번 더 그리므로 셀이 따로 들고 그린다.
    var centeredPlaceholder: NSAttributedString?

    private func centered(_ rect: NSRect) -> NSRect {
        var r = super.drawingRect(forBounds: rect)
        let textHeight = cellSize(forBounds: rect).height
        if textHeight < r.height {
            r.origin.y += (r.height - textHeight) / 2
            r.size.height = textHeight
        }
        return r
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        centered(rect)
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        centered(rect)
    }

    /// 기본 셀은 안내 문구를 칸 위쪽에 붙여 그리므로, 비어 있을 때는 입력 글자와 같은 자리에 직접 그린다.
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard stringValue.isEmpty, let placeholder = centeredPlaceholder else {
            super.drawInterior(withFrame: cellFrame, in: controlView)
            return
        }
        let r = centered(cellFrame)
        // 편집기 글자와 맞추려고 줄 앞 여백(lineFragmentPadding, 2pt)만큼 민다.
        placeholder.draw(in: r.insetBy(dx: 2, dy: 0))
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText,
                       delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: centered(rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText,
                         delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: centered(rect), in: controlView, editor: textObj, delegate: delegate,
                     start: selStart, length: selLength)
    }
}
