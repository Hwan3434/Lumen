import Foundation
import Observation

@Observable
final class NoteViewModel {
    var text = ""
    var isPreview = false
    private var saveWorkItem: DispatchWorkItem?

    private let savePath: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Lumen")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("note.md")
    }()

    init() {
        loadFromDisk()
    }

    func onTextChanged() {
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
    }

    private func loadFromDisk() {
        if let content = try? String(contentsOf: savePath, encoding: .utf8) {
            text = content
        }
    }
}
