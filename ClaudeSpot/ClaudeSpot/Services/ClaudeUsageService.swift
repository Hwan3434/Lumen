import Foundation

struct DailyUsage: Identifiable {
    var id: String { date }
    let date: String   // "2026-04-15"
    let calls: Int
}

struct ProjectUsage: Identifiable {
    var id: String { name }
    let name: String
    let calls: Int
}

struct ClaudeUsageData {
    let todayCalls: Int
    let todaySessions: Int
    let monthCalls: Int
    let dailyHistory: [DailyUsage]   // 30일, 날짜순
    let projects: [ProjectUsage]     // top 5
    let sessionPct: Int
    let weeklyPct: Int
}

@Observable
final class ClaudeUsageService {
    var data: ClaudeUsageData?
    var isLoading = false
    var lastError: String?

    func fetch() async {
        await MainActor.run { isLoading = true; lastError = nil }

        async let codeburnResult = fetchCodeburn()
        async let projectsResult = fetchProjects()
        async let csvResult = fetchCSV()

        let (cb, projects, csv) = await (codeburnResult, projectsResult, csvResult)

        let result = ClaudeUsageData(
            todayCalls: cb.todayCalls,
            todaySessions: cb.todaySessions,
            monthCalls: cb.monthCalls,
            dailyHistory: cb.dailyHistory,
            projects: projects,
            sessionPct: csv.sessionPct,
            weeklyPct: csv.weeklyPct
        )

        await MainActor.run {
            self.data = result
            self.isLoading = false
        }
    }

    // MARK: - codeburn

    private struct CodeburnResult {
        let todayCalls: Int
        let todaySessions: Int
        let monthCalls: Int
        let dailyHistory: [DailyUsage]
    }

    private func fetchCodeburn() async -> CodeburnResult {
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
            return CodeburnResult(todayCalls: 0, todaySessions: 0, monthCalls: 0, dailyHistory: [])
        }

        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: tmpPath)),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let periods = json["periods"] as? [String: Any]
        else {
            return CodeburnResult(todayCalls: 0, todaySessions: 0, monthCalls: 0, dailyHistory: [])
        }

        func summary(_ key: String) -> [String: Any]? {
            (periods[key] as? [String: Any])?["summary"] as? [String: Any]
        }

        let todayCalls = summary("Today")?["API Calls"] as? Int ?? 0
        let todaySessions = summary("Today")?["Sessions"] as? Int ?? 0
        let monthCalls = summary("30 Days")?["API Calls"] as? Int ?? 0

        // 30일 daily 히스토리
        var daily: [DailyUsage] = []
        if let thirtyDays = periods["30 Days"] as? [String: Any],
           let rows = thirtyDays["daily"] as? [[String: Any]] {
            for row in rows {
                if let date = row["Date"] as? String,
                   let calls = row["API Calls"] as? Int {
                    daily.append(DailyUsage(date: date, calls: calls))
                }
            }
        }
        daily.sort { $0.date < $1.date }

        return CodeburnResult(
            todayCalls: todayCalls,
            todaySessions: todaySessions,
            monthCalls: monthCalls,
            dailyHistory: daily
        )
    }

    // MARK: - JSONL (by project)

    private func fetchProjects() async -> [ProjectUsage] {
        let projectsDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/projects")
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let fm = FileManager.default

        guard let folders = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var result: [ProjectUsage] = []

        for folder in folders {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let jsonls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "jsonl" } ?? []

            var calls = 0
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
                    calls += 1
                }
            }

            if calls > 0 {
                let rawName = folder.lastPathComponent
                let displayName = cleanProjectName(rawName)
                result.append(ProjectUsage(name: displayName, calls: calls))
            }
        }

        return Array(result.sorted { $0.calls > $1.calls }.prefix(5))
    }

    private func parseISO(_ ts: String) -> Date? {
        let s = ts.replacingOccurrences(of: "Z", with: "+0000")
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: ts) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: s)
    }

    private func cleanProjectName(_ raw: String) -> String {
        // "-Users-temp-project-planet-ai" → "planet-ai"
        // "-Users-temp-develop-claude-spot" → "claude-spot"
        var name = raw
        if name.hasPrefix("-") { name = String(name.dropFirst()) }
        // 앞의 "Users-{username}-" 혹은 "Users-{username}-project-" / "Users-{username}-develop-" 제거
        let parts = name.split(separator: "-", omittingEmptySubsequences: true).map(String.init)
        // "Users", username 제거
        var idx = 0
        if idx < parts.count, parts[idx].lowercased() == "users" { idx += 1 }
        if idx < parts.count { idx += 1 } // username
        // 중간 폴더 (project, develop 등) 하나 더 제거
        if idx < parts.count, ["project", "develop", "library", "documents"].contains(parts[idx].lowercased()) {
            idx += 1
        }
        let remaining = parts[idx...].joined(separator: "-")
        return remaining.isEmpty ? raw : remaining
    }

    // MARK: - CSV (session/weekly %)

    private struct CSVResult {
        let sessionPct: Int
        let weeklyPct: Int
    }

    private func fetchCSV() async -> CSVResult {
        let csvPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("develop/claude_status/usage-history.csv")

        guard let content = try? String(contentsOf: csvPath, encoding: .utf8) else {
            return CSVResult(sessionPct: 0, weeklyPct: 0)
        }

        let lines = content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        guard let last = lines.last else { return CSVResult(sessionPct: 0, weeklyPct: 0) }

        // format: timestamp,weekday,session_pct,weekly_pct,status
        let cols = last.split(separator: ",").map(String.init)
        guard cols.count >= 4 else { return CSVResult(sessionPct: 0, weeklyPct: 0) }

        return CSVResult(
            sessionPct: Int(cols[2]) ?? 0,
            weeklyPct: Int(cols[3]) ?? 0
        )
    }

    // MARK: - Helpers

    private func findExecutable(_ name: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(NSHomeDirectory())/.local/bin/\(name)",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
