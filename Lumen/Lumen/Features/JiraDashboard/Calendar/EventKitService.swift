import EventKit
import Foundation

// macOS Calendar.app에 연동된 캘린더에서 이벤트를 가져온다.
// 이름에 "휴일" / "holiday"가 포함된 캘린더는 제외한다 — 앱 내장 KoreanHolidays와 중복 방지.

@Observable
final class EventKitService {
    static let shared = EventKitService()

    private let store = EKEventStore()
    private(set) var events: [EKEvent] = []
    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
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

        let calendars = store.calendars(for: .event).filter { !isHolidayCalendar($0) }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        events = store.events(matching: predicate)
    }

    // MARK: - Helpers

    /// 공휴일 캘린더 판별 — 이름에 "휴일" / "holiday" 포함 여부로 판단.
    private func isHolidayCalendar(_ calendar: EKCalendar) -> Bool {
        let title = calendar.title.lowercased()
        return title.contains("휴일") || title.contains("holiday")
    }
}
