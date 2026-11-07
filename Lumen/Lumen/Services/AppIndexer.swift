import AppKit

final class AppIndexer {
    static let defaultDirectories = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
    ]

    private let directories: [URL]
    private var cachedApps: [AppItem] = []
    private var watchers: [DispatchSourceFileSystemObject] = []
    private var pendingChange: DispatchWorkItem?

    init(directories: [URL] = AppIndexer.defaultDirectories) {
        self.directories = directories
    }

    deinit {
        watchers.forEach { $0.cancel() }
    }

    func loadApps() -> [AppItem] {
        if !cachedApps.isEmpty { return cachedApps }

        MemoryTrace.record("AppIndexer:loadApps:enter")

        var apps: [AppItem] = []
        var seen = Set<String>()

        // CoreServices 전체 탐색 시 시스템 에이전트가 딸려오므로 필요한 앱만 직접 추가
        let individualApps = [
            URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
        ]

        for url in individualApps where url.pathExtension == "app" {
            appendApp(at: url, into: &apps, seen: &seen)
        }

        for dir in directories {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                appendApp(at: url, into: &apps, seen: &seen)
            }
        }

        cachedApps = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        MemoryTrace.record("AppIndexer:loadApps:exit(\(cachedApps.count))")
        return cachedApps
    }

    private func appendApp(at url: URL, into apps: inout [AppItem], seen: inout Set<String>) {
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier ?? url.path
        guard !seen.contains(bundleID) else { return }
        seen.insert(bundleID)

        let displayName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent

        // Finder에 보이는 현지화 이름("System Settings" → "시스템 설정")도 검색되게 별명에 더한다.
        // Lumen 자체는 영어 전용이라 FileManager.displayName은 영어를 돌려주므로 Spotlight 값을 쓴다.
        var aliases = Constants.appAliases[bundleID] ?? []
        if let localizedName = MDItemCreateWithURL(nil, url as CFURL)
            .flatMap({ MDItemCopyAttribute($0, kMDItemDisplayName) as? String })?
            .replacingOccurrences(of: ".app", with: "", options: [.anchored, .backwards]),
           localizedName.caseInsensitiveCompare(displayName) != .orderedSame,
           !aliases.contains(where: { $0.caseInsensitiveCompare(localizedName) == .orderedSame }) {
            aliases.append(localizedName)
        }

        apps.append(AppItem(
            id: bundleID,
            name: displayName,
            path: url,
            aliases: aliases
        ))
    }

    /// 앱 폴더 바로 아래 항목이 추가·삭제·이름변경되면 캐시를 비우고 `onChange`를 부른다.
    /// 폴링 없이 커널 알림(vnode write)으로만 깨어난다. 설치 프로그램은 여러 번 나눠 쓰므로
    /// 마지막 알림 뒤 `debounce`초 동안 조용해지면 한 번만 알린다.
    /// 감시 시작 시점에 없는 폴더(예: `~/Applications`)는 감시하지 않는다.
    func startWatching(debounce: TimeInterval = 1.0, onChange: @escaping () -> Void) {
        guard watchers.isEmpty else { return }

        for dir in directories {
            let fd = open(dir.path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: .write, queue: .main
            )
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated {
                    self?.scheduleChange(after: debounce, onChange: onChange)
                }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            watchers.append(source)
        }
    }

    private func scheduleChange(after delay: TimeInterval, onChange: @escaping () -> Void) {
        pendingChange?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.cachedApps = []
                MemoryTrace.record("AppIndexer:directoryChanged")
                onChange()
            }
        }
        pendingChange = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func reload() {
        cachedApps = []
        _ = loadApps()
    }
}
