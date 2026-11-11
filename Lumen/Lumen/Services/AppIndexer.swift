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

    private static func contents(of dir: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )) ?? []
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
            for url in Self.contents(of: dir) {
                if url.pathExtension == "app" {
                    appendApp(at: url, into: &apps, seen: &seen)
                } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    // 한 단계만 더 본다 — `/Applications/Utilities`, 회사별 폴더(`Adobe …/X.app`)에 든 앱.
                    for inner in Self.contents(of: url) where inner.pathExtension == "app" {
                        appendApp(at: inner, into: &apps, seen: &seen)
                    }
                }
            }
        }

        cachedApps = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        MemoryTrace.record("AppIndexer:loadApps:exit(\(cachedApps.count))")
        return cachedApps
    }

    private func appendApp(at url: URL, into apps: inout [AppItem], seen: inout Set<String>) {
        let item = Self.makeItem(at: url)
        guard seen.insert(item.id).inserted else { return }
        apps.append(item)
    }

    /// 앱 번들 하나를 `AppItem`으로 만든다. id는 번들 ID(없으면 경로)이고, 실행 횟수와 숨긴 앱 목록이 이 값으로 저장된다.
    static func makeItem(at url: URL) -> AppItem {
        // Bundle(url:)은 번들을 프로세스 끝까지 붙잡아 두므로 Info.plist만 읽는다.
        // iOS 앱을 감싼 번들처럼 Contents/Info.plist가 없는 경우에만 Bundle에 맡긴다.
        let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) as? [String: Any]
            ?? Bundle(url: url)?.infoDictionary
        let bundleID = info?["CFBundleIdentifier"] as? String ?? url.path

        let displayName = info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
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

        return AppItem(id: bundleID, name: displayName, path: url, aliases: aliases)
    }

    /// 저장해 둔 id(번들 ID 또는 경로)로 앱 하나만 찾는다. 지워진 앱이면 nil.
    /// 숨긴 앱 탭처럼 몇 개만 필요할 때 앱 폴더 전체를 훑지 않으려고 쓴다.
    static func item(forID id: String) -> AppItem? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            return makeItem(at: url)
        }
        guard id.hasPrefix("/"), FileManager.default.fileExists(atPath: id) else { return nil }
        return makeItem(at: URL(fileURLWithPath: id))
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
}
