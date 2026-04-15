import AppKit
import Observation

enum SearchResultItem: Identifiable {
    case app(AppItem)
    case feature(BuiltInFeature)
    case calculation(expression: String, result: String)

    var id: String {
        switch self {
        case .app(let item): return "app_\(item.id)"
        case .feature(let f): return "feature_\(f.name)"
        case .calculation(let expr, _): return "calc_\(expr)"
        }
    }

}

@Observable
final class SearchViewModel {
    var query = "" {
        didSet { updateResults() }
    }
    var features: [BuiltInFeature] = []
    var results: [SearchResultItem] = []
    var selectedIndex = 0

    private let appIndexer = AppIndexer()
    private let usageTracker = UsageTracker()
    private var allApps: [AppItem] = []

    func loadApps() {
        allApps = appIndexer.loadApps()
        updateResults()
    }

    private func updateResults() {
        var items: [SearchResultItem] = []
        let q = query.lowercased()

        let matchedApps: [AppItem]
        if q.isEmpty {
            matchedApps = allApps
        } else {
            matchedApps = allApps.filter { $0.name.lowercased().contains(q) }
        }

        let sorted = matchedApps.sorted { a, b in
            let aCount = usageTracker.usageCount(for: a.id)
            let bCount = usageTracker.usageCount(for: b.id)
            if aCount != bCount { return aCount > bCount }

            if !q.isEmpty {
                let aPrefix = a.name.lowercased().hasPrefix(q)
                let bPrefix = b.name.lowercased().hasPrefix(q)
                if aPrefix != bPrefix { return aPrefix }
            }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        if let calcResult = evaluate(query) {
            items.append(.calculation(expression: query, result: calcResult))
        }

        let matchedFeatures = FeatureRegistry.shared.search(query: query)
        features = matchedFeatures

        let featureNames = Set(matchedFeatures.map { $0.name.lowercased() })
        let hiddenApps = HiddenAppsManager.shared
        let filteredApps = sorted.filter {
            !featureNames.contains($0.name.lowercased()) && !hiddenApps.isHidden($0.id)
        }
        items.append(contentsOf: filteredApps.map { .app($0) })

        // results에서 feature 제거 (카드로 별도 표시)
        items.removeAll { if case .feature = $0 { return true }; return false }

        results = items
        selectedIndex = 0
    }

    func moveUp() {
        if selectedIndex > 0 { selectedIndex -= 1 }
    }

    func moveDown() {
        if selectedIndex < results.count - 1 { selectedIndex += 1 }
    }

    func executeSelected(onDismiss: @escaping (_ activatePreviousApp: Bool) -> Void) {
        guard selectedIndex < results.count else { return }
        let item = results[selectedIndex]
        switch item {
        case .app(let appItem):
            usageTracker.recordUsage(for: appItem.id)
            NSWorkspace.shared.open(appItem.path)
            onDismiss(false)
        case .feature:
            break
        case .calculation(_, let result):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
            onDismiss(true)
        }
    }

    func hideApp(_ appID: String) {
        HiddenAppsManager.shared.hide(appID)
        updateResults()
    }

    func reset() {
        query = ""
        selectedIndex = 0
        if allApps.isEmpty { loadApps() }
    }

    private func evaluate(_ expression: String) -> String? {
        let cleaned = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: "")
        guard cleaned.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789.+-*/() ").inverted) == nil,
              cleaned.rangeOfCharacter(from: .decimalDigits) != nil,
              cleaned.rangeOfCharacter(from: CharacterSet(charactersIn: "+-*/")) != nil else { return nil }
        guard let expr = try? NSExpression(format: cleaned),
              let result = expr.expressionValue(with: nil, context: nil) as? NSNumber else { return nil }
        let doubleVal = result.doubleValue
        if doubleVal == doubleVal.rounded() && abs(doubleVal) < 1e15 {
            return String(format: "%.0f", doubleVal)
        }
        return String(doubleVal)
    }
}
