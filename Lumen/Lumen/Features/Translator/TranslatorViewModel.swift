import AppKit
import Observation

struct TranslationHistoryItem: Identifiable {
    let id: UUID
    let original: String
    let translated: String
    let pronunciation: String?
    let inputPronunciation: String?
    let date: Date

    init(id: UUID = UUID(), original: String, translated: String, pronunciation: String? = nil, inputPronunciation: String? = nil, date: Date) {
        self.id = id
        self.original = original
        self.translated = translated
        self.pronunciation = pronunciation
        self.inputPronunciation = inputPronunciation
        self.date = date
    }
}

@Observable
final class TranslatorViewModel {
    var inputText = ""
    var translatedText = ""
    var pronunciationText: String?
    var inputPronunciationText: String?
    var isLoading = false
    var errorMessage: String?
    var history: [TranslationHistoryItem] = []
    var selectedHistoryIndex: Int = -1

    var inputExceedsLimit: Bool { inputText.count > 200 }

    var showPronunciation: Bool {
        guard let pron = pronunciationText, !pron.isEmpty else { return false }
        return !inputExceedsLimit
    }

    var showInputPronunciation: Bool {
        guard let pron = inputPronunciationText, !pron.isEmpty else { return false }
        return !inputExceedsLimit
    }

    var showNotice: Bool {
        !translatedText.isEmpty && inputExceedsLimit
    }

    private let service = OpenAIService()
    private let maxHistory = 30
    private let savePath: URL
    private var currentTask: Task<Void, Never>?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Lumen")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        savePath = dir.appendingPathComponent("translation_history.json")
        loadFromDisk()
    }

    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        let needsPronunciation = text.count <= 200

        currentTask?.cancel()
        currentTask = Task {
            do {
                let result = try await service.translate(text, includePronunciation: needsPronunciation)
                guard !Task.isCancelled else { return }
                self.translatedText = result.translation
                self.pronunciationText = result.pronunciation
                self.inputPronunciationText = result.inputPronunciation
                self.history.insert(
                    TranslationHistoryItem(
                        original: text,
                        translated: result.translation,
                        pronunciation: result.pronunciation,
                        inputPronunciation: result.inputPronunciation,
                        date: Date()
                    ),
                    at: 0
                )
                if self.history.count > self.maxHistory {
                    self.history = Array(self.history.prefix(self.maxHistory))
                }
                self.selectedHistoryIndex = 0
                self.saveToDisk()
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    func moveUp() {
        if selectedHistoryIndex > 0 { selectHistory(at: selectedHistoryIndex - 1) }
    }

    func moveDown() {
        if selectedHistoryIndex < history.count - 1 { selectHistory(at: selectedHistoryIndex + 1) }
    }

    func selectHistory(at index: Int) {
        guard let item = history[safe: index] else { return }
        selectedHistoryIndex = index
        inputText = item.original
        translatedText = item.translated
        pronunciationText = item.pronunciation
        inputPronunciationText = item.inputPronunciation
    }

    func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
    }

    // MARK: - 영속성

    private struct SavedItem: Codable {
        let id: String
        let original: String
        let translated: String
        let pronunciation: String?
        let inputPronunciation: String?
        let date: Date
    }

    private func saveToDisk() {
        let items = history.map {
            SavedItem(id: $0.id.uuidString, original: $0.original, translated: $0.translated, pronunciation: $0.pronunciation, inputPronunciation: $0.inputPronunciation, date: $0.date)
        }
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: savePath)
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: savePath),
              let items = try? JSONDecoder().decode([SavedItem].self, from: data) else { return }
        history = items.map {
            TranslationHistoryItem(id: UUID(uuidString: $0.id) ?? UUID(), original: $0.original, translated: $0.translated, pronunciation: $0.pronunciation, inputPronunciation: $0.inputPronunciation, date: $0.date)
        }
    }

    func copyPronunciation() {
        guard let pron = pronunciationText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pron, forType: .string)
    }

    func copyInputPronunciation() {
        guard let pron = inputPronunciationText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pron, forType: .string)
    }
}
