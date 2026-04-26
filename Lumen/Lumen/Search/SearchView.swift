import SwiftUI

struct SearchView: View {
    @State var viewModel = SearchViewModel()
    var onDismiss: () -> Void

    @FocusState private var queryFieldFocused: Bool

    var body: some View {
        ZStack {
            LumenGlassBackground(radius: LumenTokens.Radius.window)
            HStack(spacing: 0) {
                mainPanel
                if ClaudeUsageService.isAvailable {
                    sidePanelDivider
                    UsagePanelView()
                        .frame(width: Constants.usagePanelWidth)
                        .background(LumenTokens.BG.sidePanel)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: LumenTokens.Radius.window, style: .continuous))
    }

    private var sidePanelDivider: some View {
        Rectangle()
            .fill(LumenTokens.divider)
            .frame(width: 0.5)
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            searchInput
            quickRow
            LumenHairline()
                .padding(.horizontal, 18)
            resultsList
            footer
        }
    }

    // MARK: - Search input

    private var searchInput: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LumenTokens.Accent.violetSoft.opacity(0.85))

            ZStack(alignment: .leading) {
                if viewModel.query.isEmpty {
                    Text("앱 검색, 명령 실행, 계산…")
                        .font(.system(size: 18))
                        .foregroundStyle(LumenTokens.TextColor.placeholder)
                }
                TextField("", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .tint(LumenTokens.Accent.violetSoft)
                    .focused($queryFieldFocused)
            }

            LumenKbd(label: "⌘K")
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .overlay(alignment: .bottom) { LumenHairline().padding(.horizontal, 0) }
        .onAppear { queryFieldFocused = true }
    }

    // MARK: - Quick row (built-in features)

    @ViewBuilder
    private var quickRow: some View {
        if !viewModel.features.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                LumenSectionLabel(text: "빠른 실행")
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.features, id: \.name) { feature in
                            quickCard(feature: feature)
                        }
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 36)
                    .padding(.bottom, 4)
                }
                .mask(
                    // Soft right-edge fade — last 24px scrollable region
                    // dissolves to transparent so cards read as horizontally
                    // scrollable without leaking past the column.
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.92),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .padding(.bottom, 12)
            }
        } else {
            Spacer().frame(height: 8)
        }
    }

    private func quickCard(feature: BuiltInFeature) -> some View {
        Button {
            onDismiss()
            feature.activate()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: feature.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(LumenTokens.Accent.violetSoft)
                Text(feature.name)
                    .font(.system(size: 11))
                    .foregroundStyle(LumenTokens.TextColor.secondary)
                    .lineLimit(1)
            }
            .frame(width: 76, height: 64)
            .background(
                RoundedRectangle(cornerRadius: LumenTokens.Radius.card)
                    .fill(LumenTokens.BG.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LumenTokens.Radius.card)
                    .stroke(LumenTokens.stroke, lineWidth: 0.5)
            )
            // Inner top highlight to give the card a subtle bevel.
            .overlay(
                RoundedRectangle(cornerRadius: LumenTokens.Radius.card)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    .blendMode(.plusLighter)
                    .padding(0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            LumenSectionLabel(text: resultsHeaderLabel)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                            switch item {
                            case .app, .calculation:
                                resultRow(item: item, index: index)
                            case .feature:
                                EmptyView()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: viewModel.selectedIndex) { _, newValue in
                    withAnimation(.easeOut(duration: 0.4)) {
                        if let item = viewModel.results[safe: newValue] {
                            proxy.scrollTo(item.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var resultsHeaderLabel: String {
        if let first = viewModel.results.first, case .calculation = first { return "계산" }
        return "결과"
    }

    @ViewBuilder
    private func resultRow(item: SearchResultItem, index: Int) -> some View {
        let isSelected = index == viewModel.selectedIndex
        Button {
            viewModel.selectedIndex = index
        } label: {
            ZStack(alignment: .leading) {
                rowBackground(isSelected: isSelected)
                if isSelected {
                    // Amber left stripe — only on selected row.
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(LumenTokens.Accent.amber)
                        .frame(width: 2)
                        .padding(.vertical, 6)
                        .padding(.leading, 4)
                        .shadow(color: LumenTokens.Accent.amberDim, radius: 4, x: 0, y: 0)
                }
                rowContent(item: item, isSelected: isSelected)
                    .padding(.leading, 12)
                    .padding(.trailing, 10)
            }
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableRowStyle(isSelected: isSelected))
        .id(item.id)
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: LumenTokens.Radius.row)
            .fill(isSelected ? LumenTokens.BG.rowActive : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: LumenTokens.Radius.row)
                    .stroke(isSelected ? LumenTokens.Accent.amber.opacity(0.18) : .clear, lineWidth: 0.5)
            )
    }

    @ViewBuilder
    private func rowContent(item: SearchResultItem, isSelected: Bool) -> some View {
        switch item {
        case .app(let appItem):
            HStack(spacing: 10) {
                Image(nsImage: appItem.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: LumenTokens.Radius.appTile))
                Text(appItem.name)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? LumenTokens.TextColor.primary : LumenTokens.TextColor.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                LumenBadge(kind: .app)
            }

        case .calculation(let expr, let result):
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: LumenTokens.Radius.appTile)
                        .fill(LumenTokens.Accent.amber.opacity(0.15))
                    Image(systemName: "equal")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(LumenTokens.Accent.amber)
                }
                .frame(width: 24, height: 24)

                HStack(spacing: 8) {
                    Text(expr)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                    Text(result)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(LumenTokens.TextColor.primary)
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                    Text("복사")
                        .font(.system(size: 11))
                }
                .foregroundStyle(LumenTokens.Accent.amber)
            }

        case .feature:
            EmptyView()
        }
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
                footerAction(label: footerActionLabel, kbd: "⏎", primary: true)
                footerAction(label: "명령", kbd: "⌘K")
                footerAction(label: "실행", kbd: "⌥⏎")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(LumenTokens.BG.footer)
        .overlay(alignment: .top) {
            Rectangle().fill(LumenTokens.divider).frame(height: 0.5)
        }
    }

    private var footerActionLabel: String {
        if let item = viewModel.results[safe: viewModel.selectedIndex] {
            switch item {
            case .calculation: return "결과 복사"
            case .app:         return "열기"
            case .feature:     return "실행"
            }
        }
        return "열기"
    }

    private func footerAction(label: String, kbd: String, primary: Bool = false) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: primary ? .medium : .regular))
                .foregroundStyle(primary ? LumenTokens.TextColor.primary : LumenTokens.TextColor.muted)
            LumenKbd(label: kbd, primary: primary)
        }
    }
}

// MARK: - Badge

private struct LumenBadge: View {
    enum Kind { case app, calc, action, web, snippet }
    let kind: Kind

    var body: some View {
        Text(label)
            .font(.system(size: 9.5, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4).fill(bg)
            )
    }

    private var label: String {
        switch kind {
        case .app:     return "APP"
        case .calc:    return "CALC"
        case .action:  return "ACTION"
        case .web:     return "WEB"
        case .snippet: return "SNIPPET"
        }
    }
    private var bg: Color {
        switch kind {
        case .app, .web: return LumenTokens.Accent.violet.opacity(0.10)
        case .calc:      return LumenTokens.Accent.amber.opacity(0.10)
        case .action, .snippet: return Color.white.opacity(0.05)
        }
    }
    private var fg: Color {
        switch kind {
        case .app, .web: return LumenTokens.Accent.violetSoft
        case .calc:      return LumenTokens.Accent.amber
        case .action, .snippet: return LumenTokens.TextColor.secondary
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
