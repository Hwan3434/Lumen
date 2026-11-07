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
        self.end = end
    }
}
