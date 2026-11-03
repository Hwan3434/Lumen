import AppKit
import IOKit.ps

/// 덮개를 닫아도 Mac이 잠들지 않게 하는 모드 (`pmset -a disablesleep 1`).
///
/// 카페인(`CaffeineFeature`, IOPMAssertion)은 유휴 잠자기만 막고, 앱이 죽으면 OS가 알아서 풀어준다.
/// 이 모드는 덮개 닫기·Apple 메뉴 잠자기까지 막는 **시스템 전역 설정**이라 재부팅 뒤에도 남는다.
/// 덮개를 닫은 채 가방에 넣으면 배터리와 발열 문제로 이어지므로:
///   • 켜는 건 항상 사용자가 직접 한다 (앱 시작 시 자동 활성화 없음)
///   • 끄는 길을 여러 개 둔다 — 시간 제한, 배터리 하한, 메뉴바 아이콘, 앱 종료
///   • 크래시·강제 종료로 끄지 못했으면 다음 실행 때 복구한다 (`restoreIfLeftOn`)
///
/// 설정 > 전원 탭이 같은 상태를 보여주므로 `shared` 인스턴스 하나를 공유한다.
@Observable
final class LidAwakeFeature: BuiltInFeature {
    static let shared = LidAwakeFeature()

    static let duration: TimeInterval = 2 * 60 * 60
    static let minimumBatteryPercent = 20

    /// Lumen이 켰다는 표시. 시스템 값이 1이어도 이 표시가 없으면 사용자가 터미널에서 직접 켠 것이므로 건드리지 않는다.
    private static let ownedKey = "lidAwake.ownedByLumen"

    let featureDescription = "덮개를 닫아도 잠들지 않게 (최대 2시간)"
    let iconName = "flame"
    let searchKeywords = ["덮개", "클램쉘", "clamshell", "lid", "disablesleep", "잠자기", "슬립", "sleep"]
    let showInDefaultList = false

    private(set) var isActive = false
    private(set) var isBusy = false
    private(set) var expiresAt: Date?
    /// 설정 탭 표시용. `refreshStatus()`로 갱신한다.
    private(set) var isRuleInstalled = false
    private(set) var isSystemSleepDisabled: Bool?

    @ObservationIgnored private var statusHandle: StatusBarItemHandle?
    @ObservationIgnored private var expiryTimer: Timer?
    @ObservationIgnored private var battery: BatteryWatcher?

    private init() {}

    var name: String {
        isActive ? "덮개 모드 끄기" : "덮개 닫아도 깨어있기"
    }

    func activate() {
        if isActive {
            turnOff(toast: "덮개 모드를 껐어요")
        } else {
            turnOn()
        }
    }

    func setup() {
        restoreIfLeftOn()
    }

    func attachStatusBar(_ coordinator: StatusBarCoordinator) {
        // 켜져 있을 때만 메뉴바에 보인다. 누르면 바로 끈다.
        statusHandle = coordinator.addItem(
            initialIcon: "flame",
            accessibility: "덮개 모드",
            visible: false,
            onClick: { [weak self] in self?.turnOff(toast: "덮개 모드를 껐어요") }
        )
    }

    func teardown() {
        guard isActive || isOwned else { return }
        // 앱 종료 직전이라 비동기로 넘기면 끝나기 전에 프로세스가 사라진다 — 의도적으로 동기 호출.
        // 실패하면 소유 표시를 남겨 두어 다음 실행 때 `restoreIfLeftOn`이 다시 시도한다.
        if (try? SleepPolicyService.setSleepDisabled(false)) != nil {
            isOwned = false
        }
        stopGuards()
        isActive = false
    }

    // MARK: - 켜기·끄기

