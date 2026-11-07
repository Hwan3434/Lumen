import AppKit
import CoreServices
import Observation

enum SearchResultItem: Identifiable {
    case app(AppItem)
    case calculation(expression: String, result: String)
    case currency(input: String, result: String, copyValue: String)
    case feature(BuiltInFeature)

    var id: String {
        switch self {
        case .app(let item): return "app_\(item.id)"
        case .calculation(let expr, _): return "calc_\(expr)"
        case .currency(let input, _, _): return "fx_\(input)"
        case .feature(let feature): return "feature_\(ObjectIdentifier(feature).hashValue)"
        }
    }

    /// 목록 묶음 이름. 이웃한 항목과 다르면 묶음 머리를 그린다.
    var groupLabel: String {
        switch self {
        case .app: return "앱"
        case .calculation: return "계산"
        case .currency: return "환율"
        case .feature: return "기능"
        }
    }
}

/// 상세 칸에 보여 줄 앱 정보. 항목을 선택했을 때만 읽는다.
struct AppDetail {
    let version: String?
    let lastUsed: Date?
}

@Observable
@MainActor
final class SearchViewModel {
    var query = "" {
        didSet { updateResults() }
    }
    var results: [SearchResultItem] = []
    var selectedIndex = 0

    private let appIndexer = AppIndexer()
    private let usageTracker = UsageTracker.shared
    private var allApps: [AppItem] = []
    @ObservationIgnored private var appDetails: [String: AppDetail] = [:]

    var selectedItem: SearchResultItem? { results[safe: selectedIndex] }

    func loadApps() {
        AppResourceMonitor.trace("SearchVM:loadApps:enter")
        allApps = appIndexer.loadApps()
        updateResults()
        // 앱 설치·삭제 시 다시 읽어 열려 있는 검색창에도 반영한다.
        appIndexer.startWatching { [weak self] in self?.loadApps() }
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

        if let calcResult = ArithmeticEvaluator.evaluate(query) {
            items.append(.calculation(expression: query, result: calcResult))
        }

        if let fx = convertCurrency(query) {
            items.append(fx)
        }

        let matchedFeatures = FeatureRegistry.shared.search(query: query)

        let featureNames = Set(matchedFeatures.map { $0.name.lowercased() })
        let hiddenApps = HiddenAppsManager.shared
        let filteredApps = sorted.filter {
            !featureNames.contains($0.name.lowercased()) && !hiddenApps.isHidden($0.id)
        }
        // 빈 입력에서는 앱이 전부 나오므로 기능을 앞에 둬야 보인다. 입력 중에는 찾던 앱이 먼저다.
        let appItems = filteredApps.map { SearchResultItem.app($0) }
        let featureItems = matchedFeatures.map { SearchResultItem.feature($0) }
        items.append(contentsOf: q.isEmpty ? featureItems + appItems : appItems + featureItems)

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
        case .calculation(_, let result):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
            onDismiss(true)
        case .currency(_, _, let copyValue):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(copyValue, forType: .string)
            onDismiss(true)
        case .feature(let feature):
            activate(feature, onDismiss: onDismiss)
        }
    }

    /// 켜고 끄기형은 창을 그대로 두어 스위치가 바뀌는 걸 보여 준다.
    /// 창을 여는 기능은 검색창을 먼저 닫는다 — 다른 패널이 뜨면서 서로 가리지 않게.
    func activate(_ feature: BuiltInFeature, onDismiss: (_ activatePreviousApp: Bool) -> Void) {
        if feature is ToggleableFeature {
            feature.activate()
        } else {
            onDismiss(true)
            feature.activate()
        }
    }

    /// 버전과 마지막 실행 시각. 처음 선택할 때 한 번 읽고 기억한다.
    func detail(for app: AppItem) -> AppDetail {
        if let cached = appDetails[app.id] { return cached }
        // Bundle(url:)은 번들을 프로세스 끝까지 붙잡아 두므로 Info.plist만 읽는다.
        let info = NSDictionary(contentsOf: app.path.appendingPathComponent("Contents/Info.plist"))
        let version = info?["CFBundleShortVersionString"] as? String
        let lastUsed = MDItemCreateWithURL(nil, app.path as CFURL)
            .flatMap { MDItemCopyAttribute($0, kMDItemLastUsedDate) as? Date }
        let detail = AppDetail(version: version, lastUsed: lastUsed)
        appDetails[app.id] = detail
        return detail
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

        let inputLabel  = "\(CurrencyService.format(match.amount, code: match.from)) \(match.from)"
        let resultLabel = "\(CurrencyService.format(converted, code: match.to)) \(match.to)"
        let copyValue   = CurrencyService.format(converted, code: match.to)
        return .currency(input: inputLabel, result: resultLabel, copyValue: copyValue)
    }

}
