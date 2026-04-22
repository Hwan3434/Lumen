import Foundation

struct DailyUsage: Identifiable {
    var id: String { date }
    let date: String
    let calls: Int
}

struct ProjectUsage: Identifiable {
    var id: String { name }
    let name: String
    let calls: Int
}

struct ModelUsage: Identifiable {
    var id: String { name }
    let name: String
    let calls: Int     // total tokens (input + output + cache write + cache read)
    let cost: Double   // USD
}

struct HeavyUsageData {
    let todayCalls: Int
    let todaySessions: Int
    let monthCalls: Int
    let monthTokens: Int
    let dailyHistory: [DailyUsage]
    let projects: [ProjectUsage]
    let models: [ModelUsage]
}

struct LiveUsageData {
    let sessionPct: Int
    let weeklyPct: Int
    let sessionResetDate: Date?
    let weeklyResetDate: Date?
}

@Observable
final class ClaudeUsageService {
    static let shared = ClaudeUsageService()
    private init() {}

    /// 환경적으로 추적 가능한가 — `~/.claude/projects` 디렉터리 존재 여부.
    /// 앱 실행 동안 디렉터리 생성/삭제가 빈번하지 않으므로 static let으로 1회 평가.
    /// SwiftUI body 재평가마다 stat syscall이 트리거되는 것을 방지.
    static let canTrack: Bool = {
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/projects")
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }()

    /// UsagePanel 노출 여부의 최종 판정.
    /// 환경(`canTrack`)과 사용자 설정(`isClaudeUsageEnabled`)이 모두 참이어야 한다.
    /// 사용자가 Settings에서 off 하면 디렉터리가 있어도 노출하지 않는다.
    static var isAvailable: Bool {
        canTrack && CredentialsStore.shared.isClaudeUsageEnabled
    }

    var heavyData: HeavyUsageData?
    var liveData: LiveUsageData = LiveUsageData(sessionPct: 0, weeklyPct: 0, sessionResetDate: nil, weeklyResetDate: nil)
    var isLoadingHeavy = false
    private var lastHeavyFetch: Date?
    private static let heavyTTL: TimeInterval = 600

    // MARK: - Fetch

    func fetchHeavy(force: Bool = false) async {
        if !force, let last = lastHeavyFetch, Date().timeIntervalSince(last) < Self.heavyTTL, heavyData != nil { return }
        guard !isLoadingHeavy else { return }
        isLoadingHeavy = true

        let result = await background { self.fetchJSONLAggregate() }

        await MainActor.run {
            self.heavyData = result
            self.isLoadingHeavy = false
            self.lastHeavyFetch = Date()
        }
    }

    func fetchLive() async {
        let csv = await background { self.readCSV() }
        await MainActor.run {
            liveData = LiveUsageData(
                sessionPct: csv.sessionPct,
                weeklyPct: csv.weeklyPct,
                sessionResetDate: csv.sessionReset,
                weeklyResetDate: csv.weeklyReset
            )
        }
    }