    private func turnOn() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let ruleInstalled = try await SleepPolicyService.offMain { SleepPolicyService.isRuleInstalled() }
                if !ruleInstalled {
                    guard confirmRuleInstall() else { return }
                    try await SleepPolicyService.offMain { try SleepPolicyService.installRule() }
                    isRuleInstalled = true
                }
                try await SleepPolicyService.offMain { try SleepPolicyService.setSleepDisabled(true) }
                isOwned = true
                isActive = true
                isSystemSleepDisabled = true
                startGuards()
                statusHandle?.show()
                LumenToast.show(text: "덮개를 닫아도 \(Int(Self.duration / 3600))시간 동안 깨어 있어요")
            } catch SleepPolicyService.Failure.cancelled {
                // 비밀번호 창에서 취소 — 조용히 끝낸다.
            } catch {
                LumenToast.show(text: "덮개 모드를 켜지 못했어요: \(error.localizedDescription)", duration: 4)
            }
        }
    }

    private func turnOff(toast: String?) {
        guard isActive, !isBusy else { return }
        isBusy = true
        stopGuards()
        Task {
            defer { isBusy = false }
            do {
                try await SleepPolicyService.offMain { try SleepPolicyService.setSleepDisabled(false) }
                isOwned = false
                isActive = false
                isSystemSleepDisabled = false
                statusHandle?.hide()
                if let toast { LumenToast.show(text: toast) }
            } catch {
                // 끄지 못했으면 안전장치를 다시 걸고 켜진 상태로 남겨 둔다 — 사용자가 다시 시도할 수 있게.
                startGuards()
                LumenToast.show(text: "덮개 모드를 끄지 못했어요: \(error.localizedDescription)", duration: 4)
            }
        }
    }

    /// 이전 실행에서 Lumen이 켜 둔 채 종료(크래시·강제 종료)됐다면 끈다.
    /// 자동으로 다시 켜지는 않는다 — 켜는 건 항상 사용자의 결정.
    private func restoreIfLeftOn() {
        guard isOwned else { return }
        Task {
            // 상태를 읽지 못하면 소유 표시를 그대로 두고 다음 실행 때 다시 본다.
            guard let stillOn = try? await SleepPolicyService.offMain({ SleepPolicyService.isSleepDisabled() }) else { return }
            guard stillOn else {
                isOwned = false
                return
            }
            do {
                try await SleepPolicyService.offMain { try SleepPolicyService.setSleepDisabled(false) }
                isOwned = false
                LumenToast.show(text: "지난번에 켜 둔 덮개 모드를 껐어요")
            } catch {
                LumenToast.show(text: "덮개 모드가 켜진 채 남아 있어요. 설정 > 전원에서 확인해 주세요", duration: 5)
            }
        }
    }

    // MARK: - 설정 탭

    func refreshStatus() {
        Task {
            isRuleInstalled = (try? await SleepPolicyService.offMain { SleepPolicyService.isRuleInstalled() }) ?? false
            isSystemSleepDisabled = try? await SleepPolicyService.offMain { SleepPolicyService.isSleepDisabled() }
        }
    }

    /// 잠자기를 원래대로 돌리고 sudoers 규칙을 지운다. 관리자 비밀번호를 한 번 묻는다.
    func removeRule() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await SleepPolicyService.offMain { try SleepPolicyService.removeRule() }
                stopGuards()
                statusHandle?.hide()
                isActive = false
                isOwned = false
                LumenToast.show(text: "덮개 모드 권한을 지웠어요")
            } catch SleepPolicyService.Failure.cancelled {
            } catch {
                LumenToast.show(text: "권한을 지우지 못했어요: \(error.localizedDescription)", duration: 4)
            }
            refreshStatus()
        }
    }

    // MARK: - 안전장치

    private func startGuards() {
        expiresAt = Date().addingTimeInterval(Self.duration)
        expiryTimer?.invalidate()
        expiryTimer = Timer.scheduledTimer(withTimeInterval: Self.duration, repeats: false) { [weak self] _ in
            guard let feature = self else { return }
            Task { @MainActor [feature] in
                feature.turnOff(toast: "\(Int(Self.duration / 3600))시간이 지나 덮개 모드를 껐어요")
            }
        }
        let watcher = battery ?? BatteryWatcher { [weak self] in self?.checkBattery() }
        battery = watcher
        watcher.start()
        checkBattery()
    }

    private func stopGuards() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        expiresAt = nil
        battery?.stop()
    }

    private func checkBattery() {
        guard isActive, let percent = BatteryWatcher.percentIfOnBattery(),
              percent <= Self.minimumBatteryPercent else { return }
        turnOff(toast: "배터리가 \(Self.minimumBatteryPercent)% 이하라 덮개 모드를 껐어요")
    }

    // MARK: - Helpers

    private var isOwned: Bool {
        get { UserDefaults.standard.bool(forKey: Self.ownedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.ownedKey) }
    }

    private func confirmRuleInstall() -> Bool {
        let alert = NSAlert()
        alert.messageText = "처음 한 번만 관리자 권한이 필요해요"
        alert.informativeText = """
        덮개를 닫아도 잠들지 않게 하려면 시스템 설정(pmset)을 바꿔야 해요. \
        매번 비밀번호를 묻지 않도록 /etc/sudoers.d/lumen 에 \
        'pmset -a disablesleep 0/1' 두 명령만 허용하는 규칙을 추가해요. \
        다른 명령에는 권한이 생기지 않고, 설정 > 전원에서 언제든 지울 수 있어요.
        """
        alert.addButton(withTitle: "계속")
        alert.addButton(withTitle: "취소")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}

/// 전원 상태 변화(어댑터 연결·해제, 잔량 변화)를 알림으로 받는다. 폴링하지 않는다.
private final class BatteryWatcher {
    private var source: CFRunLoopSource?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        guard source == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let created = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            // 메인 런루프에 등록했으므로 콜백도 메인 스레드에서 온다.
            MainActor.assumeIsolated {
                Unmanaged<BatteryWatcher>.fromOpaque(context).takeUnretainedValue().onChange()
            }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), created, .defaultMode)
        source = created
    }

    func stop() {
        guard let source else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        self.source = nil
    }

    /// 배터리로 동작 중일 때의 잔량(%). 어댑터 연결 중이거나 배터리가 없으면 nil.
    static func percentIfOnBattery() -> Int? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?,
              type == kIOPSBatteryPowerValue else { return nil }
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let current = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return current * 100 / max
        }
        return nil
    }
}
