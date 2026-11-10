import EventKit
import Foundation
import SwiftUI

nonisolated extension SchedulePluginID {
    static let calendar = SchedulePluginID("calendar")
}

nonisolated struct CalendarSettings: Codable, Equatable {
    var enabled = false
    var hiddenCalendarIDs: Set<String> = []
    /// 켜면 캘린더 앱에서 정한 색을 그대로 쓴다. 끄면 보이는 묶음 순서대로 Still 차트 색.
    var useAppColors = false
    var inMenuBar = true
}

/// macOS 캘린더 앱에 연결된 캘린더(iCloud, Google 등)의 일정.
/// 묶음은 캘린더 하나다. 숨긴 캘린더도 함께 받아 두어 칩을 켜고 끌 때 다시 조회하지 않는다.
@Observable
@MainActor
final class CalendarPlugin: SchedulePlugin {
    static let shared = CalendarPlugin()

    let id = SchedulePluginID.calendar
    let displayName = "캘린더"
    let iconName = "calendar"

    var settings: CalendarSettings {
        didSet { PluginSettings.save(settings, for: id) }
    }
    private(set) var authorizationStatus: EKAuthorizationStatus
    private(set) var calendars: [EKCalendar] = []

    /// EKEventStore는 Sendable이 아니지만 조회는 스레드 안전하고, 여기서 만든 EKEvent를
    /// 다른 스레드로 넘기지 않는다(백그라운드에서 값 타입으로 바꾼 뒤에만 메인으로 보낸다).
    @ObservationIgnored private nonisolated(unsafe) let store = EKEventStore()
    @ObservationIgnored private var onChange: (@MainActor () -> Void)?
    @ObservationIgnored private var changeObserver: NSObjectProtocol?
    @ObservationIgnored private var debounce: Task<Void, Never>?
    /// 상세 팝오버용 원본. 항목 id → 이벤트.
    @ObservationIgnored private var eventsByItemID: [String: ExternalCalendarEvent] = [:]

    private init() {
        settings = PluginSettings.load(.calendar, default: CalendarSettings())
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        reloadCalendars()
    }

    var isEnabled: Bool { settings.enabled }
    var contributesToMenuBarLabel: Bool { settings.inMenuBar }

    var groups: [ScheduleGroup] {
        calendars.map { cal in
            ScheduleGroup(
                id: cal.calendarIdentifier,
                name: cal.title,
                isVisible: !settings.hiddenCalendarIDs.contains(cal.calendarIdentifier),
                customColor: settings.useAppColors ? Color(cgColor: cal.cgColor) : nil
            )
        }
    }

    // MARK: - 설정

    func setEnabled(_ enabled: Bool) {
        settings.enabled = enabled
        if enabled {
            Task {
                await requestAccessIfNeeded()
                onChange?()
            }
        } else {
            onChange?()
        }
    }

    func setGroupVisible(_ groupID: String, _ visible: Bool) {
        if visible {
            settings.hiddenCalendarIDs.remove(groupID)
        } else {
            settings.hiddenCalendarIDs.insert(groupID)
        }
    }

    func setUseAppColors(_ on: Bool) { settings.useAppColors = on }
    func setInMenuBar(_ on: Bool) { settings.inMenuBar = on }

    // MARK: - 권한

