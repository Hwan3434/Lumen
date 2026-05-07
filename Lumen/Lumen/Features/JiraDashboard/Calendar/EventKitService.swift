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

        let disabled = CredentialsStore.shared.iCalDisabledCalendarIDs
        let calendars = store.calendars(for: .event).filter {
            !disabled.contains($0.calendarIdentifier)
        }
        guard !calendars.isEmpty else {
            events = []
            return
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        events = store.events(matching: predicate)
    }

    /// 사용 가능 캘린더 목록. UI 토글 표시용 — 휴일 포함 모든 캘린더 노출, 사용자가 직접 OFF.
    func availableCalendars() -> [EKCalendar] {
        guard authorizationStatus == .fullAccess else { return [] }
        return store.calendars(for: .event)
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// disabled ID 집합을 통째로 갱신하고 즉시 events를 재계산.
    /// UI에서 토글 변경 시 호출 — @Observable이라 events 바인딩된 뷰는 자동 재렌더.
    func setDisabledCalendarIDs(_ ids: Set<String>) {
        CredentialsStore.shared.setICalDisabledCalendarIDs(ids)
        fetch()
    }

}
