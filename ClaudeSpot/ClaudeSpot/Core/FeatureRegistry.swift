final class FeatureRegistry {
    static let shared = FeatureRegistry()
    private var features: [BuiltInFeature] = []

    func register(_ feature: BuiltInFeature) {
        features.append(feature)
        feature.setup()
    }

    var enabledFeatures: [BuiltInFeature] {
        features.filter { $0.isEnabled }
    }

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
