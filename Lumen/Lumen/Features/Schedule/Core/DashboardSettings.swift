import Foundation
import Observation

/// 플러그인에 속하지 않는 대시보드 공통 설정.
nonisolated struct DashboardSettings: Codable, Equatable {
    nonisolated enum Weekday: String, Codable, CaseIterable {
        case sunday, monday

        /// `Calendar.firstWeekday` 값.
        var calendarValue: Int {
            switch self {
            case .sunday: return 1
            case .monday: return 2
            }
        }

        var label: String {
            switch self {
            case .sunday: return "일요일"
            case .monday: return "월요일"
            }
        }
    }

    /// 메뉴바 오른쪽 위의 다음 일정 라벨.
    var menuBarLabel = true
    var defaultView: CalendarMode = .month
    var weekStartsOn: Weekday = .sunday
}

@Observable
@MainActor
final class DashboardSettingsStore {
    static let shared = DashboardSettingsStore()
    private static let key = "schedule.dashboard"

    var settings: DashboardSettings {
        didSet { PluginSettings.save(settings, key: Self.key) }
    }

    private init() {
        settings = PluginSettings.load(key: Self.key, default: DashboardSettings())
    }
}
