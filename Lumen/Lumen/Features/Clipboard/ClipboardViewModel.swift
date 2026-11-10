import Foundation
import Observation

@Observable
final class ClipboardViewModel {
    var query = "" {
        didSet { selectedID = filteredItems.first?.id }
    }

    /// 선택은 위치가 아니라 항목 id로 기억한다 — 패널이 열려 있는 동안 새 복사가 맨 위에 끼어들어도
    /// 보고 있던 항목이 그대로 선택돼 있도록.
    private var selectedID: UUID?
    /// 패널이 내려가 있는 동안에는 미리보기를 만들지 않는다. 숨은 패널이 맨 위 항목의 이미지를 붙잡고 있지 않도록.
    private var isPanelVisible = true
    @ObservationIgnored private var cachedPreview: ClipboardPreviewModel?

    private var store = ClipboardStore.shared

    /// store.history를 직접 derive — @Observable이 history 변경을 추적해 패널이 자동 갱신된다.
    var filteredItems: [ClipboardItem] {
        let items = store.history
        guard !query.isEmpty else { return items }
        let q = query.lowercased()
        // searchKey는 item 생성 시 1회만 계산된 lowercased prefix.
        // 본문 후반부의 단어는 매칭되지 않는다 (의도된 트레이드오프, ClipboardItem.searchKey 참조).
        return items.filter { $0.searchKey.contains(q) }
    }

    /// 기억한 항목이 목록에서 사라졌으면(삭제, 검색어 변경, 같은 글을 다시 복사) 맨 위 항목.
    var selectedItem: ClipboardItem? {
        let items = filteredItems
        return items.first { $0.id == selectedID } ?? items.first
    }

    /// 선택한 항목의 미리보기. 항목마다 한 번만 만든다(파일 정보 읽기, 이미지 열기).
    var preview: ClipboardPreviewModel? {
        guard isPanelVisible, let item = selectedItem else { return nil }
        if let cached = cachedPreview, cached.id == item.id { return cached }
        let built = ClipboardPreviewModel(item: item)
        cachedPreview = built
        return built
    }

    var isHistoryEmpty: Bool { store.history.isEmpty }

    /// 머리줄 숫자. 평소에는 "기록 수 / 최대", 검색 중에는 "찾은 수 / 기록 수".
    var countLabel: String {
        let total = store.history.count
        return query.isEmpty ? "\(total) / \(store.maxItems)" : "\(filteredItems.count) / \(total)"
    }

    // MARK: - 패널 열고 닫기

    func panelWillShow() {
        isPanelVisible = true
        selectedID = filteredItems.first?.id
    }

    func panelDidHide() {
        isPanelVisible = false
        cachedPreview = nil
        query = ""
    }

    // MARK: - 선택

    func select(_ item: ClipboardItem) {
        selectedID = item.id
    }

    func moveUp() { moveSelection(by: -1) }
    func moveDown() { moveSelection(by: 1) }

    private func moveSelection(by offset: Int) {
        let items = filteredItems
        guard let current = selectedItem, let index = items.firstIndex(of: current),
              let next = items[safe: index + offset] else { return }
        selectedID = next.id
    }

    func copySelected() {
        guard let item = selectedItem else { return }
        store.copyToPasteboard(item)
    }

    // MARK: - 삭제

    func deleteSelected() {
        guard let item = selectedItem else { return }
        delete(item: item)
    }

    /// 선택한 항목을 지웠으면 같은 자리의 다음 항목을 고른다. 다른 항목을 지웠으면 선택은 그대로다.
    func delete(item: ClipboardItem) {
        let index = item == selectedItem ? filteredItems.firstIndex(of: item) : nil
        store.delete(id: item.id)
        if let index {
            let rest = filteredItems
            selectedID = (rest[safe: index] ?? rest.last)?.id
        }
    }

    func deleteAll() {
        store.deleteAll()
        selectedID = nil
    }
}
