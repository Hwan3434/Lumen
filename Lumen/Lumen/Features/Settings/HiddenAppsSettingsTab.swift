import SwiftUI

private typealias P = LumenTokens.Palette

/// Settings → "숨긴 앱" 탭. SearchView에서 숨기기 버튼으로 숨긴 앱들을 모아 보여주고,
/// 각 행에서 되돌리기 버튼으로 다시 검색 결과에 노출시킬 수 있다.
/// HiddenAppsManager는 @Observable이라 토글 즉시 리스트가 갱신된다.
struct HiddenAppsSettingsTab: View {
    let action: SettingsActionViewModel

    @State private var manager = HiddenAppsManager.shared
    @State private var allApps: [AppItem] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenTokens.Space.s7) {
                SettingsSection(title: "숨긴 앱") {
                    if hiddenApps.isEmpty {
                        emptyState
                    } else {
                        LumenList(hiddenApps) { app in
                            HiddenAppRow(app: app) {
                                manager.unhide(app.id)
                            }
                        }
                    }
                    Text("검색창에서 앱 위에 마우스를 올리면 오른쪽에 숨기기 버튼이 나타나요. 숨긴 앱은 여기서 되돌리기 전까지 검색 결과에 보이지 않아요.")
                        .lumenText(.caption)
                        .foregroundStyle(P.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(LumenTokens.Space.s6)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            // 토글이 곧 저장이라 ActionBar 숨김.
            action.hidden = true
            action.dirty = false
            action.saved = false
            // 인덱싱은 디스크 스캔이라 메인 스레드 블록을 피해 백그라운드로.
            if allApps.isEmpty {
                Task.detached(priority: .userInitiated) {
                    let apps = AppIndexer().loadApps()
                    await MainActor.run { self.allApps = apps }
                }
            }
        }
    }

    /// HiddenAppsManager에 저장된 ID 중 현재 시스템에 설치돼 있는 앱만 표시.
    /// 삭제된 앱이라면 매니저에 ID는 남아있지만 UI에선 자동으로 사라진다.
    /// 정렬은 이름순.
    private var hiddenApps: [AppItem] {
        allApps
            .filter { manager.isHidden($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var emptyState: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            LumenIcon("eye")
                .foregroundStyle(P.inkMuted)
            Text("숨긴 앱이 없어요")
                .lumenText(.body)
                .foregroundStyle(P.inkMuted)
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, LumenTokens.Space.s4)
        .lumenCard()
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
                .frame(width: 24, height: 24)
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
