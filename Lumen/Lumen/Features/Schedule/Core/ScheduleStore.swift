import SwiftUI
import Observation

/// 플러그인 상태를 모아 들고, 보이는 항목과 묶음 색을 한 곳에서 계산한다.
/// 월간·주간·메뉴바가 전부 `visibleItems`만 본다.
@Observable
@MainActor
final class ScheduleStore {
    static let shared = ScheduleStore(plugins: SchedulePlugins.all)

    struct Failure: Identifiable {
        let plugin: any SchedulePlugin
        let message: String
        var id: String { plugin.id.rawValue }
    }

    let plugins: [any SchedulePlugin]
    /// 항목과 조회 중·오류 표시를 따로 든다. 한 사전에 두면 조회 중 표시가 켜지고 꺼질 때마다
    /// 항목을 읽는 달력과 목록까지 다시 그려진다.
    private var items: [SchedulePluginID: [ScheduleItem]] = [:]
    private var updatedAt: [SchedulePluginID: Date] = [:]
    private var errors: [SchedulePluginID: String] = [:]
    private var loading: Set<SchedulePluginID> = []
    @ObservationIgnored private var running: [SchedulePluginID: Task<Void, Never>] = [:]
    /// 조회가 도는 중에 강제 갱신이 또 들어온 플러그인. 도는 조회는 바뀌기 전 설정으로 받고 있으니 끝난 뒤 한 번 더 받는다.
    @ObservationIgnored private var dirty: Set<SchedulePluginID> = []

    /// 화면 전체가 보는 시계. 오늘 표시, 날짜 묶음, 메뉴바 라벨이 이 값만 본다.
    /// 1분마다 깨우지 않고 다음 경계(자정, 오늘 시간 일정의 시작·끝)에만 갱신한다.
    private(set) var now = Date()
    @ObservationIgnored private var clockTimer: Timer?

    var today: Date { Calendar.current.startOfDay(for: now) }

    init(plugins: [any SchedulePlugin]) {
        self.plugins = plugins
        for plugin in plugins {
            // 앱을 켜면 마지막 데이터로 먼저 그리고, TTL이 지났으면 뒤에서 갱신한다.
            if plugin.cacheTTL != nil, let cached = ScheduleCache.load(plugin.id) {
                items[plugin.id] = cached.items
                updatedAt[plugin.id] = cached.savedAt
            }
            plugin.startObserving { [weak self] in
                Task { await self?.refresh(plugin.id, force: true) }
            }
        }
    }

    // MARK: - 시계

