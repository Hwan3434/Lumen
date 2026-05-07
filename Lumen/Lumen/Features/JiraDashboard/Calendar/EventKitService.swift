import EventKit
import Foundation

// macOS Calendar.app에 연동된 캘린더에서 이벤트를 가져온다.
// 표시 여부는 사용자가 popover 토글로 직접 결정 (블랙리스트 방식 — disabled IDs).
// 휴일 자동 제외는 하지 않는다 — 사용자가 KoreanHolidays와 중복되는 게 싫으면 직접 끈다.

@Observable
final class EventKitService {
    static let shared = EventKitService()

    private let store = EKEventStore()
    private(set) var events: [EKEvent] = []
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
        events = store.events(matching: predicate)
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

}
