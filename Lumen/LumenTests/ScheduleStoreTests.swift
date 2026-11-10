import XCTest
import SwiftUI
@testable import Lumen

/// 플러그인 상태를 합치는 규칙. 꺼진 플러그인은 빠지고, 숨긴 묶음은 걸러지고, 색은 보이는 묶음 순서로 붙는다.
@MainActor
final class ScheduleStoreTests: XCTestCase {

    func testVisibleItemsFollowPluginAndGroupVisibility() async {
        let a = FakeSchedulePlugin(name: "a", groups: [("g1", true), ("g2", false)])
        a.items = [item("a.1", plugin: a.id, group: "g1"), item("a.2", plugin: a.id, group: "g2")]
        let b = FakeSchedulePlugin(name: "b", groups: [("x", true)])
        b.items = [item("b.1", plugin: b.id, group: "x")]
        b.isEnabled = false

        let store = ScheduleStore(plugins: [a, b])
        await store.refreshAll(force: true)

        XCTAssertEqual(store.visibleItems.map(\.id), ["a.1"], "꺼진 플러그인과 숨긴 묶음은 보이지 않는다")
        XCTAssertEqual(b.fetchCount, 0, "꺼진 플러그인은 조회하지 않는다")

        b.isEnabled = true
        await store.refreshAll(force: true)
        XCTAssertEqual(Set(store.visibleItems.map(\.id)), ["a.1", "b.1"])

        a.setGroupVisible("g2", true)
        XCTAssertEqual(Set(store.visibleItems.map(\.id)), ["a.1", "a.2", "b.1"], "칩을 켜면 조회 없이 바로 보인다")
    }

    func testGroupColorsSkipHiddenGroupsAndRespectCustomColor() {
        let a = FakeSchedulePlugin(name: "a", groups: [("g1", true), ("g2", false), ("g3", true)])
        let b = FakeSchedulePlugin(name: "b", groups: [("x", true)])
        b.customColor = .red
        let store = ScheduleStore(plugins: [a, b])

        let colors = store.groupColors
        let palette = LumenTokens.Palette.chartCategories

        XCTAssertEqual(colors[ScheduleGroupKey(plugin: a.id, group: "g1")], palette[0])
        XCTAssertEqual(colors[ScheduleGroupKey(plugin: a.id, group: "g2")], LumenTokens.Palette.chartOther, "숨긴 묶음은 자리를 차지하지 않는다")
        XCTAssertEqual(colors[ScheduleGroupKey(plugin: a.id, group: "g3")], palette[1])
        XCTAssertEqual(colors[ScheduleGroupKey(plugin: b.id, group: "x")], .red, "플러그인이 정한 색이 우선")
    }

    func testRefreshRespectsTTLUnlessForced() async {
        let a = FakeSchedulePlugin(name: "ttl", groups: [("g", true)])
        a.cacheTTL = 3600
        defer { ScheduleCache.remove(a.id) }
        let store = ScheduleStore(plugins: [a])

        await store.refresh(a.id, force: true)
        XCTAssertEqual(a.fetchCount, 1)
        await store.refresh(a.id, force: false)
        XCTAssertEqual(a.fetchCount, 1, "TTL 안에서는 다시 받지 않는다")
        await store.refresh(a.id, force: true)
        XCTAssertEqual(a.fetchCount, 2)
        XCTAssertNotNil(ScheduleCache.load(a.id), "TTL이 있는 플러그인은 디스크에 남긴다")
    }

    func testFailedRefreshKeepsLastItemsAndRecordsError() async {
        let a = FakeSchedulePlugin(name: "fail", groups: [("g", true)])
        a.items = [item("a.1", plugin: a.id, group: "g")]
        let store = ScheduleStore(plugins: [a])

        await store.refresh(a.id, force: true)
        XCTAssertEqual(store.visibleItems.count, 1)

        a.error = URLError(.notConnectedToInternet)
        await store.refresh(a.id, force: true)

        XCTAssertEqual(store.visibleItems.count, 1, "실패해도 마지막 데이터는 남는다")
        XCTAssertEqual(store.failures.map(\.message), ["인터넷 연결을 확인해 주세요."])
        XCTAssertFalse(store.isRefreshing)
    }

