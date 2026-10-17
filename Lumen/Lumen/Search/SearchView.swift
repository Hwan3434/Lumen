import SwiftUI

struct SearchView: View {
    @State var viewModel = SearchViewModel()
    var onDismiss: () -> Void

    /// X 버튼 클릭 시 즉시 숨기지 않고 확인 alert를 띄우기 위한 pending state.
    /// (app id, 표시용 이름)을 동시에 들고 있어 alert 메시지에 이름을 넣을 수 있다.
    @State private var pendingHide: (id: String, name: String)?

    var body: some View {
        ZStack {
            LumenPanelBackground()
            mainPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(LumenShape.rect(LumenTokens.Radius.xl))
        .alert(
            "‘\(pendingHide?.name ?? "")’을(를) 숨길까요?",
            isPresented: Binding(
                get: { pendingHide != nil },
                set: { if !$0 { pendingHide = nil } }
            ),
            presenting: pendingHide
        ) { item in
            Button("숨기기", role: .destructive) {
                viewModel.hideApp(item.id)
                pendingHide = nil
            }
            Button("취소", role: .cancel) {
                pendingHide = nil
            }
        } message: { _ in
            Text("검색 결과에 더 이상 보이지 않아요. 설정의 [숨긴 앱]에서 언제든 되돌릴 수 있어요.")
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            searchInput
            // Quick row가 빈 상태일 땐 search input의 자체 구분선 하나만
            // 보이고 results 위에 또 그어지지 않도록 — quick row가 있는 경우에만
            // 그 아래 구분선을 둔다.
            if !viewModel.features.isEmpty {
                quickRow
                LumenHairline()
            }
            resultsList
            footer
        }
    }

    // MARK: - Search input

    private var searchInput: some View {
        LumenInputField(
            text: $viewModel.query,
            placeholder: "앱 검색, 명령 실행, 계산, 환율",
            fontSize: LumenTextStyle.bodyLarge.size,
            leading: {
                LumenIcon("search", size: .large)
                    .foregroundStyle(LumenTokens.Palette.inkMuted)
            },
            trailing: { LumenKbd(label: "⌘K") }
        )
        .padding(.horizontal, LumenTokens.Space.pad)
        .frame(height: LumenTokens.Space.size(64))
        .overlay(alignment: .bottom) { LumenHairline() }
    }

    // MARK: - Quick row (built-in features)

    private var quickRow: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
            LumenSectionLabel(text: "빠른 실행")
                .padding(.horizontal, LumenTokens.Space.pad)
                .padding(.top, LumenTokens.Space.s4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumenTokens.Space.inline) {
                    ForEach(viewModel.features, id: \.name) { feature in
                        quickCard(feature: feature)
                    }
                }
                .padding(.horizontal, LumenTokens.Space.pad)
            }
            .padding(.bottom, LumenTokens.Space.s4)
        }
    }

    private func quickCard(feature: BuiltInFeature) -> some View {
        Button {
            onDismiss()
            feature.activate()
        } label: {
            VStack(spacing: LumenTokens.Space.inline) {
                LumenIcon(feature.iconName, size: .large)
                    .foregroundStyle(LumenTokens.Palette.inkMuted)
                Text(feature.name)
                    .lumenText(.caption)
                    .foregroundStyle(LumenTokens.Palette.ink)
                    .lineLimit(1)
            }
            .frame(width: LumenTokens.Space.size(96), height: LumenTokens.Space.size(80))
            .overlay(LumenShape.rect(LumenTokens.Radius.md).strokeBorder(LumenTokens.Palette.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(LumenListRowStyle())
    }

    // MARK: - Results

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            LumenSectionLabel(text: resultsHeaderLabel)
                .padding(.horizontal, LumenTokens.Space.pad)
                .padding(.top, LumenTokens.Space.s4)
                .padding(.bottom, LumenTokens.Space.inline)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                            resultRow(item: item, index: index)
                        }
                    }
                    .padding(.horizontal, LumenTokens.Space.inline)
                    .padding(.bottom, LumenTokens.Space.inline)
                }
                .scrollIndicators(.hidden)
                .onChange(of: viewModel.selectedIndex) { _, newValue in
                    withAnimation(LumenTokens.Motion.easeMove()) {
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
            rowContent(item: item, isSelected: isSelected)
                .padding(.vertical, LumenTokens.Space.scaled(14))
                .padding(.horizontal, LumenTokens.Space.s4)
                .contentShape(Rectangle())
        }
        .buttonStyle(LumenListRowStyle(isSelected: isSelected))
        .id(item.id)
    }

    @ViewBuilder
    private func rowContent(item: SearchResultItem, isSelected: Bool) -> some View {
        switch item {
        case .app(let appItem):
            AppRowContent(appItem: appItem, isSelected: isSelected) {
                pendingHide = (id: appItem.id, name: appItem.name)
            }

        case .calculation(let expr, let result):
            ConversionRow(icon: "equal", input: expr, result: result, isSelected: isSelected)

        case .currency(let input, let result, _):
            ConversionRow(icon: "circle-dollar-sign", input: input, result: result, isSelected: isSelected)
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
            }
        }
        return "열기"
    }
}

// MARK: - Rows

/// 계산·환율 결과 행: 입력 → 결과, 오른쪽에 복사 안내.
private struct ConversionRow: View {
    let icon: String
    let input: String
    let result: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            LumenIcon(icon)
                .foregroundStyle(LumenTokens.Palette.inkMuted)
            HStack(spacing: LumenTokens.Space.inline) {
                Text(input)
                    .font(LumenFont.mono(LumenTextStyle.label.size))
                    .foregroundStyle(LumenTokens.Palette.inkMuted)
                LumenIcon("arrow-right", size: .small)
                    .foregroundStyle(LumenTokens.Palette.inkFaint)
                Text(result)
                    .font(LumenFont.mono(LumenTextStyle.body.size, .medium))
                    .foregroundStyle(isSelected ? LumenTokens.Palette.brand : LumenTokens.Palette.ink)
            }
            .lineLimit(1)
            Spacer(minLength: LumenTokens.Space.inline)
            HStack(spacing: LumenTokens.Space.s1) {
                LumenIcon("copy", size: .small)
                Text("복사").lumenText(.label, weight: .regular)
            }
            .foregroundStyle(LumenTokens.Palette.inkFaint)
        }
    }
}

/// 앱 결과 행. 호버 시 우측 끝에 숨기기 버튼이 페이드인 — 클릭하면 onHide 콜백.
/// 버튼 영역에서는 행 자체의 selection이 트리거되지 않도록 stop-propagation.
private struct AppRowContent: View {
    let appItem: AppItem
    let isSelected: Bool
    let onHide: () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            Image(nsImage: appItem.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: LumenIcon.Size.large.points, height: LumenIcon.Size.large.points)
            Text(appItem.name)
                .lumenText(.body, weight: isSelected ? .semibold : .medium)
                .foregroundStyle(isSelected ? LumenTokens.Palette.brand : LumenTokens.Palette.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: LumenTokens.Space.inline)
            if hovered {
                LumenIconButton(icon: "eye-off", label: "검색 결과에서 숨기기", action: onHide)
                    .padding(.vertical, -LumenIconButton.inlineOverhang)
                    .transition(.opacity)
            } else {
                LumenBadge(text: "앱")
            }
        }
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .animation(LumenTokens.Motion.easeOut(LumenTokens.Motion.fast), value: hovered)
    }
}
