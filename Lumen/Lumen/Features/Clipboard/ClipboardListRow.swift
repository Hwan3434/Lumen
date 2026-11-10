import SwiftUI

private typealias P = LumenTokens.Palette

/// 클립보드 목록의 한 줄. 마우스를 올리면 종류 문구 자리에 삭제 버튼이 나온다.
struct ClipboardListRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            LumenIcon(item.kind.icon)
                .foregroundStyle(P.inkMuted)

            Text(item.displayText)
                .lumenRowTitle(selected: isSelected)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: LumenTokens.Space.inline)

            if let count = fileCount, count > 1 {
                LumenBadge(text: "+\(count - 1)")
            }

            if isHovering {
                LumenIconButton(icon: "x", label: "삭제", action: onDelete)
                    .inRow()
            } else {
                Text(item.kind.label)
                    .lumenText(.label, weight: .regular)
                    .foregroundStyle(P.inkFaint)
            }
        }
        .padding(.vertical, LumenTokens.Space.rowY)
        .padding(.horizontal, LumenTokens.Space.s4)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private var fileCount: Int? {
        item.fileURLs?.count
    }
}
