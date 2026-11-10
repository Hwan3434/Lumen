import SwiftUI

private typealias P = LumenTokens.Palette

/// 검색창 오른쪽 상세 칸. 선택한 항목 종류에 따라 내용이 바뀐다.
struct SearchDetailView: View {
    let item: SearchResultItem?
    let viewModel: SearchViewModel

    var body: some View {
        Group {
            switch item {
            case .app(let app):
                AppDetailContent(app: app, detail: viewModel.detail(for: app))
            case .feature(let feature as ToggleableFeature):
                ToggleFeatureDetail(feature: feature)
            case .feature(let feature):
                LaunchFeatureDetail(feature: feature)
            case .calculation(let expr, let result):
                ResultDetail(title: "계산", input: expr, result: result, note: nil)
            case .currency(let input, let result, _):
                ResultDetail(title: "환율", input: input, result: result,
                             note: CurrencyService.shared.lastUpdated.map { "기준 시각 \(LumenTime.relative($0, granularity: .calendar))" })
            case nil:
                LumenEmptyState(icon: "search", text: "검색 결과가 없어요")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(LumenTokens.Space.pad)
    }
}

// MARK: - Parts

/// 가운데 정렬된 큰 아이콘 + 이름.
private struct DetailHero<Icon: View>: View {
    let title: String
    @ViewBuilder let icon: Icon

    var body: some View {
        VStack(spacing: LumenTokens.Space.stack) {
            icon
            Text(title)
                .lumenText(.title3)
                .foregroundStyle(P.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, LumenTokens.Space.s3)
    }
}

/// 기능 아이콘을 담는 큰 타일. 앱 아이콘과 같은 자리·크기.
private struct FeatureIconTile: View {
    let name: String

    var body: some View {
        LumenIcon(name, size: .large)
            .foregroundStyle(P.inkMuted)
            .frame(width: LumenTokens.Space.size(64), height: LumenTokens.Space.size(64))
            .background(P.surfaceRaised, in: LumenShape.rect(LumenTokens.Radius.lg))
            .overlay(LumenShape.rect(LumenTokens.Radius.lg).strokeBorder(P.borderSubtle, lineWidth: 1))
    }
}

/// "⏎ 를 누르면 …" 안내 한 줄.
private struct EnterHint: View {
    let text: String

    var body: some View {
        HStack(spacing: LumenTokens.Space.inline) {
            LumenKbd(label: "⏎")
            Text(text)
                .lumenText(.label, weight: .regular)
                .foregroundStyle(P.inkMuted)
        }
    }
}

// MARK: - App

private struct AppDetailContent: View {
    let app: AppItem
    let detail: AppDetail

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
            DetailHero(title: app.name) {
                Image(nsImage: app.largeIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: LumenTokens.Space.size(64), height: LumenTokens.Space.size(64))
            }
            Grid(alignment: .leading, horizontalSpacing: LumenTokens.Space.s3, verticalSpacing: LumenTokens.Space.s3) {
                row("버전", detail.version ?? "알 수 없음")
                GridRow {
                    label("위치")
                    Text((app.path.path as NSString).abbreviatingWithTildeInPath)
                        .font(LumenFont.mono(LumenTextStyle.caption.size))
                        .foregroundStyle(P.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                row("마지막 실행", detail.lastUsed.map { LumenTime.relative($0, granularity: .calendar) } ?? "기록 없음")
                if !app.aliases.isEmpty {
                    row("다른 이름", app.aliases.joined(separator: ", "))
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            label(title)
            Text(value)
                .lumenText(.label, weight: .regular)
                .foregroundStyle(P.ink)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .lumenText(.label, weight: .regular)
            .foregroundStyle(P.inkFaint)
            .frame(width: LumenTokens.Space.size(96), alignment: .leading)
    }
}

// MARK: - Features

/// 켜고 끄기형: 설명 대신 스위치. 켜져 있으면 언제 꺼지는지 같은 상태를 밑에 적는다.
private struct ToggleFeatureDetail: View {
    let feature: ToggleableFeature

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
            DetailHero(title: feature.name) { FeatureIconTile(name: feature.iconName) }
            VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
                Toggle(isOn: Binding(
                    get: { feature.isOn },
                    set: { if $0 != feature.isOn { feature.activate() } }
                )) {
                    Text(feature.isOn ? "켜짐" : "꺼짐")
                }
                .toggleStyle(LumenSwitchStyle())
                .padding(.vertical, LumenTokens.Space.s3)
                .padding(.horizontal, LumenTokens.Space.s4)
                .lumenCard(radius: LumenTokens.Radius.md)

                Text(feature.onStatus ?? feature.featureDescription)
                    .lumenText(.label, weight: .regular)
                    .foregroundStyle(P.inkMuted)
            }
            if let lidAwake = feature as? LidAwakeFeature {
                LidAwakeHoursRow(lidAwake: lidAwake)
            }
        }
    }
}

/// 클램쉘 모드 상세 칸의 "전원을 뽑은 뒤 끄기" 시간 선택. 설정 > 전원 탭과 같은 값을 바꾼다.
private struct LidAwakeHoursRow: View {
    @Bindable var lidAwake: LidAwakeFeature

    var body: some View {
        LumenSettingRow(title: "전원을 뽑은 뒤 끄기") {
            LumenSegmentedControl(
                items: LidAwakeFeature.batteryHourOptions.map { .init(value: $0, label: "\($0)시간") },
                selection: $lidAwake.batteryHours
            )
        }
        .padding(.vertical, LumenTokens.Space.s3)
        .padding(.horizontal, LumenTokens.Space.s4)
        .lumenCard(radius: LumenTokens.Radius.md)
    }
}

/// 실행형: 창을 여는 기능. 설명과 여는 방법.
private struct LaunchFeatureDetail: View {
    let feature: BuiltInFeature

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
            DetailHero(title: feature.name) { FeatureIconTile(name: feature.iconName) }
            Text(feature.featureDescription)
                .lumenText(.body)
                .foregroundStyle(P.inkMuted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            EnterHint(text: "를 누르면 열려요")
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Calculation · currency

/// 계산·환율 결과를 크게. 결과는 글자를 골라 복사할 수도 있다.
private struct ResultDetail: View {
    let title: String
    let input: String
    let result: String
    let note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: LumenTokens.Space.group) {
            VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
                LumenSectionLabel(text: title)
                Text(input)
                    .font(LumenFont.mono(LumenTextStyle.body.size))
                    .foregroundStyle(P.inkMuted)
                    .lineLimit(2)
                Text(result)
                    .font(LumenFont.mono(LumenTextStyle.title1.size, .semibold))
                    .foregroundStyle(P.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .textSelection(.enabled)
                if let note {
                    Text(note)
                        .lumenText(.caption)
                        .foregroundStyle(P.inkFaint)
                }
            }
            EnterHint(text: "를 누르면 결과를 복사해요")
        }
    }
}
