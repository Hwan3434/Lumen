import Foundation
import Observation

@Observable
final class ClipboardViewModel {
    var query = "" {
        didSet { selectedIndex = 0 }
    }
    var selectedIndex = 0

    private var manager = ClipboardManager.shared

    /// manager.history를 직접 derive — @Observable이 history 변경을 추적해 패널이 자동 갱신된다.
    var filteredItems: [ClipboardItem] {
        let items = manager.history
        guard !query.isEmpty else { return items }
        let q = query.lowercased()
        // searchKey는 item 생성 시 1회만 계산된 lowercased prefix.
        // 본문 후반부의 단어는 매칭되지 않는다 (의도된 트레이드오프, ClipboardItem.searchKey 참조).
        return items.filter { $0.searchKey.contains(q) }
    }

    func moveUp() {
        if selectedIndex > 0 { selectedIndex -= 1 }
    }

    func moveDown() {
        if selectedIndex < filteredItems.count - 1 { selectedIndex += 1 }
    }

    func selectCurrent() {
        guard let item = filteredItems[safe: selectedIndex] else { return }
        item.copyToPasteboard()
    }

    /// 현재 선택된 항목 삭제. 삭제 후 같은 인덱스 유지 — 다음 항목이 자연스럽게 선택된다.
    func deleteCurrent() {
        guard let item = filteredItems[safe: selectedIndex] else { return }
        delete(item: item)
    }

    func delete(item: ClipboardItem) {
        manager.delete(id: item.id)
        // filteredItems가 줄었으니 인덱스 clamp
        let newCount = filteredItems.count
        if selectedIndex >= newCount {
            selectedIndex = max(0, newCount - 1)
        }
    }

    func deleteAll() {
        manager.deleteAll()
        selectedIndex = 0
    }
}