    func requestAccessIfNeeded() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined {
            do {
                let granted = try await store.requestFullAccessToEvents()
                authorizationStatus = granted ? .fullAccess : .denied
            } catch {
                authorizationStatus = .denied
            }
        } else {
            authorizationStatus = status
        }
        reloadCalendars()
    }

    private func reloadCalendars() {
        guard authorizationStatus == .fullAccess else {
            calendars = []
            return
        }
        calendars = store.calendars(for: .event)
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // MARK: - SchedulePlugin

    func fetch(window: DateInterval) async throws -> [ScheduleItem] {
        guard settings.enabled else {
            eventsByItemID = [:]
            return []
        }
        await requestAccessIfNeeded()
        guard authorizationStatus == .fullAccess, !calendars.isEmpty else {
            eventsByItemID = [:]
            return []
        }

        let predicate = store.predicateForEvents(withStart: window.start, end: window.end, calendars: calendars)
        let eventStore = store
        let events = await Task.detached(priority: .userInitiated) { () -> [ExternalCalendarEvent] in
            let matched = eventStore.events(matching: predicate)
            var seen = Set<EventOccurrenceKey>()
            return matched
                .filter { seen.insert(EventOccurrenceKey($0)).inserted }
                .compactMap(ExternalCalendarEvent.init(event:))
        }.value

        var byID: [String: ExternalCalendarEvent] = [:]
        let items = events.map { event in
            let item = Self.makeItem(event)
            byID[item.id] = event
            return item
        }
        eventsByItemID = byID
        return items
    }

    func startObserving(_ onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleChange() }
        }
    }

    /// 변경 알림이 연달아 오면 2초 모아서 한 번만 갱신한다.
    private func scheduleChange() {
        debounce?.cancel()
        debounce = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.reloadCalendars()
            self?.onChange?()
        }
    }

    func detailView(for item: ScheduleItem, accent: Color, variant: ScheduleDetailVariant,
                    dismiss: @escaping @MainActor () -> Void) async throws -> AnyView? {
        guard let event = eventsByItemID[item.id] else { return nil }
        return AnyView(EKEventPreviewPopover(event: event, timeLabel: ScheduleItemFormat.timeLabel(item), accent: accent))
    }

    /// 아직 묻지 않았으면 가져올 때 시스템이 묻는다. 거부·제한된 경우만 안내한다.
    var setupHint: String? {
        guard settings.enabled else { return nil }
        switch authorizationStatus {
        case .fullAccess, .notDetermined:
            return nil
        default:
            return "캘린더를 읽을 권한이 없어요. 시스템 설정 › 개인정보 보호 › 캘린더에서 Lumen을 켜 주세요."
        }
    }

    var hasSettingsTab: Bool { true }

    func makeSettingsTab(action: SettingsActionViewModel) -> AnyView {
        AnyView(CalendarSettingsTab(plugin: self, action: action))
    }

    /// 종일 이벤트의 끝을 포함 범위(마지막 날 0시)로 바꾼다. EventKit은 끝을 다음날 0시로 주기도 하고
    /// 마지막 날 23:59:59로 주기도 해서, 하루를 빼지 않고 끝 1초 전이 속한 날을 마지막 날로 본다.
    nonisolated static func makeItem(_ event: ExternalCalendarEvent) -> ScheduleItem {
        let cal = Calendar.current
        let end: Date?
        if event.isAllDay {
            let lastDay = cal.startOfDay(for: event.endDate.addingTimeInterval(-1))
            end = lastDay > cal.startOfDay(for: event.startDate) ? lastDay : nil
        } else {
            end = event.endDate
        }
        // 반복 이벤트는 모든 회차가 같은 eventIdentifier를 가지므로 시작 시각을 붙여야 id가 겹치지 않는다.
        // 캘린더 id도 넣는다 — 중복 제거 키(`EventOccurrenceKey`)가 캘린더까지 보므로 id가 그보다 성기면 안 된다.
        return ScheduleItem(
            id: "calendar.\(event.calendarIdentifier).\(event.id).\(Int(event.startDate.timeIntervalSince1970))",
            plugin: .calendar,
            group: event.calendarIdentifier,
            title: event.title,
            start: event.startDate,
            end: end,
            isAllDay: event.isAllDay,
            kind: .event,
            subtitle: event.calendarTitle,
            location: event.location,
            url: event.urlString.flatMap { URL(string: $0) }
        )
    }
}

/// EKEvent를 값 타입으로 옮긴 것. 상세 팝오버가 메모·위치·링크를 보여줄 때 쓴다.
nonisolated struct ExternalCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarIdentifier: String
    let calendarTitle: String
    let sourceTitle: String?
    let notes: String?
    let location: String?
    let urlString: String?

    init?(
        id: String?,
        title: String?,
        startDate: Date?,
        endDate: Date?,
        isAllDay: Bool,
        calendarIdentifier: String = "",
        calendarTitle: String,
        sourceTitle: String?,
        notes: String?,
        location: String?,
        urlString: String?
    ) {
        guard let id, let startDate, let endDate else { return nil }
        self.id = id
        self.title = title ?? "(제목 없음)"
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarIdentifier = calendarIdentifier
        self.calendarTitle = calendarTitle
        self.sourceTitle = sourceTitle
        self.notes = notes
        self.location = location
        self.urlString = urlString
    }

    init?(event: EKEvent) {
        self.init(
            id: event.eventIdentifier ?? event.calendarItemIdentifier,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendarIdentifier: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            sourceTitle: event.calendar.source?.title,
            notes: event.notes,
            location: event.location,
            urlString: event.url?.absoluteString
        )
    }
}

/// EventKit은 같은 회차를 두 번 돌려주기도 한다. 반복 이벤트는 식별자를 공유하므로
/// 캘린더와 시각까지 키에 넣어 걸러낸다.
private nonisolated struct EventOccurrenceKey: Hashable {
    let calendarIdentifier: String
    let eventIdentifier: String
    let start: UInt64?
    let end: UInt64?

    init(_ event: EKEvent) {
        calendarIdentifier = event.calendar.calendarIdentifier
        eventIdentifier = event.eventIdentifier ?? event.calendarItemIdentifier
        start = event.startDate?.timeIntervalSinceReferenceDate.bitPattern
        end = event.endDate?.timeIntervalSinceReferenceDate.bitPattern
    }
}