    private func background<T>(_ work: @escaping () -> T) async -> T {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async { cont.resume(returning: work()) }
        }
    }

    // MARK: - CSV

    private struct CSVResult {
        let sessionPct: Int
        let weeklyPct: Int
        let sessionReset: Date?
        let weeklyReset: Date?
    }

    private func readCSV() -> CSVResult {
        let csvPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("develop/claude_status/usage-history.csv")

        guard let content = try? String(contentsOf: csvPath, encoding: .utf8) else {
            return CSVResult(sessionPct: 0, weeklyPct: 0, sessionReset: nil, weeklyReset: nil)
        }

        let lines = content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        guard let last = lines.last(where: { !$0.hasPrefix("timestamp") }) else {
            return CSVResult(sessionPct: 0, weeklyPct: 0, sessionReset: nil, weeklyReset: nil)
        }

        let cols = last.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard cols.count >= 4 else {
            return CSVResult(sessionPct: 0, weeklyPct: 0, sessionReset: nil, weeklyReset: nil)
        }

        let sessionPct = Int(cols[2]) ?? 0
        let weeklyPct  = Int(cols[3]) ?? 0
        let sessionReset = cols.count > 4 ? parseSessionReset(cols[4]) : nil
        let weeklyReset  = cols.count > 5 ? parseWeeklyReset(cols[5])  : nil

        return CSVResult(sessionPct: sessionPct, weeklyPct: weeklyPct, sessionReset: sessionReset, weeklyReset: weeklyReset)
    }

    // CSV 포맷 예: "11am", "11pm", "10:59am", "12:30pm"
    private func parseSessionReset(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !s.isEmpty else { return nil }
        let isPM = s.hasSuffix("pm")
        let isAM = s.hasSuffix("am")
        guard isPM || isAM else { return nil }

        let body = String(s.dropLast(2))   // "11", "10:59"
        let parts = body.split(separator: ":")
        guard let hourVal = Int(parts.first ?? ""), hourVal >= 1, hourVal <= 12 else { return nil }
        let minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        guard minute >= 0, minute < 60 else { return nil }

        var hour = hourVal
        if isPM && hour != 12 { hour += 12 }
        if isAM && hour == 12 { hour = 0 }

        let tz = TimeZone(identifier: "Asia/Seoul") ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour; comps.minute = minute; comps.second = 0

        var result = cal.date(from: comps)
        if let r = result, r < Date() { result = cal.date(byAdding: .day, value: 1, to: r) }
        return result
    }

    private func parseWeeklyReset(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        let normalized = s.replacingOccurrences(of: "am", with: "AM", options: .caseInsensitive)
                          .replacingOccurrences(of: "pm", with: "PM", options: .caseInsensitive)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        f.dateFormat = "MMM d 'at' hha"
        f.defaultDate = Calendar.current.startOfDay(for: Date())
        if let d = f.date(from: normalized) { return d }
        f.dateFormat = "MMM d 'at' ha"
        return f.date(from: normalized)
    }

    // MARK: - JSONL Aggregate (mtime 기반 증분 캐싱)
    //
    // 전략:
    // - 파일 mtime이 이전과 같으면 재파싱하지 않고 캐시된 entries 사용
    // - 변경된 파일만 스트리밍 파싱
    // - 캐시는 Application Support에 영속 → 앱 재시작 후에도 유지
    // - dedup: requestId(없으면 uuid) — 세션 재개/compact 시 중복 저장 방지
    // - 제외: isSidechain=true (subagent 중복)

    private struct CachedEntry: Codable {
        let id: String
        let date: Date
        let folderPath: String
        let model: String
        let inputT: Int
        let outputT: Int
        let cacheWriteT: Int
        let cacheReadT: Int
        let sessionId: String?
    }

    private struct FileCache: Codable {
        let mtime: TimeInterval
        let entries: [CachedEntry]
    }

    private struct JSONLCacheBundle: Codable {
        var files: [String: FileCache] = [:]
    }

    // mmap으로 파일을 RSS에 복사하지 않고 가상 메모리 매핑 → 디코드 peak 감소.
    private static let cacheURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClaudeSpot", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("jsonl_cache.json")
    }()

    private var cacheBundle = JSONLCacheBundle()
    private var cacheLoaded = false
    private let cacheDiskQueue = DispatchQueue(label: "com.claudespot.jsonl_cache.disk", qos: .utility)

    private func loadCacheIfNeeded() {
        guard !cacheLoaded else { return }
        cacheLoaded = true
        AppResourceMonitor.trace("cache:load:enter")
        autoreleasepool {
            guard let data = try? Data(contentsOf: Self.cacheURL, options: .mappedIfSafe) else { return }
            if let decoded = try? JSONDecoder().decode(JSONLCacheBundle.self, from: data) {
                cacheBundle = decoded
            }
        }
        AppResourceMonitor.trace("cache:load:exit(files=\(cacheBundle.files.count))")
    }

    private func saveCacheAsync() {
        let snapshot = cacheBundle
        let url = Self.cacheURL
        cacheDiskQueue.async {
            autoreleasepool {
                guard let data = try? JSONEncoder().encode(snapshot) else { return }
                try? data.write(to: url)
            }
        }
    }

    private func fetchJSONLAggregate() -> HeavyUsageData {
        AppResourceMonitor.trace("fetchJSONLAggregate:enter")
        loadCacheIfNeeded()

        let cal = Calendar.current
        let now = Date()
        let cutoff30d  = now.addingTimeInterval(-30 * 24 * 3600)
        let todayStart = cal.startOfDay(for: now)

        let projectsDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/projects")
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return emptyHeavy()
        }

        var folderNameCache = [String: String]()
        var currentFilePaths = Set<String>()
        var cacheChanged = false
        var filesParsed = 0, filesHit = 0

        for folder in folders {
            guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let folderPath = folder.path
            folderNameCache[folderPath] = cleanProjectName(folder.lastPathComponent)

            let jsonls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]))?
                .filter { $0.pathExtension == "jsonl" } ?? []

            for jsonl in jsonls {
                currentFilePaths.insert(jsonl.path)
                let mtime = (try? jsonl.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate?.timeIntervalSince1970) ?? 0

                if let cached = cacheBundle.files[jsonl.path], cached.mtime == mtime {
                    filesHit += 1
                    continue
                }
                filesParsed += 1

                let entries = parseFileEntries(jsonl, folderPath: folderPath)
                cacheBundle.files[jsonl.path] = FileCache(mtime: mtime, entries: entries)
                cacheChanged = true
            }
        }

        // 사라진 파일(삭제된 세션) 정리
        let removedKeys = cacheBundle.files.keys.filter { !currentFilePaths.contains($0) }
        if !removedKeys.isEmpty {
            for k in removedKeys { cacheBundle.files.removeValue(forKey: k) }
            cacheChanged = true
        }

        AppResourceMonitor.trace("fetchJSONLAggregate:parse_done (hit=\(filesHit) parsed=\(filesParsed))")

        // 전역 집계: 모든 캐시된 entries를 순회
        var seenIds            = Set<String>()
        var tokensByFolder     = [String: Int]()
        var breakdownByModel   = [String: ModelTokenBreakdown]()
        var callsByDayStart    = [Date: Int]()
        var todaySessionIds    = Set<String>()
        var todayCalls         = 0
        var monthCalls         = 0
        var monthTokens        = 0

        for (_, fc) in cacheBundle.files {
            for e in fc.entries {
                if e.date < cutoff30d { continue }
                if seenIds.contains(e.id) { continue }
                seenIds.insert(e.id)

                let total = e.inputT + e.outputT + e.cacheWriteT + e.cacheReadT
                tokensByFolder[e.folderPath, default: 0] += total
                monthTokens += total
                monthCalls += 1

                let dayKey = cal.startOfDay(for: e.date)
                callsByDayStart[dayKey, default: 0] += 1

                var b = breakdownByModel[e.model] ?? ModelTokenBreakdown()
                b.input      += e.inputT
                b.output     += e.outputT
                b.cacheWrite += e.cacheWriteT
                b.cacheRead  += e.cacheReadT
                breakdownByModel[e.model] = b

                if e.date >= todayStart {
                    todayCalls += 1
                    if let sid = e.sessionId { todaySessionIds.insert(sid) }
                }
            }
        }

        let dayFmt = Self.dayFmt
        var dailyHistory: [DailyUsage] = []
        for i in (0..<30).reversed() {
            let d = cal.date(byAdding: .day, value: -i, to: todayStart) ?? now
            dailyHistory.append(DailyUsage(date: dayFmt.string(from: d), calls: callsByDayStart[d] ?? 0))
        }

        let projects = tokensByFolder.compactMap { path, tokens -> ProjectUsage? in
            guard tokens > 0, let name = folderNameCache[path] else { return nil }
            return ProjectUsage(name: name, calls: tokens)
        }.sorted { $0.calls > $1.calls }

        AppResourceMonitor.trace("fetchJSONLAggregate:aggregate_done (seen=\(seenIds.count))")

        if cacheChanged { saveCacheAsync() }

        var modelsByName: [String: (calls: Int, cost: Double)] = [:]
        for (raw, b) in breakdownByModel where b.total > 0 {
            let name = displayModelName(raw)
            let existing = modelsByName[name] ?? (calls: 0, cost: 0)
            modelsByName[name] = (calls: existing.calls + b.total, cost: existing.cost + cost(for: raw, breakdown: b))
        }
        let models = modelsByName.map { name, v in
            ModelUsage(name: name, calls: v.calls, cost: v.cost)
        }.sorted { $0.calls > $1.calls }

        return HeavyUsageData(
            todayCalls:    todayCalls,
            todaySessions: todaySessionIds.count,
            monthCalls:    monthCalls,
            monthTokens:   monthTokens,
            dailyHistory:  dailyHistory,
            projects:      Array(projects.prefix(5)),
            models:        models
        )
    }

    /// JSONL 파일을 스트리밍으로 읽어 유효한 assistant entry만 `CachedEntry`로 변환한다.
    /// 필터링(30일 cutoff, dedup)은 집계 단계로 이관 — 파일 캐시는 raw 보존.
    private func parseFileEntries(_ url: URL, folderPath: String) -> [CachedEntry] {
        var entries: [CachedEntry] = []
        autoreleasepool {
            guard let handle = try? FileHandle(forReadingFrom: url) else { return }
            defer { try? handle.close() }

            var buffer = Data()
            let chunkSize = 64 * 1024
            while let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty {
                buffer.append(chunk)
                while let nl = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer.subdata(in: 0..<nl)
                    buffer.removeSubrange(0...nl)
                    if let e = parseLineToEntry(lineData, folderPath: folderPath) {
                        entries.append(e)
                    }
                }
            }
            if !buffer.isEmpty, let e = parseLineToEntry(buffer, folderPath: folderPath) {
                entries.append(e)
            }
        }
        return entries
    }

    private func parseLineToEntry(_ data: Data, folderPath: String) -> CachedEntry? {
        guard
            !data.isEmpty,
            let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            (obj["type"] as? String) == "assistant",
            (obj["isSidechain"] as? Bool) != true,
            let ts   = obj["timestamp"] as? String,
            let date = DateParsers.parseISO8601(ts),
            let message = obj["message"] as? [String: Any],
            let usage   = message["usage"] as? [String: Any]
        else { return nil }

        let id = (obj["requestId"] as? String) ?? (obj["uuid"] as? String) ?? ""
        guard !id.isEmpty else { return nil }

        return CachedEntry(
            id: id,
            date: date,
            folderPath: folderPath,
            model: (message["model"] as? String) ?? "",
            inputT:      usage["input_tokens"] as? Int ?? 0,
            outputT:     usage["output_tokens"] as? Int ?? 0,
            cacheWriteT: usage["cache_creation_input_tokens"] as? Int ?? 0,
            cacheReadT:  usage["cache_read_input_tokens"] as? Int ?? 0,
            sessionId:   obj["sessionId"] as? String
        )
    }

    private func emptyHeavy() -> HeavyUsageData {
        HeavyUsageData(todayCalls: 0, todaySessions: 0, monthCalls: 0, monthTokens: 0, dailyHistory: [], projects: [], models: [])
    }

    private func displayModelName(_ raw: String) -> String {
        let parts = raw.split(separator: "-").map(String.init)
        guard parts.first == "claude" else { return raw }
        let families = ["opus", "sonnet", "haiku"]
        guard let familyIdx = parts.firstIndex(where: { families.contains($0.lowercased()) }) else { return raw }
        let family = parts[familyIdx].capitalized
        // date suffix(8자리 숫자) 제거 후 버전 파트 추출
        let tail = parts.suffix(from: familyIdx + 1).filter { !($0.count == 8 && Int($0) != nil) }
        return tail.isEmpty ? family : "\(family) \(tail.joined(separator: "."))"
    }

    // MARK: - Pricing (USD per 1M tokens, Anthropic 공식 기준)

    private struct ModelTokenBreakdown {
        var input: Int = 0
        var output: Int = 0
        var cacheWrite: Int = 0
        var cacheRead: Int = 0
        var total: Int { input + output + cacheWrite + cacheRead }
    }

    private struct ModelPricing {
        let input: Double
        let output: Double
        let cacheWrite: Double
        let cacheRead: Double
    }

    private static let pricingByFamily: [String: ModelPricing] = [
        "opus":   ModelPricing(input: 15,  output: 75, cacheWrite: 18.75, cacheRead: 1.50),
        "sonnet": ModelPricing(input: 3,   output: 15, cacheWrite: 3.75,  cacheRead: 0.30),
        "haiku":  ModelPricing(input: 1,   output: 5,  cacheWrite: 1.25,  cacheRead: 0.10),
    ]

    private func cost(for rawModel: String, breakdown b: ModelTokenBreakdown) -> Double {
        let family = rawModel.split(separator: "-").dropFirst().first.map(String.init)?.lowercased() ?? ""
        let p = Self.pricingByFamily[family] ?? Self.pricingByFamily["sonnet"]!
        let per = 1_000_000.0
        return Double(b.input)      * p.input      / per
             + Double(b.output)     * p.output     / per
             + Double(b.cacheWrite) * p.cacheWrite / per
             + Double(b.cacheRead)  * p.cacheRead  / per
    }

    // MARK: - Helpers

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current; return f
    }()

    private func cleanProjectName(_ raw: String) -> String {
        var name = raw
        if name.hasPrefix("-") { name = String(name.dropFirst()) }
        let parts = name.split(separator: "-", omittingEmptySubsequences: true).map(String.init)
        var idx = 0
        if idx < parts.count, parts[idx].lowercased() == "users" { idx += 1 }
        if idx < parts.count { idx += 1 }
        if idx < parts.count, ["project", "develop", "library", "documents"].contains(parts[idx].lowercased()) {
            idx += 1
        }
        let remaining = parts[idx...].joined(separator: "-")
        return remaining.isEmpty ? raw : remaining
    }
}
