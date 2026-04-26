import SwiftUI

struct ClipboardView: View {
    @State var viewModel = ClipboardViewModel()
    @FocusState private var queryFocused: Bool

    private let listColumnWidth: CGFloat = 320
    private let totalCapacity = 500

    var body: some View {
        ZStack {
            LumenGlassBackground(radius: LumenTokens.Radius.window)
            VStack(spacing: 0) {
                titleStrip
                LumenHairline()
                HStack(spacing: 0) {
                    listColumn
                        .frame(width: listColumnWidth)
                    Rectangle().fill(LumenTokens.divider).frame(width: 0.5)
                    previewColumn
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: LumenTokens.Radius.window, style: .continuous))
    }

    // MARK: - Title strip

    private var titleStrip: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LumenTokens.Accent.violetSoft)
                Text("클립보드")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                Rectangle()
                    .fill(LumenTokens.divider)
                    .frame(width: 1, height: 12)
                Text(countLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                if viewModel.query.isEmpty == false {
                    Text("(검색)")
                        .font(.system(size: 10.5))
                        .tracking(0.4)
                        .foregroundStyle(LumenTokens.TextColor.muted)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Text("패널")
                    .font(.system(size: 11))
                    .foregroundStyle(LumenTokens.TextColor.muted)
                LumenKbd(label: "⌘⇧V")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
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
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(viewModel.query.isEmpty ? LumenTokens.TextColor.muted : LumenTokens.Accent.violetSoft)

            ZStack(alignment: .leading) {
                if viewModel.query.isEmpty {
                    Text("클립보드 검색…")
                        .font(.system(size: 12.5))
                        .foregroundStyle(LumenTokens.TextColor.placeholder)
                }
                TextField("", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .tint(LumenTokens.Accent.violetSoft)
                    .focused($queryFocused)
            }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(LumenTokens.TextColor.muted.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .onAppear { queryFocused = true }
    }

    private var listEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(LumenTokens.TextColor.muted.opacity(0.5))
            Text(viewModel.query.isEmpty ? "아직 항목이 없습니다" : "일치하는 항목이 없습니다")
                .font(.system(size: 12))
                .foregroundStyle(LumenTokens.TextColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var listContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardListRow(
                            item: item,
                            isSelected: index == viewModel.selectedIndex
                        )
                        .id(item.id)
                        .onTapGesture { viewModel.selectedIndex = index }
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.selectedIndex) { _, newValue in
                if let item = viewModel.filteredItems[safe: newValue] {
                    withAnimation(.easeOut(duration: 0.3)) {
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
        VStack(spacing: 14) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(LumenTokens.Accent.violetSoft.opacity(0.35))
            Text("미리보기")
                .font(.system(size: 12))
                .foregroundStyle(LumenTokens.TextColor.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                LinearGradient(
                    colors: [LumenTokens.Accent.violetSoft, LumenTokens.Accent.amber],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Lumen")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
            Spacer()
            HStack(spacing: 14) {
                ClipFooterAction(label: "복사", kbd: "⏎", primary: true)
                ClipFooterAction(label: "닫기", kbd: "esc")
                ClipFooterAction(label: "패널", kbd: "⌘⇧V")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(LumenTokens.BG.footer)
        .overlay(alignment: .top) {
            Rectangle().fill(LumenTokens.divider).frame(height: 0.5)
        }
    }
}

// MARK: - List row

private struct ClipboardListRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: LumenTokens.Radius.row)
                .fill(isSelected ? LumenTokens.BG.rowActive : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: LumenTokens.Radius.row)
                        .stroke(isSelected ? LumenTokens.Accent.amber.opacity(0.18) : .clear, lineWidth: 0.5)
                )

            if isSelected {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(LumenTokens.Accent.amber)
                    .frame(width: 2)
                    .padding(.vertical, 6)
                    .padding(.leading, 4)
                    .shadow(color: LumenTokens.Accent.amberDim, radius: 4)
            }

            HStack(spacing: 10) {
                Image(systemName: typeIcon)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(isSelected ? LumenTokens.TextColor.secondary : LumenTokens.TextColor.muted)
                    .frame(width: 14)

                Text(item.displayText)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? LumenTokens.TextColor.primary : LumenTokens.TextColor.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 6)

                if let count = fileCount, count > 1 {
                    Text("+\(count - 1)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(LumenTokens.stroke, lineWidth: 0.5)
                        )
                }

                Text(item.typeLabel)
                    .font(.system(size: 10.5))
                    .tracking(0.2)
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }

    private var typeIcon: String {
        switch item.typeLabel {
        case "이미지": return "photo"
        case "파일":   return "doc"
        default:       return "text.alignleft"
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

    var body: some View {
        VStack(spacing: 0) {
            previewHeader
            LumenHairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    bodyContent
                    metaBlock
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var previewHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            sourceAppTile
            VStack(alignment: .leading, spacing: 3) {
                Text(primaryLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(secondaryLine)
                    .font(.system(size: 11))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var sourceAppTile: some View {
        if let icon = item.sourceAppIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LumenTokens.BG.card)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "questionmark.app")
                        .font(.system(size: 14))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                )
        }
    }

    private var primaryLine: String {
        item.displayText.split(separator: "\n").first.map(String.init) ?? item.displayText
    }

    private var secondaryLine: String {
        let app = item.sourceApp ?? "Unknown"
        return "\(app) · \(timeOnly(item.date))"
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let image = item.resolvedImage ?? loadedFileImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
        }

        if let urls = item.fileURLs, !urls.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(urls, id: \.self) { url in
                    HStack(spacing: 8) {
                        Image(systemName: "doc")
                            .font(.system(size: 12))
                            .foregroundStyle(LumenTokens.TextColor.muted)
                        Text(url.lastPathComponent)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(LumenTokens.TextColor.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LumenTokens.BG.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LumenTokens.stroke, lineWidth: 0.5)
                    )
            )
        }

        if let text = item.text, !text.isEmpty {
            let displayed = text.count > 500 ? String(text.prefix(500)) + "…" : text
            Text(displayed)
                .font(.system(size: 13))
                .foregroundStyle(LumenTokens.TextColor.primary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var loadedFileImage: NSImage? {
        guard let urls = item.fileURLs, let url = urls.first else { return nil }
        let exts = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"]
        guard exts.contains(url.pathExtension.lowercased()) else { return nil }
        return NSImage(contentsOf: url)
    }

    // MARK: - Meta block

    @ViewBuilder
    private var metaBlock: some View {
        let rows = buildMetaRows()
        if !rows.isEmpty {
            VStack(spacing: 0) {
                Rectangle().fill(LumenTokens.divider).frame(height: 0.5)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), alignment: .topLeading),
                        GridItem(.flexible(), alignment: .topLeading),
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 3) {
                            LumenSectionLabel(text: row.key)
                            Text(row.value)
                                .font(.system(size: 12, design: row.mono ? .monospaced : .default))
                                .foregroundStyle(LumenTokens.TextColor.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding(.top, 14)
            }
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
                let total = urls.compactMap {
                    (try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? Int64)?.flatMap { $0 }
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

    private func timeOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func fullTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            f.dateFormat = "오늘 HH:mm"
        } else if cal.isDateInYesterday(date) {
            f.dateFormat = "어제 HH:mm"
        } else {
            f.dateFormat = "M월 d일 HH:mm"
        }
        return f.string(from: date)
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

// MARK: - Footer action

private struct ClipFooterAction: View {
    let label: String
    let kbd: String
    var primary: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: primary ? .medium : .regular))
                .foregroundStyle(primary ? LumenTokens.TextColor.primary : LumenTokens.TextColor.muted)
            LumenKbd(label: kbd, primary: primary)
        }
    }
}
