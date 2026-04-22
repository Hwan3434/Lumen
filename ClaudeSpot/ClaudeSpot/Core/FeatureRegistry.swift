final class FeatureRegistry {
    static let shared = FeatureRegistry()
    private var features: [BuiltInFeature] = []

    func register(_ feature: BuiltInFeature) {
        // 비활성 feature는 append·setup을 모두 스킵한다.
        // → 검색 목록·핫키 등록·리소스 할당이 일체 발생하지 않아 완전히 격리된다.
        guard feature.isEnabled else { return }
        features.append(feature)
        feature.setup()
    }

    // register() 단계에서 isEnabled 기준으로 이미 걸러지므로 여기선 재필터 불필요.
    var enabledFeatures: [BuiltInFeature] { features }

    func search(query: String) -> [BuiltInFeature] {
        guard !query.isEmpty else { return enabledFeatures.filter { $0.showInDefaultList } }
        let q = query.lowercased()
        return enabledFeatures.filter { feature in
            feature.name.lowercased().contains(q) ||
            feature.searchKeywords.contains(where: { $0.lowercased().contains(q) })
        }
    }

    func teardownAll() {
        features.forEach { $0.teardown() }
    }
}
