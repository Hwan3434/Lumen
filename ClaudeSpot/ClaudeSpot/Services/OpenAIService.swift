import Foundation

struct TranslationResult {
    let translation: String
    let pronunciation: String?
}

final class OpenAIService {
    /// API 키가 존재하면 이 Service가 활성화된다.
    /// TranslatorFeature.isEnabled 기준점.
    static var isAvailable: Bool { CredentialsStore.shared.isOpenAIConfigured }

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
                You are a translator. If the input is Korean, translate to English. If the input is English, translate to Korean. \
                Respond in JSON: {"translation": "...", "pronunciation": "..."} \
                pronunciation is the Korean phonetic reading of the English text involved. \
                If the input is English, pronunciation is for the input (e.g., "Exception" → "익셉션"). \
                If the input is Korean, pronunciation is for the English translation (e.g., input "나비" → translation "butterfly" → pronunciation "버터플라이").
                """
        } else {
            systemPrompt = """
                You are a translator. If the input is Korean, translate to English. If the input is English, translate to Korean. \
                Respond in JSON: {"translation": "..."}
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
            return TranslationResult(translation: parsed.translation, pronunciation: parsed.pronunciation)
        }
        return TranslationResult(translation: rawContent.isEmpty ? "번역 실패" : rawContent, pronunciation: nil)
    }
}
