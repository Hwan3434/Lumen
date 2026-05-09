import Foundation

final class GoogleAIService: TranslationService {
    static var isAvailable: Bool {
        CredentialsStore.shared.isGoogleAIConfigured
    }

    let providerName = "Google AI"

    private let apiKey: String

    init(apiKey: String = CredentialsStore.shared.googleAIAPIKey) {
        self.apiKey = apiKey
    }

    private struct ChatResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String
                }
                let parts: [Part]
            }
            let content: Content
        }
        let candidates: [Candidate]
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

    private func extractLastJSON(from text: String) -> String {
        // "translation" 키가 포함된 JSON 블록만 추출
        let indices = text.indices.filter { text[$0] == "{" }
        for idx in indices.reversed() {
            var depth = 0
            var result = ""
            for ch in text[idx...] {
                if ch == "{" { depth += 1 }
                else if ch == "}" { depth -= 1 }
                result.append(ch)
                if depth == 0 {
                    if result.contains("\"translation\"") { return result }
                    break
                }
            }
        }
        return text
    }

    func translate(_ text: String, includePronunciation: Bool) async throws -> TranslationResult {
        let model = Constants.googleAIModel
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
                  • If the input is KOREAN → write Revised Romanization in lowercase English letters.
                    - "나비" → "nabi"
                    - "안녕하세요" → "annyeonghaseyo"

                "pronunciation" = how the TRANSLATED text sounds, in the OTHER language's reading script (same rules):
                  • English translation → 한글 외래어 표기 ("butterfly" → "버터플라이")
                  • Korean translation → Revised Romanization ("분석하다" → "bunseokhada")

                Rules:
                  • ALWAYS fill BOTH input_pronunciation and pronunciation. Never leave them empty, never echo the input as-is.
                  • For English source: input_pronunciation MUST be Hangul (한글).
                  • For Korean source: input_pronunciation MUST be lowercase English Revised Romanization.
                  • Length does not matter — apply the same rule to single words and to long sentences.
                """
        } else {
            systemPrompt = """
                You are a translator. If the input is Korean, translate to English. If the input is English, translate to Korean. \
                Respond ONLY in JSON: {"translation": "..."}
                """
        }

        let responseSchema: [String: Any] = includePronunciation ? [
            "type": "OBJECT",
            "properties": [
                "translation":          ["type": "STRING"],
                "input_pronunciation":  ["type": "STRING"],
                "pronunciation":        ["type": "STRING"]
            ],
            "required": ["translation", "input_pronunciation", "pronunciation"]
        ] : [
            "type": "OBJECT",
            "properties": ["translation": ["type": "STRING"]],
            "required": ["translation"]
        ]

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["parts": [["text": text]]]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "responseMimeType": "application/json",
                "responseSchema": responseSchema
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)

        let rawContent = response.candidates.first?.content.parts.first?.text ?? ""
        // Gemma가 thinking 텍스트 뒤에 JSON을 붙이는 경우가 있어 마지막 { } 블록만 추출
        let jsonString = extractLastJSON(from: rawContent)
        if let jsonData = jsonString.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(TranslationJSON.self, from: jsonData) {
            return TranslationResult(translation: parsed.translation, pronunciation: parsed.pronunciation, inputPronunciation: parsed.inputPronunciation)
        }
        return TranslationResult(translation: rawContent.isEmpty ? "번역 실패" : rawContent, pronunciation: nil, inputPronunciation: nil)
    }
}