    /// 시계를 켠다. 앱이 한 번 부른다(테스트에서 만든 스토어는 켜지 않는다).
    /// 보이는 항목이 바뀌면(갱신, 칩으로 묶음 켜고 끄기) 다음 경계를 다시 잡는다.
    func startClock() {
        tick()
        observeVisibleItemsForClock()
        // 타이머는 잠든 시간을 세지 않아 자정을 넘겨 깨어나면 늦게 울린다. 깨어날 때, 날짜가 바뀔 때,
        // 시간대가 바뀔 때는 타이머를 기다리지 않고 바로 맞춘다.
        let wake = (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification)
        let dayChanged = (NotificationCenter.default, Notification.Name.NSCalendarDayChanged)
        let timeZoneChanged = (NotificationCenter.default, Notification.Name.NSSystemTimeZoneDidChange)
        for (center, name) in [wake, dayChanged, timeZoneChanged] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.tick() }
            }
        }
    }

    private func observeVisibleItemsForClock() {
        withObservationTracking {
            _ = visibleItems
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.itemsChangedForClock()
                self?.observeVisibleItemsForClock()
            }
        }
    }

    /// 항목이 바뀔 때마다 `now`를 새로 쓰면 `now`를 읽는 화면 전부가 갱신 한 번에 여러 번 다시 그려진다.
    /// 그래서 새 항목 기준으로 이미 지난 경계가 있을 때만 시계를 넘기고, 아니면 타이머만 다시 건다.
    private func itemsChangedForClock() {
        if Self.clockIsBehind(now: now, items: visibleItems, current: Date()) {
            tick()
        } else {
            armClockTimer()
        }
    }

    /// `now`가 마지막으로 넘어간 뒤로 `items`의 경계(자정, 오늘 시간 일정의 시작·끝)가 이미 지났는가.
    nonisolated static func clockIsBehind(now: Date, items: [ScheduleItem], current: Date) -> Bool {
        nextBoundary(after: now, items: items) <= current
    }

    private func tick() {
        now = Date()
        armClockTimer()
    }

    private func armClockTimer() {
        clockTimer?.invalidate()
        let next = Self.nextBoundary(after: now, items: visibleItems)
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    /// 다음에 화면이 바뀌어야 하는 시각: 다음 자정, 또는 그 전에 오는 오늘 시간 일정의 시작·끝 중 가장 이른 것(1초 여유).
    nonisolated static func nextBoundary(after now: Date, items: [ScheduleItem]) -> Date {
        let cal = Calendar.current
        let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now.addingTimeInterval(3600)
        var next = midnight
        for item in items where item.hasTimeOfDay {
            for edge in [item.start, item.end].compactMap({ $0 }) where edge > now && edge < next {
                next = edge
            }
        }
        return next.addingTimeInterval(1)
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
            guard let fetched = items[plugin.id], !fetched.isEmpty else { continue }
            let visible = Set(plugin.groups.filter(\.isVisible).map(\.id))
            result.append(contentsOf: fetched.filter { visible.contains($0.group) })
        }
        return result
    }

    /// 그날에 걸친 항목. 기간 항목(스프린트)은 목록·메뉴바에 넣지 않는다.
    func items(on day: Date) -> [ScheduleItem] {
        visibleItems.filter { $0.kind != .span && $0.covers(day) }
    }

    var lastUpdated: Date? {
        enabledPlugins.compactMap { updatedAt[$0.id] }.max()
    }

    var isRefreshing: Bool {
        enabledPlugins.contains { loading.contains($0.id) }
    }

    var failures: [Failure] {
        enabledPlugins.compactMap { plugin in
            errors[plugin.id].map { Failure(plugin: plugin, message: $0) }
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

    /// TTL이 지난 플러그인만 다시 받는다. 패널·메뉴바 팝오버를 열 때마다 부른다.
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
            // 이미 비어 있으면 건드리지 않는다 — 꺼진 플러그인 때문에 열 때마다 화면이 다시 그려지지 않도록.
            if items[id] != nil || updatedAt[id] != nil || errors[id] != nil {
                items[id] = nil
                updatedAt[id] = nil
                errors[id] = nil
                if plugin.cacheTTL != nil { ScheduleCache.remove(id) }
            }
            return
        }
        // 같은 플러그인을 겹쳐 받지 않는다 — 먼저 시작한 조회를 기다린다.
        if let task = running[id] {
            // 조회가 이미 설정을 읽고 떠났을 때만 다시 받게 표시한다. 아직 출발 전이면 그 조회가 새 설정으로 받는다
            // (설정 저장이 콜백을 연달아 두 번 부를 때 두 번 받지 않도록).
            if force, loading.contains(id) { dirty.insert(id) }
            await task.value
            return
        }
        if !force, let ttl = plugin.cacheTTL, let at = updatedAt[id],
           Date().timeIntervalSince(at) < ttl {
            return
        }

        let window = Self.window()
        let task = Task { @MainActor [weak self] in
            // 끝나는 즉시 스스로 비운다. 기다리던 쪽이 비우면 그 사이에 들어온 호출이 끝난 조회에 합류해 버린다.
            defer {
                self?.running[id] = nil
                self?.loading.remove(id)
            }
            self?.loading.insert(id)
            do {
                let fetched = try await plugin.fetch(window: window)
                // 받는 사이에 플러그인을 껐으면 버린다. 쓰면 방금 지운 캐시 파일이 다시 생긴다.
                guard let self, plugin.isEnabled else { return }
                self.items[id] = fetched
                self.updatedAt[id] = Date()
                self.errors[id] = nil
                if plugin.cacheTTL != nil { ScheduleCache.save(fetched, for: id) }
            } catch {
                // 실패해도 마지막 데이터는 그대로 두고 오류만 적는다.
                guard plugin.isEnabled else { return }
                self?.errors[id] = error.networkErrorMessage
            }
        }
        running[id] = task
        await task.value
        if dirty.remove(id) != nil {
            await refresh(id, force: true)
        }
    }

    // MARK: - 플러그인 뷰

    func detailView(for item: ScheduleItem,
                    variant: ScheduleDetailVariant,
                    dismiss: @escaping @MainActor () -> Void) async throws -> AnyView {
        guard let plugin = plugin(item.plugin) else { throw ScheduleStoreError.unknownPlugin }
        let accent = color(for: item)
        // 플러그인이 따로 상세를 내주지 않는 항목은 기본 미리보기로 보여 준다.
        return try await plugin.detailView(for: item, accent: accent, variant: variant, dismiss: dismiss)
            ?? AnyView(ScheduleItemPreview(item: item, accent: accent))
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
