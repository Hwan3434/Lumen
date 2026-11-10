import SwiftUI
@testable import Lumen

/// 네트워크 없는 가짜 플러그인. 테스트마다 다른 id를 써 디스크 캐시가 섞이지 않게 한다.
@Observable
@MainActor
final class FakeSchedulePlugin: SchedulePlugin {
    let id: SchedulePluginID
    let displayName: String
    let iconName: String
    var isEnabled = true
    var groups: [ScheduleGroup]
    var cacheTTL: TimeInterval? = nil
    var contributesToMenuBarLabel: Bool = true
    var customColor: Color? = nil {
        didSet { groups = groups.map { ScheduleGroup(id: $0.id, name: $0.name, isVisible: $0.isVisible, customColor: customColor) } }
    }
    var items: [ScheduleItem] = []
    var error: Error? = nil
    var fetchCount = 0
    /// 조회를 중간에 붙잡아 두는 갈고리. 겹치는 갱신을 테스트할 때 쓴다.
    var beforeReturn: (() async -> Void)?

    init(name: String, icon: String = "star", groups: [(String, Bool)], id: SchedulePluginID? = nil) {
        self.id = id ?? SchedulePluginID("\(name)-\(UUID().uuidString)")
        self.displayName = name
        self.iconName = icon
        self.groups = groups.map { ScheduleGroup(id: $0.0, name: $0.0, isVisible: $0.1) }
    }

    func fetch(window: DateInterval) async throws -> [ScheduleItem] {
        fetchCount += 1
        // 실제 플러그인처럼 조회를 시작할 때의 값으로 답한다.
        let snapshot = items
        await beforeReturn?()
        if let error { throw error }
        return snapshot
    }

    func setGroupVisible(_ groupID: String, _ visible: Bool) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[idx].isVisible = visible
    }
}
