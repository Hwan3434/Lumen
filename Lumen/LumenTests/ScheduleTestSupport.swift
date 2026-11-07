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

    init(name: String, icon: String = "star", groups: [(String, Bool)]) {
        self.id = SchedulePluginID("\(name)-\(UUID().uuidString)")
        self.displayName = name
        self.iconName = icon
        self.groups = groups.map { ScheduleGroup(id: $0.0, name: $0.0, isVisible: $0.1) }
    }

    func fetch(window: DateInterval) async throws -> [ScheduleItem] {
        fetchCount += 1
        if let error { throw error }
        return items
    }

    func setGroupVisible(_ groupID: String, _ visible: Bool) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[idx].isVisible = visible
    }

    func detailView(for item: ScheduleItem, accent: Color, variant: ScheduleDetailVariant,
                    dismiss: @escaping @MainActor () -> Void) async throws -> AnyView {
        AnyView(ScheduleItemPreview(item: item, accent: accent))
    }
}
