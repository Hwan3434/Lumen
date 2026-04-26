import Foundation
import Observation

@Observable
final class NoteViewModel {
    enum SaveStatus { case resting, editing, saved }

    var text = ""
    var isPreview = false
    var saveStatus: SaveStatus = .resting

    private var saveWorkItem: DispatchWorkItem?
    private var savedFlashWorkItem: DispatchWorkItem?

    private let savePath: URL = LumenStorage.url(for: .note)

    init() {
        loadFromDisk()
    }

    func onTextChanged() {
        saveStatus = .editing
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.saveToDisk()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    func togglePreview() {
        isPreview.toggle()
    }

    private func saveToDisk() {
        try? text.write(to: savePath, atomically: true, encoding: .utf8)
        saveStatus = .saved

        // "저장됨" 상태를 잠깐 보여주고 "자동 저장(휴식)"으로 돌아감
        savedFlashWorkItem?.cancel()
        let flash = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.saveStatus == .saved { self.saveStatus = .resting }
        }
        savedFlashWorkItem = flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: flash)
    }

    private func loadFromDisk() {
        if let content = try? String(contentsOf: savePath, encoding: .utf8) {
            text = content
            saveStatus = .resting
        }
    }
}
