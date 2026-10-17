import SwiftUI

private typealias P = LumenTokens.Palette

struct ClipboardView: View {
    @State var viewModel = ClipboardViewModel()
    @State private var showDeleteAllConfirm = false

    private var listColumnWidth: CGFloat { LumenTokens.Space.size(360) }
    private let totalCapacity = 500

    var body: some View {
        ZStack {
            LumenPanelBackground()
            VStack(spacing: 0) {
                titleStrip
                LumenHairline()
                HStack(spacing: 0) {
                    listColumn
                        .frame(width: listColumnWidth)
                    Rectangle().fill(P.borderSubtle).frame(width: 1)
                    previewColumn
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(LumenShape.rect(LumenTokens.Radius.xl))
        .confirmationDialog(
            "클립보드 기록을 모두 지울까요?",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("모두 삭제", role: .destructive) { viewModel.deleteAll() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("지운 기록은 되돌릴 수 없어요.")
        }
    }

    // MARK: - Title strip

    private var titleStrip: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            HStack(spacing: LumenTokens.Space.inline) {
                LumenIcon("clipboard-list")
                    .foregroundStyle(P.inkMuted)
                Text("클립보드")
                    .lumenText(.body, weight: .semibold)
                    .foregroundStyle(P.ink)
            }
            Text(countLabel)
                .lumenText(.caption)
                .monospacedDigit()
                .foregroundStyle(P.inkFaint)
            if viewModel.query.isEmpty == false {
                Text("검색 중")
                    .lumenText(.caption)
                    .foregroundStyle(P.inkFaint)
            }
            Spacer()
            LumenIconButton(icon: "trash-2", label: "모두 삭제") {
                showDeleteAllConfirm = true
            }
            .disabled(ClipboardManager.shared.history.isEmpty)
            LumenKbd(label: "⌘⇧V")
        }
        .padding(.leading, LumenTokens.Space.pad)
        .padding(.trailing, LumenTokens.Space.s4)
        .draggableWindowHeader()
        .frame(height: LumenTokens.Space.size(56))
    }

    private var countLabel: String {
        let total = ClipboardManager.shared.history.count
        if viewModel.query.isEmpty {
            return "\(total) / \(totalCapacity)"
        } else {
            return "\(viewModel.filteredItems.count) / \(total)"
        }
    }

    // MARK: - List column

    private var listColumn: some View {
        VStack(spacing: 0) {
            searchField
            LumenHairline()
            if viewModel.filteredItems.isEmpty {
                listEmptyState
            } else {
                listContent
            }
        }
    }

    private var searchField: some View {
        LumenInputField(
            text: $viewModel.query,
            placeholder: "클립보드 검색",
            fontSize: LumenTextStyle.body.size,
            leading: {
                LumenIcon("search")
                    .foregroundStyle(P.inkMuted)
            },
            trailing: {
                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                    } label: {
                        LumenIcon("circle-x", size: .small)
                            .foregroundStyle(P.inkFaint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("검색어 지우기")
                }
            }
        )
        .padding(.horizontal, LumenTokens.Space.s4)
        .frame(height: LumenTokens.Space.size(52))
    }

    private var listEmptyState: some View {
        LumenEmptyState(icon: "search",
                        text: viewModel.query.isEmpty ? "아직 복사한 항목이 없어요" : "찾는 항목이 없어요")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(LumenTokens.Space.pad)
    }

    private var listContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                        Button {
                            viewModel.selectedIndex = index
                        } label: {
                            ClipboardListRow(
                                item: item,
                                isSelected: index == viewModel.selectedIndex,
                                onDelete: { viewModel.delete(item: item) }
                            )
                        }
                        .buttonStyle(LumenListRowStyle(isSelected: index == viewModel.selectedIndex))
                        .id(item.id)
                    }
                }
                .padding(LumenTokens.Space.inline)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.selectedIndex) { _, newValue in
                if let item = viewModel.filteredItems[safe: newValue] {
                    withAnimation(LumenTokens.Motion.easeMove()) {
                        proxy.scrollTo(item.id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Preview column

    @ViewBuilder
    private var previewColumn: some View {
        if let item = viewModel.filteredItems[safe: viewModel.selectedIndex] {
            ClipboardPreview(item: item, viewModel: viewModel)
        } else {
            previewEmpty
        }
    }

    private var previewEmpty: some View {
        LumenEmptyState(icon: "clipboard-list", text: "항목을 고르면 여기에 미리 보여요")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        LumenFooterBar(actions: [
            .init(label: "복사", kbd: "⏎", primary: true),
            .init(label: "삭제", kbd: "⌫"),
            .init(label: "닫기", kbd: "esc"),
        ])
    }
}

// MARK: - List row

private struct ClipboardListRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            LumenIcon(typeIcon)
                .foregroundStyle(P.inkMuted)

            Text(item.displayText)
                .lumenText(.body, weight: isSelected ? .semibold : .medium)
                .foregroundStyle(isSelected ? P.brand : P.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: LumenTokens.Space.inline)

            if let count = fileCount, count > 1 {
                LumenBadge(text: "+\(count - 1)")
            }

            if isHovering {
                LumenIconButton(icon: "x", label: "삭제", action: onDelete)
                    .padding(.vertical, -LumenIconButton.inlineOverhang)
            } else {
                Text(item.typeLabel)
                    .lumenText(.label, weight: .regular)
                    .foregroundStyle(P.inkFaint)
            }
        }
        .padding(.vertical, LumenTokens.Space.scaled(14))
        .padding(.horizontal, LumenTokens.Space.s4)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private var typeIcon: String {
        switch item.typeLabel {
        case "이미지": return "image"
        case "파일":   return "file"
        default:       return "align-left"
        }
    }

    private var fileCount: Int? {
        item.fileURLs?.count
    }
}

// MARK: - Preview

private struct ClipboardPreview: View {
    let item: ClipboardItem
    let viewModel: ClipboardViewModel

    /// 파일 URL이 이미지일 때 디스크에서 1회 로드한 결과를 캐시 — body 재호출마다
    /// NSImage(contentsOf:)를 다시 디코드하지 않게 한다. item이 바뀌면 무효화.
    @State private var cachedFileImage: NSImage?
    @State private var cachedFileImageItemID: UUID?

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
        .onAppear { refreshCachedFileImage() }
        .onChange(of: item.id) { _, _ in refreshCachedFileImage() }
    }

    private func refreshCachedFileImage() {
        guard cachedFileImageItemID != item.id else { return }
        cachedFileImageItemID = item.id
        cachedFileImage = loadFileImage()
    }

    private func loadFileImage() -> NSImage? {
        guard let urls = item.fileURLs, let url = urls.first else { return nil }
        let exts = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"]
        guard exts.contains(url.pathExtension.lowercased()) else { return nil }
        return NSImage(contentsOf: url)
    }

    private var previewHeader: some View {
        HStack(alignment: .center, spacing: LumenTokens.Space.s3) {
            sourceAppTile
            VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
                Text(primaryLine)
                    .lumenText(.body, weight: .semibold)
                    .foregroundStyle(P.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(secondaryLine)
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
        if let icon = item.sourceAppIcon {
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

    private var primaryLine: String {
        item.displayText.split(separator: "\n").first.map(String.init) ?? item.displayText
    }

    private var secondaryLine: String {
        let app = item.sourceApp ?? "알 수 없는 앱"
        return "\(app) · \(timeOnly(item.date))"
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let image = item.resolvedImage ?? cachedFileImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: LumenTokens.Space.size(240))
                .clipShape(LumenShape.rect(LumenTokens.Radius.lg))
                .overlay(LumenShape.rect(LumenTokens.Radius.lg).strokeBorder(P.borderSubtle, lineWidth: 1))
        }

        if let urls = item.fileURLs, !urls.isEmpty {
            LumenList(data: urls, id: \.self) { url in
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

        if let text = item.text, !text.isEmpty {
            let displayed = text.count > 500 ? String(text.prefix(500)) + "…" : text
            Text(displayed)
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
        let rows = buildMetaRows()
        if !rows.isEmpty {
            VStack(spacing: 0) {
                LumenHairline()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LumenTokens.Space.group) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
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

    private struct MetaRow {
        let key: String
        let value: String
        let mono: Bool
    }

    private func buildMetaRows() -> [MetaRow] {
        var rows: [MetaRow] = []
        if let app = item.sourceApp {
            rows.append(.init(key: "복사한 앱", value: app, mono: false))
        }
        rows.append(.init(key: "복사 시간", value: fullTime(item.date), mono: true))

        if let text = item.text {
            let count = text.count
            if count > 500 {
                rows.append(.init(key: "글자 수", value: "\(count.formatted())자 (500자만 표시)", mono: true))
            } else {
                rows.append(.init(key: "글자 수", value: "\(count.formatted())자", mono: true))
            }
            rows.append(.init(key: "종류", value: "텍스트", mono: false))
        }

        if let urls = item.fileURLs, !urls.isEmpty {
            if urls.count == 1, let url = urls.first {
                rows.append(.init(key: "경로", value: shortPath(url), mono: true))
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                    if let size = attrs[.size] as? Int64 {
                        rows.append(.init(key: "크기",
                                          value: ByteCountFormatter.string(fromByteCount: size, countStyle: .file),
                                          mono: true))
                    }
                    if let date = attrs[.modificationDate] as? Date {
                        rows.append(.init(key: "수정 시각", value: fullTime(date), mono: true))
                    }
                }
            } else {
                rows.append(.init(key: "항목 수", value: "\(urls.count)개", mono: false))
                let total = urls.compactMap { url -> Int64? in
                    try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
                }.reduce(Int64(0), +)
                if total > 0 {
                    rows.append(.init(key: "총 크기",
                                      value: ByteCountFormatter.string(fromByteCount: total, countStyle: .file),
                                      mono: true))
                }
            }
        }

        if let img = item.resolvedImage {
            rows.append(.init(key: "이미지 크기",
                              value: "\(Int(img.size.width)) × \(Int(img.size.height))",
                              mono: true))
        }

        return rows
    }

    private static let hourMinuteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private func timeOnly(_ date: Date) -> String {
        Self.hourMinuteFormatter.string(from: date)
    }

    private func fullTime(_ date: Date) -> String {
        LumenTime.relative(date, granularity: .calendar)
    }

    private func shortPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let p = url.path
        if p.hasPrefix(home) {
            return "~" + p.dropFirst(home.count)
        }
        return p
    }
}

