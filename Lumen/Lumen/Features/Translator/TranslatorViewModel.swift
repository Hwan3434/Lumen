import AppKit
import Observation
import Translation
import NaturalLanguage

struct TranslationHistoryItem: Identifiable {
    let id: UUID
    let original: String
    let translated: String
    let date: Date
}

@Observable
final class TranslatorViewModel {
    var inputText = ""
    var translatedText = ""
    var isLoading = false
    var errorMessage: String?
    var history: [TranslationHistoryItem] = []
    var selectedHistoryIndex: Int = -1
    /// 패널을 연 시각. 기록의 "N분" 같은 상대 시간을 열 때마다 다시 계산하게 하는 기준이다.
    var shownAt = Date()

    var providerName: String { "Apple" }
    
    // 이 바인딩은 SwiftUI의 .translationTask에 사용됩니다.
    var translationConfig: TranslationSession.Configuration? = nil

    let maxHistory = 30
    private let savePath: URL

    init(savePath: URL = LumenStorage.url(for: .translationHistory)) {
        self.savePath = savePath
        loadFromDisk()
    }

    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        translatedText = ""

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

    /// `.translationTask`가 준 세션으로 번역한다. 보낸 글을 시작할 때 한 번만 읽어,
    /// 기다리는 동안 입력이 바뀌어도 기록에는 실제로 번역한 원문이 남는다.
    func runTranslation(using session: TranslationSession) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let response = try await session.translate(text)
            // 번역을 다시 시작하면 앞선 요청의 작업이 취소된다. 그 결과나 오류는 버리고 새 요청에 맡긴다.
            // 기다리는 사이 기록에서 다른 항목을 골랐으면(isLoading이 꺼짐) 화면은 이미 그 항목이라 덮지 않는다.
            guard !Task.isCancelled, isLoading else { return }
            handleTranslationResult(original: text, translated: response.targetText)
        } catch {
            if Task.isCancelled { return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func handleTranslationResult(original: String, translated: String) {
        translatedText = translated
        isLoading = false
        errorMessage = nil

        history.insert(
            TranslationHistoryItem(id: UUID(), original: original, translated: translated, date: Date()),
            at: 0
        )
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }
        selectedHistoryIndex = 0
        saveToDisk()
    }

    /// ↑ 키. 기록을 옮겼으면 true, 입력 칸이 키를 받아야 하면 false.
    func moveUp() -> Bool {
        guard canNavigateHistory else { return false }
        if selectedHistoryIndex > 0 { selectHistory(at: selectedHistoryIndex - 1) }
        return true
    }

    func moveDown() -> Bool {
        guard canNavigateHistory else { return false }
        if selectedHistoryIndex < history.count - 1 { selectHistory(at: selectedHistoryIndex + 1) }
        return true
    }

    /// 쓰고 있는 글이 있으면 화살표는 입력 칸의 것이다(여러 줄 사이로 커서 옮기기).
    /// 입력이 비었거나 고른 기록 그대로일 때만 기록을 오르내린다 — 아니면 ↓ 한 번에 쓰던 글이 기록으로 바뀐다.
    private var canNavigateHistory: Bool {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return input.isEmpty || input == history[safe: selectedHistoryIndex]?.original
    }

    func selectHistory(at index: Int) {
        guard let item = history[safe: index] else { return }
        selectedHistoryIndex = index
        inputText = item.original
        translatedText = item.translated
        errorMessage = nil
        isLoading = false
    }

    func copyToClipboard() {
        NSPasteboard.general.copy(translatedText)
    }

    // MARK: - 영속성

    private struct SavedItem: Codable {
        let id: String
        let original: String
        let translated: String
        let date: Date
    }

    private func saveToDisk() {
        let items = history.map {
            SavedItem(id: $0.id.uuidString, original: $0.original, translated: $0.translated, date: $0.date)
        }
        LumenStorage.write(items, to: savePath)
    }

    private func loadFromDisk() {
        guard let items = LumenStorage.read([SavedItem].self, from: savePath) else { return }
        history = items.map {
            TranslationHistoryItem(id: UUID(uuidString: $0.id) ?? UUID(), original: $0.original, translated: $0.translated, date: $0.date)
        }
    }
}
