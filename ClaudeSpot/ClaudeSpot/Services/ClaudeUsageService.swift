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
    let name: String   // "Opus 4.6", "Sonnet 4.6"
    let calls: Int
}

// codeburn + JSONL — 앱 시작 시 1번
struct HeavyUsageData {
    let todaySessions: Int
    let monthCalls: Int
    let dailyHistory: [DailyUsage]
    let projects: [ProjectUsage]
    let models: [ModelUsage]
}

// CSV + JSONL 오늘치 — 패널 열 때마다
struct LiveUsageData {
    let todayCalls: Int
    let sessionPct: Int
    let weeklyPct: Int
}

@Observable
final class ClaudeUsageService {
    static let shared = ClaudeUsageService()
    private init() {}

    var heavyData: HeavyUsageData?
    var liveData: LiveUsageData = LiveUsageData(todayCalls: 0, sessionPct: 0, weeklyPct: 0)
    var isLoadingHeavy = false

    // MARK: - 앱 시작 시 1번 (codeburn + JSONL 프로젝트)

    func fetchHeavy() async {
        guard heavyData == nil else { return }
        await MainActor.run { isLoadingHeavy = true }

        // GCD로 실행해서 Swift concurrency 스레드 풀 블로킹 방지
        async let cb = withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async { cont.resume(returning: self.fetchCodeburnSync()) }
        }
        async let projects = withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async { cont.resume(returning: self.fetchProjectsSync()) }
        }
        let (cbResult, projectsResult) = await (cb, projects)

        let result = HeavyUsageData(
            todaySessions: cbResult.todaySessions,
            monthCalls: cbResult.monthCalls,
            dailyHistory: cbResult.dailyHistory,
            projects: projectsResult,
            models: cbResult.models
        )

        await MainActor.run {
            self.heavyData = result
            self.isLoadingHeavy = false
        }
    }

    // MARK: - 패널 열 때마다 (CSV + 오늘 JSONL 카운트) — GCD 백그라운드

    func fetchLive() async {
        let result = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let calls = self.countTodayCallsFromJSONL()
                let (sessionPct, weeklyPct) = self.readCSV()
                cont.resume(returning: LiveUsageData(todayCalls: calls, sessionPct: sessionPct, weeklyPct: weeklyPct))
            }
        }
        liveData = result
    }

    private func countTodayCallsFromJSONL() -> Int {
        let cutoff = Calendar.current.startOfDay(for: Date())
        var count = 0
        enumerateJSONLLines(cutoff: cutoff) { _ in count += 1 }
        return count
    }

    /// cutoff 이후의 모든 JSONL 라인을 순회하며 클로저를 호출한다. folder URL을 함께 전달한다.
    private func enumerateJSONLLines(cutoff: Date, body: (_ folder: URL) -> Void) {
        let projectsDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/projects")
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return }

        for folder in folders {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let jsonls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "jsonl" } ?? []

            for jsonl in jsonls {
                guard let content = try? String(contentsOf: jsonl, encoding: .utf8) else { continue }
                for line in content.split(separator: "\n") {
                    guard
                        let data = line.data(using: .utf8),
                        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let ts = obj["timestamp"] as? String,
                        let date = parseISO(ts),
                        date >= cutoff
                    else { continue }
                    body(folder)
                }
            }
        }
    }

    private func readCSV() -> (Int, Int) {
        let csvPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("develop/claude_status/usage-history.csv")

        guard let content = try? String(contentsOf: csvPath, encoding: .utf8) else { return (0, 0) }

        let lines = content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        guard let last = lines.last else { return (0, 0) }

        // timestamp,weekday,session_pct,weekly_pct,status
        let cols = last.split(separator: ",").map(String.init)
        guard cols.count >= 4 else { return (0, 0) }

        return (Int(cols[2]) ?? 0, Int(cols[3]) ?? 0)
    }

    // MARK: - codeburn (동기, GCD에서 실행)

    private struct CodeburnResult {
        let todaySessions: Int
        let monthCalls: Int
        let dailyHistory: [DailyUsage]
        let models: [ModelUsage]
    }

    private func fetchCodeburnSync() -> CodeburnResult {
        let tmpPath = "/tmp/cs-codeburn-\(ProcessInfo.processInfo.processIdentifier).json"
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let codeburnPath = findExecutable("codeburn") ?? "/opt/homebrew/bin/codeburn"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: codeburnPath)
        process.arguments = ["export", "--format", "json", "--output", tmpPath]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CodeburnResult(todaySessions: 0, monthCalls: 0, dailyHistory: [], models: [])
        }

        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: tmpPath)),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let periods = json["periods"] as? [String: Any]
        else {
            return CodeburnResult(todaySessions: 0, monthCalls: 0, dailyHistory: [], models: [])
        }

        func period(_ key: String) -> [String: Any]? { periods[key] as? [String: Any] }
        func summary(_ key: String) -> [String: Any]? { period(key)?["summary"] as? [String: Any] }

        let todaySessions = summary("Today")?["Sessions"] as? Int ?? 0
        let monthCalls = summary("30 Days")?["API Calls"] as? Int ?? 0

        // 30일 daily
        var daily: [DailyUsage] = []
        if let rows = period("30 Days")?["daily"] as? [[String: Any]] {
            for row in rows {
                if let date = row["Date"] as? String, let calls = row["API Calls"] as? Int {
                    daily.append(DailyUsage(date: date, calls: calls))
                }
            }
        }
        daily.sort { $0.date < $1.date }

        // 30일 모델별
        var models: [ModelUsage] = []
        if let rows = period("30 Days")?["models"] as? [[String: Any]] {
            for row in rows {
                guard
                    let name = row["Model"] as? String,
                    let calls = row["API Calls"] as? Int,
                    calls > 0,
                    !name.contains("synthetic")
                else { continue }
                // 이름 정리: "Opus 4.6" / "Sonnet 4.6" / "Haiku 4.5"
                models.append(ModelUsage(name: name, calls: calls))
            }
        }
        models.sort { $0.calls > $1.calls }

        return CodeburnResult(
            todaySessions: todaySessions,
            monthCalls: monthCalls,
            dailyHistory: daily,
            models: models
        )
    }

    // MARK: - JSONL (by project, 30일, 동기)

    private func fetchProjectsSync() -> [ProjectUsage] {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        var callsByFolder: [URL: Int] = [:]
        enumerateJSONLLines(cutoff: cutoff) { folder in
            callsByFolder[folder, default: 0] += 1
        }
        let result = callsByFolder.compactMap { folder, calls -> ProjectUsage? in
            calls > 0 ? ProjectUsage(name: cleanProjectName(folder.lastPathComponent), calls: calls) : nil
        }
        return Array(result.sorted { $0.calls > $1.calls }.prefix(5))
    }

    // MARK: - Helpers

    private static let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()

    private func parseISO(_ ts: String) -> Date? {
        Self.isoFull.date(from: ts) ?? Self.isoBasic.date(from: ts)
    }

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

    private func findExecutable(_ name: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(NSHomeDirectory())/.local/bin/\(name)",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
