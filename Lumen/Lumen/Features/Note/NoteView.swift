import SwiftUI
import MarkdownUI

struct NoteView: View {
    @State var viewModel = NoteViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.yellow)
                Text("메모")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Button(action: { viewModel.togglePreview() }) {
                    Text(viewModel.isPreview ? "편집" : "미리보기")
                        .foregroundColor(.gray)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                Text("⌘⇧E")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().background(Color.gray.opacity(0.3))

            if viewModel.isPreview {
                ScrollView(.vertical) {
                    Markdown(viewModel.text)
                        .markdownTheme(.dark)
                        .textSelection(.enabled)
                        .environment(\.openURL, OpenURLAction { url in
                            NSWorkspace.shared.open(url)
                            return .handled
                        })
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            } else {
                TextEditor(text: $viewModel.text)
                    .font(.system(size: 14, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .foregroundColor(.white)
                    .padding(8)
                    .onChange(of: viewModel.text) { _, _ in
                        viewModel.onTextChanged()
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
