import SwiftUI

/// Settings → "숨긴 앱" 탭. SearchView에서 X 버튼으로 숨긴 앱들을 모아 보여주고,
/// 각 행에서 되돌리기 버튼으로 다시 검색 결과에 노출시킬 수 있다.
/// HiddenAppsManager는 @Observable이라 토글 즉시 리스트가 갱신된다.
struct HiddenAppsSettingsTab: View {
    let action: SettingsActionViewModel

    @State private var manager = HiddenAppsManager.shared
    @State private var allApps: [AppItem] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(title: "숨긴 앱") {
                    if hiddenApps.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 4) {
                            ForEach(hiddenApps) { app in
                                HiddenAppRow(app: app) {
                                    manager.unhide(app.id)
                                }
                            }
                        }
                    }
                    Text("검색창에서 앱 위에 마우스를 올리면 우측에 작은 숨기기 버튼이 나타납니다. 숨긴 앱은 검색 결과에서 제외되며, 이 화면에서 되돌리기 전까지 유지됩니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                        .lineSpacing(3)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            // 토글이 곧 저장이라 ActionBar 숨김.
            action.hidden = true
            action.dirty = false
            action.saved = false
            // AppIndexer는 SearchViewModel이 들고 있어서 별도로 한 번 인덱싱.
            // 자주 열리는 화면이 아니라 매번 다시 도는 비용이 부담스럽지 않다.
            if allApps.isEmpty {
                allApps = AppIndexer().loadApps()
            }
        }
    }

    /// HiddenAppsManager에 저장된 ID 중 현재 시스템에 설치돼 있는 앱만 표시.
    /// 삭제된 앱이라면 매니저에 ID는 남아있지만 UI에선 자동으로 사라진다.
    /// 정렬은 이름순.
    private var hiddenApps: [AppItem] {
        let ids = manager.hiddenIDs
        return allApps
            .filter { ids.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LumenTokens.TextColor.muted)
            Text("숨긴 앱이 없습니다.")
                .font(.system(size: 12.5))
                .foregroundStyle(LumenTokens.TextColor.muted)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.018))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
        )
    }
}

private struct HiddenAppRow: View {
    let app: AppItem
    let onUnhide: () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text(app.name)
                .font(.system(size: 12.5))
                .foregroundStyle(LumenTokens.TextColor.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button(action: onUnhide) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text("되돌리기")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(LumenTokens.Accent.violetSoft)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(
                    Capsule()
                        .fill(LumenTokens.Accent.violet.opacity(0.12))
                        .overlay(
                            Capsule().stroke(LumenTokens.Accent.violetSoft.opacity(0.30), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovered ? Color.white.opacity(0.035) : Color.white.opacity(0.015))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
        )
        .onHover { hovered = $0 }
    }
}
