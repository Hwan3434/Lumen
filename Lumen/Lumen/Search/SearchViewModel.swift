import AppKit
import CoreServices
import Observation

enum SearchResultItem: Identifiable {
    case app(AppItem)
    case calculation(expression: String, result: String)
    /// `ratesUpdated`는 환산에 쓴 환율의 기준 시각. 상세 칸이 서비스를 직접 읽지 않도록 같이 싣는다.
    case currency(input: String, result: String, copyValue: String, ratesUpdated: Date?)
    case feature(BuiltInFeature)

    var id: String {
        switch self {
        case .app(let item): return "app_\(item.id)"
        case .calculation(let expr, _): return "calc_\(expr)"
        case .currency(let input, _, _, _): return "fx_\(input)"
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
    private(set) var results: [SearchResultItem] = []
    /// 선택은 위치가 아니라 항목 id로 기억한다. 목록이 다시 만들어져도(앱 숨기기, 앱 설치, 환율 갱신)
    /// 보고 있던 항목이 그대로 선택돼 있도록.
    private(set) var selectedID: String?
    /// 선택한 항목이 앱일 때의 상세 정보. 선택이 바뀔 때 뷰모델이 읽어 두고 뷰는 그리기만 한다.
    private(set) var selectedAppDetail: AppDetail?

    private let appIndexer = AppIndexer()
    private let usageTracker = UsageTracker.shared
    private var allApps: [AppItem] = []
    @ObservationIgnored private var appDetails: [String: AppDetail] = [:]

    private var selectedIndex: Int { results.firstIndex { $0.id == selectedID } ?? 0 }
    var selectedItem: SearchResultItem? { results[safe: selectedIndex] }

    init() {
        // 환율을 새로 받으면 열려 있는 검색창의 환산 결과와 기준 시각을 다시 만든다.
        CurrencyService.shared.onUpdate = { [weak self] in self?.updateResults(keepSelection: true) }
    }

    func loadApps() {
        MemoryTrace.record("SearchVM:loadApps:enter")
        allApps = appIndexer.loadApps()
        updateResults(keepSelection: true)
        // 앱 설치·삭제 시 다시 읽어 열려 있는 검색창에도 반영한다.
        appIndexer.startWatching { [weak self] in self?.loadApps() }
        MemoryTrace.record("SearchVM:loadApps:exit(\(allApps.count))")
    }

    /// 검색어에 맞는 앱을 골라 순서를 매긴다: 검색어로 시작하는 이름·별명 먼저 → 실행 횟수 많은 순 → 이름순.
    /// 앞부분 일치가 먼저인 이유: "no"를 치면 별명 중간에 "no"가 든 자주 쓰는 앱보다 Notes가 위에 와야 한다.
    static func rankedApps(_ apps: [AppItem], query: String, usageCount: (String) -> Int) -> [AppItem] {
        let q = query.lowercased()
        guard !q.isEmpty else {
            return apps.sorted { a, b in
                let aCount = usageCount(a.id), bCount = usageCount(b.id)
                if aCount != bCount { return aCount > bCount }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }

        // 비교할 때마다 소문자로 바꾸지 않도록 한 번만 계산한다.
        let scored: [(app: AppItem, prefix: Bool, count: Int)] = apps.compactMap { app in
            let names = [app.name.lowercased()] + app.aliases.map { $0.lowercased() }
            guard names.contains(where: { $0.contains(q) }) else { return nil }
            return (app, names.contains { $0.hasPrefix(q) }, usageCount(app.id))
        }

        return scored.sorted { a, b in
            if a.prefix != b.prefix { return a.prefix }
            if a.count != b.count { return a.count > b.count }
            return a.app.name.localizedCaseInsensitiveCompare(b.app.name) == .orderedAscending
        }.map(\.app)
    }

    /// `keepSelection`이 false면 맨 위 항목을 고른다(검색어가 바뀐 경우).
    /// true면 고르고 있던 항목을 유지하고, 그 항목이 사라졌으면 같은 자리의 항목을 고른다.
    private func updateResults(keepSelection: Bool = false) {
        var items: [SearchResultItem] = []
        let q = query.lowercased()
        let previousIndex = selectedIndex

        let sorted = Self.rankedApps(allApps, query: query, usageCount: usageTracker.usageCount(for:))

        if let calcResult = ArithmeticEvaluator.evaluate(query) {
            items.append(.calculation(expression: query, result: calcResult))
        }

        if let fx = convertCurrency(query) {
            items.append(fx)
        }

        let matchedFeatures = FeatureRegistry.shared.search(query: query)

        let featureNames = Set(matchedFeatures.map { $0.name.lowercased() })
        let hiddenApps = HiddenAppsStore.shared
        let filteredApps = sorted.filter {
            !featureNames.contains($0.name.lowercased()) && !hiddenApps.isHidden($0.id)
        }
        // 빈 입력에서는 앱이 전부 나오므로 기능을 앞에 둬야 보인다. 입력 중에는 찾던 앱이 먼저다.
        let appItems = filteredApps.map { SearchResultItem.app($0) }
        let featureItems = matchedFeatures.map { SearchResultItem.feature($0) }
        items.append(contentsOf: q.isEmpty ? featureItems + appItems : appItems + featureItems)

        results = items
        if !keepSelection {
            selectedID = items.first?.id
        } else if !items.contains(where: { $0.id == selectedID }) {
            selectedID = (items[safe: previousIndex] ?? items.last)?.id
        }
        refreshSelectedAppDetail()
    }

    func select(_ item: SearchResultItem) {
        selectedID = item.id
        refreshSelectedAppDetail()
    }

    func moveUp() { moveSelection(by: -1) }
    func moveDown() { moveSelection(by: 1) }

    private func moveSelection(by offset: Int) {
        guard let next = results[safe: selectedIndex + offset] else { return }
        select(next)
    }

    func executeSelected(onDismiss: @escaping (_ activatePreviousApp: Bool) -> Void) {
        guard let item = selectedItem else { return }
        switch item {
        case .app(let appItem):
            MemoryTrace.record("SearchVM:launchApp:enter(\(appItem.name))")
            usageTracker.recordUsage(for: appItem.id)
            MemoryTrace.record("SearchVM:launchApp:beforeOpen")
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: appItem.path, configuration: config) { _, _ in
                MemoryTrace.record("SearchVM:launchApp:openCompletion(\(appItem.name))")
            }
            MemoryTrace.record("SearchVM:launchApp:afterOpen")
            onDismiss(false)
        case .calculation(_, let copyValue), .currency(_, _, let copyValue, _):
            NSPasteboard.general.copy(copyValue)
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

    private func refreshSelectedAppDetail() {
        if case .app(let app) = selectedItem {
            selectedAppDetail = detail(for: app)
        } else {
            selectedAppDetail = nil
        }
    }

    /// 버전과 마지막 실행 시각. 검색창을 한 번 여는 동안에는 앱마다 한 번만 읽는다(`reset()`이 비운다).
    private func detail(for app: AppItem) -> AppDetail {
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
        HiddenAppsStore.shared.hide(appID)
        updateResults(keepSelection: true)
    }

    /// 검색창을 열 때마다 부른다. 몇 주씩 떠 있는 앱이라 지난번에 읽은 "마지막 실행"·버전은 버리고 다시 읽는다.
    func reset() {
        appDetails = [:]
        query = ""
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
        return .currency(input: inputLabel, result: resultLabel, copyValue: copyValue,
                         ratesUpdated: CurrencyService.shared.lastUpdated)
    }
}