    /// 조회가 설정을 읽고 떠난 뒤 강제 갱신이 또 오면, 도는 조회에 묻어가지 않고 끝난 뒤 한 번 더 받는다.
    func testForcedRefreshDuringFetchRunsAgainWithNewData() async {
        let a = FakeSchedulePlugin(name: "overlap", groups: [("g", true)])
        a.items = [item("old", plugin: a.id, group: "g")]
        let store = ScheduleStore(plugins: [a])

        var release: CheckedContinuation<Void, Never>?
        a.beforeReturn = { await withCheckedContinuation { release = $0 } }
        let first = Task { await store.refresh(a.id, force: true) }
        while release == nil { await Task.yield() }

        a.items = [item("new", plugin: a.id, group: "g")]
        a.beforeReturn = nil
        let second = Task { await store.refresh(a.id, force: true) }
        await Task.yield()
        release?.resume()
        await first.value
        await second.value

        XCTAssertEqual(store.visibleItems.map(\.id), ["new"])
        XCTAssertEqual(a.fetchCount, 2)
        XCTAssertFalse(store.isRefreshing)
    }

    /// 설정 저장은 콜백을 연달아 두 번 부른다. 조회가 아직 출발 전이면 한 번만 받는다.
    func testForcedRefreshesBeforeFetchStartsShareOneFetch() async {
        let a = FakeSchedulePlugin(name: "burst", groups: [("g", true)])
        let store = ScheduleStore(plugins: [a])

        let first = Task { await store.refresh(a.id, force: true) }
        let second = Task { await store.refresh(a.id, force: true) }
        await first.value
        await second.value

        XCTAssertEqual(a.fetchCount, 1)
    }

    /// 받는 사이에 플러그인을 끄면 결과를 버린다. 꺼서 지운 캐시 파일이 다시 생기면 안 된다.
    func testDisablingDuringFetchDropsTheResult() async {
        let a = FakeSchedulePlugin(name: "disable", groups: [("g", true)])
        a.cacheTTL = 3600
        a.items = [item("a.1", plugin: a.id, group: "g")]
        defer { ScheduleCache.remove(a.id) }
        let store = ScheduleStore(plugins: [a])

        var release: CheckedContinuation<Void, Never>?
        a.beforeReturn = { await withCheckedContinuation { release = $0 } }
        let fetch = Task { await store.refresh(a.id, force: true) }
        while release == nil { await Task.yield() }

        a.isEnabled = false
        await store.refresh(a.id, force: true)
        release?.resume()
        await fetch.value

        XCTAssertNil(ScheduleCache.load(a.id))
        a.isEnabled = true
        XCTAssertTrue(store.visibleItems.isEmpty, "다시 켜도 버린 결과가 나타나지 않는다")
        XCTAssertNil(store.lastUpdated)
    }

    /// 항목이 바뀔 때는 새 항목 기준으로 이미 지난 경계가 있을 때만 시계를 넘긴다.
    func testClockAdvancesOnItemChangeOnlyWhenABoundaryHasPassed() {
        let cal = Calendar.current
        let midnight = cal.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))
        func at(_ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: midnight)!
        }
        let meeting = ScheduleItem(id: "m", plugin: SchedulePluginID("x"), group: "g", title: "m",
                                   start: at(13, 30), end: at(14), isAllDay: false, kind: .event)

        XCTAssertFalse(ScheduleStore.clockIsBehind(now: at(9), items: [], current: at(14, 5)),
                       "항목이 없으면 자정 전까지는 넘길 일이 없다")
        XCTAssertTrue(ScheduleStore.clockIsBehind(now: at(9), items: [meeting], current: at(14, 5)),
                      "새로 받은 일정의 시작이 이미 지났으면 넘긴다 — 아니면 끝난 일정이 목록에 남는다")
        XCTAssertFalse(ScheduleStore.clockIsBehind(now: at(9), items: [meeting], current: at(10)))
        XCTAssertTrue(ScheduleStore.clockIsBehind(now: at(9), items: [], current: at(9).addingTimeInterval(86_400)),
                      "자정을 넘겼으면 넘긴다")
    }

    func testCacheRoundTrip() {
        let id = SchedulePluginID("cache-\(UUID().uuidString)")
        defer { ScheduleCache.remove(id) }
        // ISO 8601로 저장하므로 초 단위로 맞춘 날짜를 쓴다.
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        var saved = ScheduleItem(id: "x.1", plugin: id, group: "g", title: "x.1",
                                 start: start, end: start.addingTimeInterval(3600), isAllDay: false, kind: .event)
        saved.url = URL(string: "https://example.com/x")
        saved.status = .inProgress

        ScheduleCache.save([saved], for: id)
        let loaded = ScheduleCache.load(id)

        XCTAssertEqual(loaded?.items, [saved])
        XCTAssertNotNil(loaded?.savedAt)
        ScheduleCache.remove(id)
        XCTAssertNil(ScheduleCache.load(id))
    }

    // MARK: - Helpers

    private func item(_ id: String, plugin: SchedulePluginID, group: String) -> ScheduleItem {
        ScheduleItem(id: id, plugin: plugin, group: group, title: id,
                     start: Date(), end: nil, isAllDay: true, kind: .event)
    }
}
