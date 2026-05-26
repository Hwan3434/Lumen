import Foundation

final class OpenAIService: TranslationService {
    static var isAvailable: Bool {
        CredentialsStore.shared.isOpenAIConfigured
    }

    let providerName = "OpenAI"

    // init 시점에 캡처 — 런타임 키 교체는 재시작 필요. JiraService와 동일 정책.
    private var apiKey: String {
        CredentialsStore.shared.openAIAPIKey
    }

    init() {}

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
                You are a translator. The user message contains ONLY the source text — translate Korean↔English automatically based on its language.

                Respond ONLY in JSON with exactly these three keys:
                {"translation": "...", "input_pronunciation": "...", "pronunciation": "..."}

                "input_pronunciation" = how the INPUT sounds, written in the OTHER language's reading script:
                  • If the input is ENGLISH → write Korean Hangul (한글) characters following 외래어 표기법, regardless of length. Always 한글, never IPA, never romanization.
                    - "analyze" → "애널라이즈"
                    - "butterfly" → "버터플라이"
                    - "Hello, my name is John." → "헬로, 마이 네임 이즈 존."
                    - "Antigravity is an agentic, terminal-based coding tool." → "안티그래비티 이즈 언 에이전틱, 터미널 베이스드 코딩 툴."
                  • If the input is KOREAN → write Revised Romanization in lowercase English letters.
                    - "나비" → "nabi"
                    - "안녕하세요" → "annyeonghaseyo"

                "pronunciation" = how the TRANSLATED text sounds, in the OTHER language's reading script (same rules):
                  • English translation → 한글 외래어 표기 ("butterfly" → "버터플라이")
                  • Korean translation → Revised Romanization ("분석하다" → "bunseokhada")

                Rules:
                  • ALWAYS fill BOTH input_pronunciation and pronunciation. Never leave them empty, never echo the input as-is.
                  • For English source: input_pronunciation MUST be Hangul (한글). It MUST NOT be lowercase English. Never output romanization for an English source.
                  • For Korean source: input_pronunciation MUST be lowercase English Revised Romanization. It MUST NOT be Hangul.
                  • Length does not matter — apply the same rule to single words and to long sentences.
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
