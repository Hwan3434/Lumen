import AppKit
import Observation

@Observable
final class ClipboardViewModel {
    var query = "" {
        didSet { selectedIndex = 0 }
    }
    var selectedIndex = 0 {
        didSet { loadPreview() }
    }
    var isLoadingPreview = false
    var previewText: String?
    var previewImage: NSImage?
    var previewMeta: String?
    var previewAppIcon: NSImage?

    private var manager = ClipboardManager.shared
    private var previewWorkItem: DispatchWorkItem?
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fmt
    }()

    /// manager.history를 직접 derive — @Observable이 history 변경을 추적해 패널이 자동 갱신된다.
    var filteredItems: [ClipboardItem] {
        let items = manager.history
        guard !query.isEmpty else { return items }
        let q = query.lowercased()
        // searchKey는 item 생성 시 1회만 계산된 lowercased prefix.
        // 본문 후반부의 단어는 매칭되지 않는다 (의도된 트레이드오프, ClipboardItem.searchKey 참조).
        return items.filter { $0.searchKey.contains(q) }
    }

    init() {}

    var hasPreviewContent: Bool {
        previewText != nil || previewImage != nil || previewMeta != nil
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
        } else {
            // 같은 인덱스를 유지해도 preview는 새 항목 기준으로 갱신돼야 함
            loadPreview()
        }
    }

    func deleteAll() {
        manager.deleteAll()
        selectedIndex = 0
    }

    private func loadPreview() {
        previewWorkItem?.cancel()
        previewText = nil
        previewImage = nil
        previewMeta = nil
        previewAppIcon = nil
        isLoadingPreview = true

        guard let item = filteredItems[safe: selectedIndex] else {
            isLoadingPreview = false
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // 메타 정보 (앱 이름 + 복사 시간)
            var meta = "복사 시간: \(Self.dateFormatter.string(from: item.date))"
            if let app = item.sourceApp {
                meta = "복사한 앱: \(app)\n" + meta
            }
            self.previewMeta = meta
            self.previewAppIcon = item.sourceAppIcon

            if let text = item.text {
                meta += "\n글자 수: \(text.count)자"
                if text.count > 500 {
                    self.previewText = String(text.prefix(500)) + "..."
                    meta += " (500자만 표시)"
                } else {
                    self.previewText = text
                }
                self.previewMeta = meta
            }

            if let urls = item.fileURLs, let url = urls.first {
                meta += "\n경로: \(url.path)"
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                    if let size = attrs[.size] as? Int64 {
                        meta += "\n파일 크기: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
                    }
                    if let date = attrs[.modificationDate] as? Date {
                        meta += "\n수정: \(Self.dateFormatter.string(from: date))"
                    }
                }

                let imageExts = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"]
                if imageExts.contains(url.pathExtension.lowercased()) {
                    if let img = NSImage(contentsOf: url) {
                        self.previewImage = img
                        meta += "\n이미지 크기: \(Int(img.size.width))×\(Int(img.size.height))"
                    }
                }
            }

            if let img = item.resolvedImage {
                self.previewImage = img
                meta += "\n이미지 크기: \(Int(img.size.width))×\(Int(img.size.height))"
            }

            self.previewMeta = meta

            self.isLoadingPreview = false
        }

        previewWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
}
