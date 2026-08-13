import EventKit
import Foundation
import CoreGraphics
import OSLog

// macOS Calendar.app에 연동된 캘린더에서 이벤트를 가져온다.
// 표시 여부는 사용자가 popover 토글로 직접 결정 (블랙리스트 방식 — disabled IDs).
// 휴일 자동 제외는 하지 않는다 — 사용자가 KoreanHolidays와 중복되는 게 싫으면 직접 끈다.

@Observable
@MainActor
final class EventKitService {
    static let shared = EventKitService()
    private static let logger = Logger(subsystem: "com.jh.Lumen", category: "EventKitService")

    /// EKEventStore는 Sendable이 아니지만 조회는 스레드 안전하고, 여기서 만든 EKEvent를
    /// 다른 스레드로 넘기지 않는다(백그라운드에서 값 타입으로 변환한 뒤에만 메인으로 보낸다).
    /// Swift 6 격리 검사에 이 의도를 명시한다.
    private nonisolated(unsafe) let store = EKEventStore()

    /// 진행 중인 조회. `.EKEventStoreChanged`가 연달아 오면 조회가 겹치는데, 완료 순서는
    /// 보장되지 않아 오래된 결과가 최신 결과를 덮어쓸 수 있다. 새 조회 전에 이전 것을 취소한다.
    private var fetchTask: Task<Void, Never>?
    private(set) var events: [ExternalCalendarEvent] = []
    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    /// 여러 strip이 동일 인스턴스를 구독해 한 strip의 토글이 즉시 다른 strip에 반영되도록 @Observable로 노출.
    private(set) var disabledCalendarIDs: Set<String> = []

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        disabledCalendarIDs = CredentialsStore.shared.iCalDisabledCalendarIDs
    }

    // MARK: - Authorization & Fetch

    func requestAccessAndFetch() async {
        guard CredentialsStore.shared.isICalEnabled else {
            events = []
            return
        }
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined {
            do {
                let granted = try await store.requestFullAccessToEvents()
                authorizationStatus = granted ? .fullAccess : .denied
            } catch {
                authorizationStatus = .denied
                return
            }
        } else {
            authorizationStatus = status
        }
        guard authorizationStatus == .fullAccess else { return }
        fetch()
    }

    func fetch() {
        guard CredentialsStore.shared.isICalEnabled, authorizationStatus == .fullAccess else {
            events = []
            return
        }
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -90, to: now) ?? now
        let end   = cal.date(byAdding: .day, value: +90, to: now) ?? now

        let calendars = store.calendars(for: .event).filter {
            !disabledCalendarIDs.contains($0.calendarIdentifier)
        }
        guard !calendars.isEmpty else {
            events = []
            return
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let eventStore = self.store

        fetchTask?.cancel()
        fetchTask = Task.detached(priority: .userInitiated) {
            let matched = eventStore.events(matching: predicate)
            guard !Task.isCancelled else { return }

            var seenOccurrences: Set<EventOccurrenceKey> = []
            let uniqueMatches = matched.filter { event in
                seenOccurrences.insert(EventOccurrenceKey(event)).inserted
            }
            let uniqueEvents = uniqueMatches.compactMap(ExternalCalendarEvent.init(event:))
            let duplicateCount = matched.count - uniqueMatches.count

            guard !Task.isCancelled else { return }
            await MainActor.run {
                if duplicateCount > 0 {
                    Self.logger.warning("Removed \(duplicateCount, privacy: .public) duplicate EventKit occurrence(s)")
                }
                // 싱글턴이라 self를 캡처할 필요가 없다 — 캡처하면 Swift 6에서 격리 위반이 된다.
                EventKitService.shared.events = uniqueEvents
            }
        }
    }

    /// 휴일 캘린더도 포함 — 사용자가 KoreanHolidays와 중복되면 직접 OFF한다.
    func availableCalendars() -> [EKCalendar] {
        guard authorizationStatus == .fullAccess else { return [] }
        return store.calendars(for: .event)
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func setDisabledCalendarIDs(_ ids: Set<String>) {
        guard ids != disabledCalendarIDs else { return }
        disabledCalendarIDs = ids
        CredentialsStore.shared.setICalDisabledCalendarIDs(ids)
        fetch()
    }

    func event(withIdentifier id: String) -> ExternalCalendarEvent? {
        events.first { $0.id == id }
    }

}

nonisolated struct ExternalCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let sourceTitle: String?
    let calendarColor: CGColor
    let notes: String?
    let location: String?
    let urlString: String?

    init?(
        id: String?,
        title: String?,
        startDate: Date?,
        endDate: Date?,
        isAllDay: Bool,
        calendarTitle: String,
        sourceTitle: String?,
        calendarColor: CGColor,
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
        self.calendarTitle = calendarTitle
        self.sourceTitle = sourceTitle
        self.calendarColor = calendarColor
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
            calendarTitle: event.calendar.title,
            sourceTitle: event.calendar.source?.title,
            calendarColor: event.calendar.cgColor,
            notes: event.notes,
            location: event.location,
            urlString: event.url?.absoluteString
        )
    }
}

/// EventKit may return the same synced occurrence more than once. Recurring events can share a
/// base identifier, so dates and calendar identity are part of the key rather than deduplicating
/// by `eventIdentifier` alone.
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
