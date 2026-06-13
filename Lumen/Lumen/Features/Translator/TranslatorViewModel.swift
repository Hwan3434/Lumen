import AppKit
import Observation
import Translation
import NaturalLanguage

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

    var inputExceedsLimit: Bool { inputText.count > 100 }

    var providerName: String { "Apple" }
    
    // 이 바인딩은 SwiftUI의 .translationTask에 사용됩니다.
    var translationConfig: TranslationSession.Configuration? = nil

    private let maxHistory = 30
    private let savePath: URL = LumenStorage.url(for: .translationHistory)

    init() {
        loadFromDisk()
    }

    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        translatedText = ""
        pronunciationText = nil
        inputPronunciationText = nil

        let isKorean = detectIsKorean(text)
        let sourceLang = Locale.Language(identifier: isKorean ? "ko" : "en")
        let targetLang = Locale.Language(identifier: isKorean ? "en" : "ko")

        if let currentConfig = translationConfig,
           currentConfig.source == sourceLang,
           currentConfig.target == targetLang {
            translationConfig?.invalidate()
        } else {
            translationConfig = TranslationSession.Configuration(source: sourceLang, target: targetLang)
        }
    }

    private func detectIsKorean(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let dominant = recognizer.dominantLanguage?.rawValue ?? "ko"
        return dominant == "ko"
    }

    @MainActor
    func handleTranslationResult(_ text: String) {
        self.translatedText = text
        self.isLoading = false

        let originalText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.history.insert(
            TranslationHistoryItem(
                original: originalText,
                translated: text,
                date: Date()
            ),
            at: 0
        )
        if self.history.count > self.maxHistory {
            self.history = Array(self.history.prefix(self.maxHistory))
        }
        self.selectedHistoryIndex = 0
        self.saveToDisk()
    }

    @MainActor
    func handleTranslationError(_ error: Error) {
        self.errorMessage = error.localizedDescription
        self.isLoading = false
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
