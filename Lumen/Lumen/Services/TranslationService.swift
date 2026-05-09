import Foundation

struct TranslationResult {
    let translation: String
    let pronunciation: String?
    let inputPronunciation: String?
}

protocol TranslationService {
    static var isAvailable: Bool { get }
    var providerName: String { get }
    func translate(_ text: String, includePronunciation: Bool) async throws -> TranslationResult
}
