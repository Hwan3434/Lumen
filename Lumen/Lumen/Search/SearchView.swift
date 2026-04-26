import SwiftUI

struct SearchView: View {
    @State var viewModel = SearchViewModel()
    var onDismiss: () -> Void

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
            // Quick row가 빈 상태일 땐 search input의 자체 hairline 하나만
            // 보이고 results 위에 또 그어지지 않도록 — quick row가 있는 경우에만
            // 그 아래 구분선을 둔다.
            if !viewModel.features.isEmpty {
                quickRow
                LumenHairline()
                    .padding(.horizontal, 18)
            }
            resultsList
            footer
        }
    }

    // MARK: - Search input

    private var searchInput: some View {
        LumenInputField(
            text: $viewModel.query,
            placeholder: "앱 검색, 명령 실행, 계산, 환율…",
            fontSize: 18,
            leading: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LumenTokens.Accent.violetSoft.opacity(0.85))
            },
            trailing: { LumenKbd(label: "⌘K") }
        )
        .padding(.horizontal, 18)
        .frame(height: 56)
        .overlay(alignment: .bottom) { LumenHairline() }
    }

    // MARK: - Quick row (built-in features)

    private var quickRow: some View {
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
                // 우측 끝 24px 페이드 — quick row가 가로 스크롤 가능하다는 시그널.
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
                            case .app, .calculation, .currency:
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
        if let first = viewModel.results.first {
            switch first {
            case .calculation: return "계산"
            case .currency:    return "환율"
            default:           break
            }
        }
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
            AppRowContent(appItem: appItem, isSelected: isSelected) {
                viewModel.hideApp(appItem.id)
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

        case .currency(let input, let result, _):
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: LumenTokens.Radius.appTile)
                        .fill(LumenTokens.Accent.violet.opacity(0.15))
                    Image(systemName: "dollarsign.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LumenTokens.Accent.violetSoft)
                }
                .frame(width: 24, height: 24)

                HStack(spacing: 8) {
                    Text(input)
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
                .foregroundStyle(LumenTokens.Accent.violetSoft)
            }

        case .feature:
            EmptyView()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        LumenFooterBar(actions: [
            .init(label: footerActionLabel, kbd: "⏎", primary: true),
            .init(label: "명령", kbd: "⌘K"),
            .init(label: "실행", kbd: "⌥⏎"),
        ])
    }

    private var footerActionLabel: String {
        if let item = viewModel.results[safe: viewModel.selectedIndex] {
            switch item {
            case .calculation, .currency: return "결과 복사"
            case .app:                    return "열기"
            case .feature:                return "실행"
            }
        }
        return "열기"
    }
}

// MARK: - Badge

/// 검색 결과 행 우측의 "APP" 배지. 현재 Search는 앱 항목만 배지를 다는데,
/// 다른 종류(snippet/web 등) 결과 타입이 늘어나면 multi-tone Badge 컴포넌트로
/// 확장하면 된다.
private struct AppBadge: View {
    var body: some View {
        Text("APP")
            .font(.system(size: 9.5, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(LumenTokens.Accent.violetSoft)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(LumenTokens.Accent.violet.opacity(0.10))
            )
    }
}

/// 앱 결과 행. 호버 시 우측 끝에 작은 X 버튼이 페이드인 — 클릭하면 onHide 콜백.
/// X 버튼 영역에서는 행 자체의 selection이 트리거되지 않도록 stop-propagation.
private struct AppRowContent: View {
    let appItem: AppItem
    let isSelected: Bool
    let onHide: () -> Void

    @State private var hovered = false

    var body: some View {
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
            if hovered {
                HideButton(action: onHide)
                    .transition(.opacity)
            } else {
                AppBadge()
            }
        }
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }
}

private struct HideButton: View {
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "eye.slash")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.muted)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(pressed ? LumenTokens.Accent.amber.opacity(0.16) : Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(LumenTokens.stroke, lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .help("검색 결과에서 숨기기")
        .onHover { pressed = $0 }
    }
}

