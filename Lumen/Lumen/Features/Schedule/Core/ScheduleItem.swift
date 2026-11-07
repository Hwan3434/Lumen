import SwiftUI

/// 일정 출처(플러그인) 식별자. 등록 순서, 설정 키, 캐시 파일 이름에 쓴다.
nonisolated struct SchedulePluginID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }

    static let calendar = SchedulePluginID("calendar")
    static let jira = SchedulePluginID("jira")
    static let local = SchedulePluginID("local")
}

/// 플러그인 안에서 색 하나를 받는 단위. 캘린더 하나, Jira 프로젝트 하나, 내 일정 전체가 각각 묶음이다.
nonisolated struct ScheduleGroup: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var isVisible: Bool
    /// 플러그인이 정한 색(캘린더 앱의 색). nil이면 스토어가 Still 차트 색을 순서대로 배정한다.
    var customColor: Color? = nil
}

nonisolated struct ScheduleGroupKey: Hashable, Sendable {
    let plugin: SchedulePluginID
    let group: String
}

/// 모든 플러그인이 내놓는 일정 한 줄. 캘린더 이벤트, Jira 이슈, 내 일정이 모두 이 모양으로 바뀐다.
/// 플러그인 전용 정보(이슈 설명, 캘린더 메모)는 여기 없다. 상세 뷰를 플러그인이 내주면서 자기 저장소에서 꺼낸다.
nonisolated struct ScheduleItem: Identifiable, Hashable, Codable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable {
        /// 시간을 차지하는 일정(캘린더 이벤트, 내 일정).
        case event
        /// 마감형 일(이슈, 에픽).
        case task
        /// 여러 날에 걸친 기간(스프린트). 캘린더 막대로만 보이고 목록에는 안 나온다.
        case span
    }

    nonisolated enum Status: String, Codable, Sendable { case todo, inProgress, done }
    nonisolated enum Priority: String, Codable, Sendable { case urgent, high }

    /// 플러그인끼리 겹치지 않게 "<플러그인>.<출처 고유 id>" 꼴로 만든다.
    let id: String
    let plugin: SchedulePluginID
    /// 묶음 id. 캘린더 identifier, 프로젝트 키, "local".
    let group: String
    let title: String
    let start: Date
    /// nil이면 한 시점(마감일, 종일 하루).
    let end: Date?
    /// false면 막대 앞에 시각을 붙인다.
    let isAllDay: Bool
    let kind: Kind
    /// 이벤트는 nil.
    var status: Status? = nil
    /// 보통·낮음은 nil.
    var priority: Priority? = nil
    /// "PROJ-142", 캘린더 이름처럼 두 번째 줄에 쓰는 글.
    var subtitle: String? = nil
    var location: String? = nil
    /// 출처에서 열기.
    var url: URL? = nil

    var isDone: Bool { status == .done }
    var hasTimeOfDay: Bool { !isAllDay }
    var groupKey: ScheduleGroupKey { ScheduleGroupKey(plugin: plugin, group: group) }

    /// 이 항목이 주어진 날짜에 걸쳐 있는가. end가 없으면 그 날짜만, 있으면 [start, end]를 날짜 단위로 본다.
    func covers(_ day: Date) -> Bool {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end ?? start)
        return dayStart >= s && dayStart <= e
    }
}
