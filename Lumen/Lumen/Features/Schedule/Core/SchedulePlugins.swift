/// 플러그인 등록 목록. 순서가 곧 칩 순서이고 색 순서다.
/// 새 플러그인은 `Plugins/<이름>/` 폴더에 구현을 두고 여기에 한 줄 더한다.
enum SchedulePlugins {
    static let all: [any SchedulePlugin] = [
        CalendarPlugin.shared,
        JiraPlugin.shared,
        LocalPlugin.shared,
    ]

    static func plugin(_ id: SchedulePluginID) -> (any SchedulePlugin)? {
        all.first { $0.id == id }
    }
}
