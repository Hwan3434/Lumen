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
