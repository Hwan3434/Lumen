import AppKit
import Observation

enum SearchResultItem: Identifiable {
    case app(AppItem)
    case feature(BuiltInFeature)
    case calculation(expression: String, result: String)
    case currency(input: String, result: String, copyValue: String)

    var id: String {
        switch self {
        case .app(let item): return "app_\(item.id)"
        case .feature(let f): return "feature_\(f.name)"
        case .calculation(let expr, _): return "calc_\(expr)"
        case .currency(let input, _, _): return "fx_\(input)"
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
        AppResourceMonitor.trace("SearchVM:loadApps:enter")
        allApps = appIndexer.loadApps()
        updateResults()
        AppResourceMonitor.trace("SearchVM:loadApps:exit(\(allApps.count))")
    }

    private func updateResults() {
        var items: [SearchResultItem] = []
        let q = query.lowercased()

        let matchedApps: [AppItem]
        if q.isEmpty {
            matchedApps = allApps
        } else {
            matchedApps = allApps.filter { app in
                if app.name.lowercased().contains(q) { return true }
                return app.aliases.contains { $0.lowercased().contains(q) }
            }
        }

        let sorted = matchedApps.sorted { a, b in
            let aCount = usageTracker.usageCount(for: a.id)
            let bCount = usageTracker.usageCount(for: b.id)
            if aCount != bCount { return aCount > bCount }

            if !q.isEmpty {
                let aPrefix = a.name.lowercased().hasPrefix(q)
                    || a.aliases.contains { $0.lowercased().hasPrefix(q) }
                let bPrefix = b.name.lowercased().hasPrefix(q)
                    || b.aliases.contains { $0.lowercased().hasPrefix(q) }
                if aPrefix != bPrefix { return aPrefix }
            }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        if let calcResult = evaluate(query) {
            items.append(.calculation(expression: query, result: calcResult))
        }

        if let fx = convertCurrency(query) {
            items.append(fx)
        }

        let matchedFeatures = FeatureRegistry.shared.search(query: query)
        features = matchedFeatures

        let featureNames = Set(matchedFeatures.map { $0.name.lowercased() })
        let hiddenApps = HiddenAppsManager.shared
        let filteredApps = sorted.filter {
            !featureNames.contains($0.name.lowercased()) && !hiddenApps.isHidden($0.id)
        }
        items.append(contentsOf: filteredApps.map { .app($0) })

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
            AppResourceMonitor.trace("SearchVM:launchApp:enter(\(appItem.name))")
            usageTracker.recordUsage(for: appItem.id)
            AppResourceMonitor.trace("SearchVM:launchApp:beforeOpen")
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: appItem.path, configuration: config) { _, _ in
                AppResourceMonitor.trace("SearchVM:launchApp:openCompletion(\(appItem.name))")
            }
            AppResourceMonitor.trace("SearchVM:launchApp:afterOpen")
            onDismiss(false)
        case .feature:
            break
        case .calculation(_, let result):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
            onDismiss(true)
        case .currency(_, _, let copyValue):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(copyValue, forType: .string)
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

    /// "100 usd", "5만원" 같은 입력을 환산 결과 행으로. 캐시된 환율이 없으면 nil.
    private func convertCurrency(_ query: String) -> SearchResultItem? {
        guard let match = CurrencyQuery.parse(query),
              let converted = CurrencyService.shared.convert(amount: match.amount,
                                                             from: match.from,
                                                             to: match.to) else { return nil }

        let inputLabel  = "\(formatCurrency(match.amount, code: match.from)) \(match.from)"
        let resultLabel = "\(formatCurrency(converted, code: match.to)) \(match.to)"
        let copyValue   = formatCurrency(converted, code: match.to)
        return .currency(input: inputLabel, result: resultLabel, copyValue: copyValue)
    }

    /// KRW/JPY는 정수, 그 외는 소수점 2자리. 천단위 콤마.
    private func formatCurrency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        if code == "KRW" || code == "JPY" {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 0
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
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
