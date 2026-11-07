/// 캘린더의 두 보기. 헤더의 세그먼트와 ⌘1/⌘2로 바꾼다.
nonisolated enum CalendarMode: String, Codable, CaseIterable, Identifiable {
    case month, week

    var id: String { rawValue }

    var label: String {
        switch self {
        case .month: return "월간"
        case .week:  return "주간"
        }
    }

    var iconName: String {
        switch self {
        case .month: return "calendar"
        case .week:  return "calendar-range"
        }
    }
}
