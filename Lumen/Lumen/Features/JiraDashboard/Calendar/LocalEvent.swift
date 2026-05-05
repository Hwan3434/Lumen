import Foundation
import SwiftUI

// 사용자가 캘린더 좌측 사이드바에서 직접 추가하는 로컬 이벤트.
// Jira와 무관하게 디스크에 저장되고 월간 탭에서만 막대로 표시된다 (타임라인 X).

struct LocalEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var start: Date
    /// nil이면 단일 일자(start만 표시).
    var end: Date?
    /// 짧은 메모 — 1차에선 입력 UI 없음, 추후 확장용.
    var note: String?

    init(id: UUID = UUID(), title: String, start: Date, end: Date? = nil, note: String? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.note = note
    }
}

// MARK: - Store

@Observable
final class LocalEventStore {
    static let shared = LocalEventStore()

    private(set) var events: [LocalEvent] = []

    private init() {
        events = LumenStorage.read([LocalEvent].self, from: .localEvents) ?? []
    }

    // MARK: - CRUD

    func add(_ event: LocalEvent) {
        events.append(event)
        sortAndSave()
    }

    func update(_ event: LocalEvent) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[idx] = event
        sortAndSave()
    }

    func delete(id: UUID) {
        events.removeAll { $0.id == id }
        save()
    }

    private func sortAndSave() {
        events.sort { $0.start < $1.start }
        save()
    }

    private func save() {
        LumenStorage.write(events, to: .localEvents)
    }
}
