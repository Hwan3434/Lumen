import SwiftUI

private typealias P = LumenTokens.Palette

/// 클립보드 오른쪽 미리보기 칸. `ClipboardPreviewModel`을 그리기만 한다.
struct ClipboardPreview: View {
    let preview: ClipboardPreviewModel

    var body: some View {
        VStack(spacing: 0) {
            previewHeader
            LumenHairline()
            ScrollView {
                VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
                    bodyContent
                }
                .padding(LumenTokens.Space.pad)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
            metaFooter
        }
    }

    private var previewHeader: some View {
        HStack(alignment: .center, spacing: LumenTokens.Space.s3) {
            sourceAppTile
            VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
                Text(preview.title)
                    .lumenText(.body, weight: .semibold)
                    .foregroundStyle(P.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(preview.subtitle)
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LumenTokens.Space.pad)
        .padding(.vertical, LumenTokens.Space.s4)
    }

    @ViewBuilder
    private var sourceAppTile: some View {
        if let icon = preview.sourceAppIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: LumenTokens.Space.size(32), height: LumenTokens.Space.size(32))
        } else {
            LumenShape.rect(LumenTokens.Radius.sm)
                .fill(P.surface)
                .frame(width: LumenTokens.Space.size(32), height: LumenTokens.Space.size(32))
                .overlay(
                    LumenIcon("app-window")
                        .foregroundStyle(P.inkMuted)
                )
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let image = preview.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: LumenTokens.Space.size(240))
                .clipShape(LumenShape.rect(LumenTokens.Radius.lg))
                .overlay(LumenShape.rect(LumenTokens.Radius.lg).strokeBorder(P.borderSubtle, lineWidth: 1))
        }

        if !preview.fileURLs.isEmpty {
            LumenList(data: preview.fileURLs, id: \.self) { url in
                HStack(spacing: LumenTokens.Space.s3) {
                    LumenIcon("file")
                        .foregroundStyle(P.inkMuted)
                    Text(url.lastPathComponent)
                        .font(LumenFont.mono(LumenTextStyle.label.size))
                        .foregroundStyle(P.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, LumenTokens.Space.s3)
                .padding(.horizontal, LumenTokens.Space.s4)
            }
        }

        if let text = preview.text {
            Text(text)
                .lumenText(.body)
                .foregroundStyle(P.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Meta footer (하단 가로 stripe)

    /// 우측 패널 하단에 고정되는 메타데이터 띠. 본문 영역을 줄이지 않도록 ScrollView 밖에 둔다.
    /// 항목들은 한 줄로, 너무 길어지면 가로 스크롤로 처리.
    @ViewBuilder
    private var metaFooter: some View {
        if !preview.metaRows.isEmpty {
            VStack(spacing: 0) {
                LumenHairline()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LumenTokens.Space.group) {
                        ForEach(Array(preview.metaRows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: LumenTokens.Space.inline) {
                                Text(row.key)
                                    .lumenText(.caption)
                                    .foregroundStyle(P.inkFaint)
                                Text(row.value)
                                    .font(row.mono ? LumenFont.mono(LumenTextStyle.caption.size)
                                                   : LumenFont.style(.caption, weight: .medium))
                                    .foregroundStyle(P.inkMuted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .padding(.horizontal, LumenTokens.Space.pad)
                    .padding(.vertical, LumenTokens.Space.s3)
                }
            }
            .background(P.panelSurface)
        }
    }
}
