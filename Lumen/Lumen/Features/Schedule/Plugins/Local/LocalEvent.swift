import Foundation

/// 사용자가 캘린더의 빈 날짜를 더블클릭해 직접 적는 일정. 날짜 단위이고 디스크에 저장된다.
nonisolated struct LocalEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var start: Date
    /// nil이면 하루짜리.
    var end: Date?

    init(id: UUID = UUID(), title: String, start: Date, end: Date? = nil) {
        self.id = id
        self.title = title
        self.start = start
        // 종료일을 고른 뒤 시작일을 그 뒤로 옮기면 끝이 시작보다 앞선다. 그런 끝은 버리고 하루짜리로 둔다.
        self.end = end.flatMap { $0 > start ? $0 : nil }
    }
}
