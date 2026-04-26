import SwiftUI
import AppKit

// MARK: - LumenInputField (single-line, borderless)
//
// Search / Clipboard 등 패널 헤더 자리에 들어가는 borderless 검색·입력 필드.
// SwiftUI TextField의 placeholder는 시스템 색을 따르고 커스텀이 어렵기 때문에,
// AppKit NSTextField를 NSViewRepresentable로 감싸 placeholderAttributedString을
// 직접 LumenTokens 색으로 칠한다. 이렇게 하면 placeholder와 입력 텍스트의
// 베이스라인이 동일 NSTextField 내부에서 결정되므로 정렬 어긋남이 원천 차단된다.
//
// leading/trailing slot은 SwiftUI ViewBuilder로 받아 아이콘·키 힌트 등을 자유롭게
// 끼워 넣을 수 있다.
//
// `tint`는 SwiftUI .tint()로 커서/선택색을 지정 — NSTextField가 이 값을
// insertionPointColor로 자동 사용한다.

struct LumenInputField<Leading: View, Trailing: View>: View {
    @Binding var text: String
    let placeholder: String
    var fontSize: CGFloat = 18
    var monospaced: Bool = false
    var autoFocus: Bool = true
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
                autoFocus: autoFocus,
                onSubmit: onSubmit
            )
            trailing()
        }
    }
}

extension LumenInputField where Leading == EmptyView, Trailing == EmptyView {
    init(text: Binding<String>, placeholder: String, fontSize: CGFloat = 18, monospaced: Bool = false, autoFocus: Bool = true, onSubmit: (() -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.fontSize = fontSize
        self.monospaced = monospaced
        self.autoFocus = autoFocus
        self.onSubmit = onSubmit
        self.leading = { EmptyView() }
        self.trailing = { EmptyView() }
    }
}

extension LumenInputField where Leading == EmptyView {
    init(text: Binding<String>, placeholder: String, fontSize: CGFloat = 18, monospaced: Bool = false, autoFocus: Bool = true, onSubmit: (() -> Void)? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self._text = text
        self.placeholder = placeholder
        self.fontSize = fontSize
        self.monospaced = monospaced
        self.autoFocus = autoFocus
        self.onSubmit = onSubmit
        self.leading = { EmptyView() }
        self.trailing = trailing
    }
}

extension LumenInputField where Trailing == EmptyView {
    init(text: Binding<String>, placeholder: String, fontSize: CGFloat = 18, monospaced: Bool = false, autoFocus: Bool = true, onSubmit: (() -> Void)? = nil, @ViewBuilder leading: @escaping () -> Leading) {
        self._text = text
        self.placeholder = placeholder
        self.fontSize = fontSize
        self.monospaced = monospaced
        self.autoFocus = autoFocus
        self.onSubmit = onSubmit
        self.leading = leading
        self.trailing = { EmptyView() }
    }
}

// MARK: - LumenTextArea (multi-line — Translator input, Note editor)
//
// AppKit NSTextView를 SwiftUI로 감싼 멀티라인 에디터. placeholder는
// NSTextView 자체가 그리므로 caret과 placeholder의 정렬을 *AppKit이
// 자기 좌표계 안에서* 보장한다 — 우리는 픽셀을 보정하지 않는다.
// Safari 주소창·macOS 검색창이 단일라인에서 보여주는 자연스러운 동작을
// 멀티라인으로 옮긴 형태.

struct LumenTextArea: View {
    @Binding var text: String
    let placeholder: String
    var fontSize: CGFloat = 17
    var monospaced: Bool = false

    var body: some View {
        TextAreaRepresentable(
            text: $text,
            placeholder: placeholder,
            fontSize: fontSize,
            monospaced: monospaced
        )
    }
}

private struct TextAreaRepresentable: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let fontSize: CGFloat
    let monospaced: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

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

        applyAttributes(to: textView)
        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? PlaceholderTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        applyAttributes(to: textView)
    }

    private func applyAttributes(to textView: PlaceholderTextView) {
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
        let parent: TextAreaRepresentable
        init(_ parent: TextAreaRepresentable) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// NSTextView 서브클래스로 placeholder를 *NSTextView 자기 좌표계*에서 직접 그린다.
/// 첫 글자가 들어갈 자리는 `textContainerOrigin`이 가리키므로 그 origin을 그대로
/// 쓰면 caret과 baseline이 자동으로 일치한다 — 픽셀 보정 불필요.
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

        // 첫 글자가 그려질 origin = textContainerOrigin + lineFragment의 첫 줄 origin.
        // 빈 텍스트일 때는 textContainerOrigin 자체가 첫 줄의 시작점이므로 거기 그린다.
        let origin = textContainerOrigin
        attributed.draw(at: origin)
    }

    override func didChangeText() {
        super.didChangeText()
        // 비어있다 → 채워지거나, 채워졌다 → 비어지는 전이 시 placeholder 영역이
        // 다시 그려지도록 강제. NSTextView 기본 동작은 텍스트 영역만 invalidate함.
        needsDisplay = true
    }
}

// MARK: - TintedTextField (NSViewRepresentable, placeholder color customization)

private struct TintedTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var fontSize: CGFloat = 13
    var monospaced: Bool = false
    var autoFocus: Bool = false
    var onSubmit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

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
        applyAttributes(to: tf)
        // KeyablePanel.becomeKey 가 findFirstEditableField()로 이 NSTextField를 찾아
        // makeFirstResponder 한다. 패널 생명주기에 맡기는 게 옳다.
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        applyAttributes(to: nsView)
    }

    private func applyAttributes(to tf: NSTextField) {
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
        let parent: TintedTextField
        init(_ parent: TintedTextField) { self.parent = parent }

        func controlTextDidChange(_ note: Notification) {
            guard let tf = note.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)),
               let onSubmit = parent.onSubmit {
                onSubmit()
                return true
            }
            return false
        }
    }
}
