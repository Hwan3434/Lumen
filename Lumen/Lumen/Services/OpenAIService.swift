import Foundation

struct TranslationResult {
    let translation: String
    let pronunciation: String?
    let inputPronunciation: String?
}

final class OpenAIService {
    /// Translator 기능이 살아있는지 — Settings 토글 ON + API Key 채워졌을 때만 true.
    /// TranslatorFeature.isEnabled의 기준점.
    static var isAvailable: Bool {
        let store = CredentialsStore.shared
        return store.isOpenAIEnabled && store.isOpenAIConfigured
    }

    // init 시점에 캡처 — 런타임 키 교체는 재시작 필요. JiraService와 동일 정책.
    private let apiKey: String

    init(apiKey: String = CredentialsStore.shared.openAIAPIKey) {
        self.apiKey = apiKey
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }

    private struct TranslationJSON: Decodable {
        let translation: String
        let pronunciation: String?
        let inputPronunciation: String?

        enum CodingKeys: String, CodingKey {
            case translation
            case pronunciation
            case inputPronunciation = "input_pronunciation"
        }
    }

    func translate(_ text: String, includePronunciation: Bool) async throws -> TranslationResult {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt: String
        if includePronunciation {
            systemPrompt = """
                You are a translator. Translate Korean↔English automatically based on input language. \
                Respond ONLY in JSON with exactly these three keys: {"translation": "...", "pronunciation": "...", "input_pronunciation": "..."} \
                \
                "input_pronunciation" = how the INPUT word SOUNDS, written in the OTHER language's phonetic script: \
                  - English input like "analyze" → write Korean phonetic characters how it sounds: "애널라이즈" \
                  - Korean input like "나비" → write English letters how it sounds: "nabi" \
                \
                "pronunciation" = how the TRANSLATED word SOUNDS, written in the OTHER language's phonetic script: \
                  - Korean translation like "분석하다" → write English letters how it sounds: "bunseokhada" \
                  - English translation like "butterfly" → write Korean phonetic characters how it sounds: "버터플라이"
                """
        } else {
            systemPrompt = """
                You are a translator. If the input is Korean, translate to English. If the input is English, translate to Korean. \
                Respond ONLY in JSON: {"translation": "..."}
                """
        }

        let body: [String: Any] = [
            "model": Constants.openAIModel,
            "temperature": 0.3,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)

        let rawContent = response.choices.first?.message.content ?? ""
        if let jsonData = rawContent.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(TranslationJSON.self, from: jsonData) {
            return TranslationResult(translation: parsed.translation, pronunciation: parsed.pronunciation, inputPronunciation: parsed.inputPronunciation)
        }
        return TranslationResult(translation: rawContent.isEmpty ? "번역 실패" : rawContent, pronunciation: nil, inputPronunciation: nil)
    }
}
