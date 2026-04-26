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
// TextEditor 기반. placeholder는 ZStack overlay로 그리되, TextEditor 내부의
// NSTextView가 가지는 기본 textContainerInset (약 8pt top, 5pt leading)을
// 동일하게 placeholder에 강제한다. 이러면 사용자가 입력하는 순간 caret이
// placeholder가 보였던 자리에 정확히 등장한다.
// .allowsHitTesting(false)로 placeholder가 클릭/포커스를 가로막지 못하게 한다.

struct LumenTextArea: View {
    @Binding var text: String
    let placeholder: String
    var fontSize: CGFloat = 17
    var monospaced: Bool = false
    var autoFocus: Bool = true

    @FocusState private var focused: Bool

    /// macOS TextEditor 내부 NSTextView 기본 textContainerInset 보정값.
    /// padding 0인 TextEditor의 첫 글자가 그려지는 좌상단 위치를 placeholder가 따라가도록.
    private static let textViewInset = EdgeInsets(top: 8, leading: 5, bottom: 0, trailing: 5)

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundStyle(LumenTokens.TextColor.placeholder)
                    .padding(Self.textViewInset)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(font)
                .foregroundStyle(LumenTokens.TextColor.primary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .tint(LumenTokens.Accent.violetSoft)
                .focused($focused)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { if autoFocus { focused = true } }
    }

    private var font: Font {
        .system(size: fontSize, design: monospaced ? .monospaced : .default)
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
