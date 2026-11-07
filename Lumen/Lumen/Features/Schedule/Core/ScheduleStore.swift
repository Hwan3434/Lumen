import SwiftUI
import Observation

/// 플러그인 상태를 모아 들고, 보이는 항목과 묶음 색을 한 곳에서 계산한다.
/// 월간·주간·메뉴바가 전부 `visibleItems`만 본다.
@Observable
@MainActor
final class ScheduleStore {
    static let shared = ScheduleStore(plugins: SchedulePlugins.all)

    struct PluginState {
        var items: [ScheduleItem] = []
        var lastUpdated: Date? = nil
        var errorMessage: String? = nil
        var isLoading = false
    }

    struct Failure: Identifiable {
        let plugin: any SchedulePlugin
        let message: String
        var id: String { plugin.id.rawValue }
    }

    let plugins: [any SchedulePlugin]
    private(set) var states: [SchedulePluginID: PluginState] = [:]
    @ObservationIgnored private var running: [SchedulePluginID: Task<Void, Never>] = [:]

    init(plugins: [any SchedulePlugin]) {
        self.plugins = plugins
        for plugin in plugins {
            var state = PluginState()
            // 앱을 켜면 마지막 데이터로 먼저 그리고, TTL이 지났으면 뒤에서 갱신한다.
            if plugin.cacheTTL != nil, let cached = ScheduleCache.load(plugin.id) {
                state.items = cached.items
                state.lastUpdated = cached.savedAt
            }
            states[plugin.id] = state
            plugin.startObserving { [weak self] in
                Task { await self?.refresh(plugin.id, force: true) }
            }
        }
    }

    // MARK: - 조회

    func plugin(_ id: SchedulePluginID) -> (any SchedulePlugin)? {
        plugins.first { $0.id == id }
    }

    var enabledPlugins: [any SchedulePlugin] { plugins.filter(\.isEnabled) }

    /// 오늘 앞뒤 90일.
    nonisolated static func window(around date: Date = Date()) -> DateInterval {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        let start = cal.date(byAdding: .day, value: -90, to: today) ?? today
        let end = cal.date(byAdding: .day, value: 91, to: today) ?? today
        return DateInterval(start: start, end: end)
    }

    /// 켜진 플러그인의 항목 중 보이는 묶음에 든 것만.
    var visibleItems: [ScheduleItem] {
        var result: [ScheduleItem] = []
        for plugin in enabledPlugins {
            guard let items = states[plugin.id]?.items, !items.isEmpty else { continue }
            let visible = Set(plugin.groups.filter(\.isVisible).map(\.id))
            result.append(contentsOf: items.filter { visible.contains($0.group) })
        }
        return result
    }

    /// 그날에 걸친 항목. 기간 항목(스프린트)은 목록·메뉴바에 넣지 않는다.
    func items(on day: Date) -> [ScheduleItem] {
        visibleItems.filter { $0.kind != .span && $0.covers(day) }
    }

    var lastUpdated: Date? {
        enabledPlugins.compactMap { states[$0.id]?.lastUpdated }.max()
    }

    var isRefreshing: Bool {
        enabledPlugins.contains { states[$0.id]?.isLoading == true }
    }

    var failures: [Failure] {
        enabledPlugins.compactMap { plugin in
            (states[plugin.id]?.errorMessage).map { Failure(plugin: plugin, message: $0) }
        }
    }

    // MARK: - 색

    /// 묶음 색. 켜진 플러그인을 등록 순서대로 돌며 보이는 묶음에 `chart1`부터 붙인다.
    /// 플러그인이 색을 정해 준 묶음(캘린더 앱 색)은 그 색을 쓰고 자리를 차지하지 않는다. 숨긴 묶음은 `chartOther`.
    var groupColors: [ScheduleGroupKey: Color] {
        var colors: [ScheduleGroupKey: Color] = [:]
        var slot = 0
        for plugin in enabledPlugins {
            for group in plugin.groups {
                let key = ScheduleGroupKey(plugin: plugin.id, group: group.id)
                if let custom = group.customColor {
                    colors[key] = custom
                } else if group.isVisible {
                    colors[key] = LumenTokens.Palette.chartCategories[safe: slot] ?? LumenTokens.Palette.chartOther
                    slot += 1
                } else {
                    colors[key] = LumenTokens.Palette.chartOther
                }
            }
        }
        return colors
    }

    func color(for item: ScheduleItem) -> Color {
        groupColors[item.groupKey] ?? LumenTokens.Palette.chartOther
    }

    // MARK: - 갱신

    /// TTL이 지난 플러그인만 다시 받는다. 패널·메뉴바 팝오버를 열 때 부른다.
    func refreshStale() async {
        await refreshAll(force: false)
    }

    /// 메뉴바 라벨에 올리는 플러그인만 받는다. 앱을 켤 때 부른다 — 패널을 열기 전에는 그 밖의 플러그인(Jira)을 두드리지 않는다.
    func refreshMenuBarPlugins() async {
        for plugin in plugins where plugin.contributesToMenuBarLabel {
            await refresh(plugin.id, force: false)
        }
    }

    func refreshAll(force: Bool) async {
        await withTaskGroup(of: Void.self) { group in
            for plugin in plugins {
                group.addTask { await self.refresh(plugin.id, force: force) }
            }
        }
    }

    func refresh(_ id: SchedulePluginID, force: Bool) async {
        guard let plugin = plugin(id) else { return }
        guard plugin.isEnabled else {
            states[id] = PluginState()
            if plugin.cacheTTL != nil { ScheduleCache.remove(id) }
            return
        }
        // 같은 플러그인을 겹쳐 받지 않는다 — 먼저 시작한 조회를 기다린다.
        if let task = running[id] {
            await task.value
            return
        }
        if !force, let ttl = plugin.cacheTTL, let at = states[id]?.lastUpdated,
           Date().timeIntervalSince(at) < ttl {
            return
        }

        let window = Self.window()
        let task = Task { @MainActor [weak self] in
            self?.states[id]?.isLoading = true
            do {
                let items = try await plugin.fetch(window: window)
                self?.states[id] = PluginState(items: items, lastUpdated: Date())
                if plugin.cacheTTL != nil { ScheduleCache.save(items, for: id) }
            } catch {
                // 실패해도 마지막 데이터는 그대로 두고 오류만 적는다.
                self?.states[id]?.isLoading = false
                self?.states[id]?.errorMessage = error.networkErrorMessage
            }
        }
        running[id] = task
        await task.value
        running[id] = nil
    }

    // MARK: - 플러그인 뷰

    func detailView(for item: ScheduleItem,
                    variant: ScheduleDetailVariant,
                    dismiss: @escaping @MainActor () -> Void) async throws -> AnyView {
        guard let plugin = plugin(item.plugin) else { throw ScheduleStoreError.unknownPlugin }
        return try await plugin.detailView(for: item, accent: color(for: item), variant: variant, dismiss: dismiss)
    }

    /// 새 항목을 만들 수 있는 첫 플러그인의 뷰.
    func newItemView(on day: Date, dismiss: @escaping @MainActor () -> Void) -> AnyView? {
        for plugin in enabledPlugins {
            if let view = plugin.newItemView(on: day, dismiss: dismiss) { return view }
        }
        return nil
    }
}

nonisolated enum ScheduleStoreError: LocalizedError {
    case unknownPlugin

    var errorDescription: String? {
        switch self {
        case .unknownPlugin: return "이 항목의 출처를 찾을 수 없어요."
        }
    }
}
