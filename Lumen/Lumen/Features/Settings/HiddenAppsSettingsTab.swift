import SwiftUI

private typealias P = LumenTokens.Palette

/// Settings → "숨긴 앱" 탭. SearchView에서 숨기기 버튼으로 숨긴 앱들을 모아 보여주고,
/// 각 행에서 되돌리기 버튼으로 다시 검색 결과에 노출시킬 수 있다.
/// HiddenAppsStore는 @Observable이라 토글 즉시 리스트가 갱신된다.
struct HiddenAppsSettingsTab: View {
    let action: SettingsActionViewModel

    @State private var store = HiddenAppsStore.shared
    /// 숨긴 앱 중 지금 설치돼 있는 것, 이름순. 지워진 앱은 빠진다(id는 저장소에 남는다).
    @State private var hiddenApps: [AppItem] = []

    var body: some View {
        SettingsTabContent {
            SettingsSection(title: "숨긴 앱") {
                if hiddenApps.isEmpty {
                    LumenEmptyCard(icon: "eye", text: "숨긴 앱이 없어요")
                } else {
                    LumenList(hiddenApps) { app in
                        HiddenAppRow(app: app) {
                            store.unhide(app.id)
                        }
                    }
                }
                LumenHint("검색창에서 앱 위에 마우스를 올리면 오른쪽에 숨기기 버튼이 나타나요. 숨긴 앱은 여기서 되돌리기 전까지 검색 결과에 보이지 않아요.")
            }
        }
        .onAppear {
            // 토글이 곧 저장이라 ActionBar 숨김.
            action.hideActionBar()
        }
        // 숨긴 앱 몇 개만 찾으면 되므로 앱 폴더 전체를 훑지 않는다. 검색창에서 숨기거나 여기서 되돌리면 다시 만든다.
        .onChange(of: store.hiddenIDs, initial: true) { _, ids in
            hiddenApps = ids
                .compactMap { AppIndexer.item(forID: $0) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}

private struct HiddenAppRow: View {
    let app: AppItem
    let onUnhide: () -> Void

    var body: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: LumenIcon.Size.large.points, height: LumenIcon.Size.large.points)
            Text(app.name)
                .lumenText(.body, weight: .medium)
                .foregroundStyle(P.ink)
                .lineLimit(1)
            Spacer(minLength: LumenTokens.Space.inline)
            Button(action: onUnhide) {
                Label { Text("되돌리기") } icon: { LumenIcon("undo-2", size: .small) }
            }
            .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))
        }
        .padding(.vertical, LumenTokens.Space.s3)
        .padding(.horizontal, LumenTokens.Space.s4)
    }
}
