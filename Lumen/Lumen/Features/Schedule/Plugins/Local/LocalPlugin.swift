import Foundation
import SwiftUI

nonisolated extension SchedulePluginID {
    static let local = SchedulePluginID("local")
}

nonisolated struct LocalSettings: Codable, Equatable {
    var isVisible = true
}

/// 내 일정. 연동 없이 Lumen 안에서 직접 적는 일정으로, 항상 켜져 있고 묶음은 하나다.
/// 설정 탭은 없고 캘린더 위 칩으로만 숨긴다.
@Observable
@MainActor
final class LocalPlugin: SchedulePlugin {
    static let shared = LocalPlugin()
    nonisolated static let groupID = "local"
    nonisolated static let groupName = "내 일정"

    let id = SchedulePluginID.local
    let displayName = LocalPlugin.groupName
    let iconName = "calendar-plus"

    private(set) var events: [LocalEvent]
    var settings: LocalSettings {
        didSet { PluginSettings.save(settings, for: id) }
    }
    @ObservationIgnored private var onChange: (@MainActor () -> Void)?

    private init() {
        settings = PluginSettings.load(.local, default: LocalSettings())
        events = LumenStorage.read([LocalEvent].self, from: .localEvents) ?? []
    }

    var isEnabled: Bool { true }
    var contributesToMenuBarLabel: Bool { true }

    var groups: [ScheduleGroup] {
        [ScheduleGroup(id: Self.groupID, name: Self.groupName, isVisible: settings.isVisible)]
    }

    // MARK: - 편집

    func add(_ event: LocalEvent) {
        events.append(event)
        sortAndSave()
    }

    func update(_ event: LocalEvent) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[idx] = event
        sortAndSave()
    }

    func delete(id: UUID) {
        events.removeAll { $0.id == id }
        save()
    }

    private func sortAndSave() {
        events.sort { $0.start < $1.start }
        save()
    }

    private func save() {
        LumenStorage.write(events, to: .localEvents)
        onChange?()
    }

    func event(for item: ScheduleItem) -> LocalEvent? {
        guard item.id.hasPrefix("local."),
              let uuid = UUID(uuidString: String(item.id.dropFirst("local.".count))) else { return nil }
        return events.first { $0.id == uuid }
    }

    // MARK: - SchedulePlugin

    func fetch(window: DateInterval) async throws -> [ScheduleItem] {
        events.map(Self.makeItem)
    }

    func startObserving(_ onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func setGroupVisible(_ groupID: String, _ visible: Bool) {
        settings.isVisible = visible
    }

    func detailView(for item: ScheduleItem, accent: Color, variant: ScheduleDetailVariant,
                    dismiss: @escaping @MainActor () -> Void) async throws -> AnyView? {
        guard let event = event(for: item) else { return nil }
        return AnyView(LocalEventPopover(plugin: self, draft: event, isNew: false, onDismiss: dismiss))
    }

    func newItemView(on day: Date, dismiss: @escaping @MainActor () -> Void) -> AnyView? {
        let draft = LocalEvent(title: "", start: Calendar.current.startOfDay(for: day))
        return AnyView(LocalEventPopover(plugin: self, draft: draft, isNew: true, onDismiss: dismiss))
    }

    nonisolated static func makeItem(_ event: LocalEvent) -> ScheduleItem {
        ScheduleItem(
            id: "local.\(event.id.uuidString)",
            plugin: .local,
            group: groupID,
            title: event.title,
            start: event.start,
            end: event.end,
            isAllDay: true,
            kind: .event,
            subtitle: groupName
        )
    }
}
