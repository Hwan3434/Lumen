import AppKit
import IOKit.ps

/// 덮개를 닫아도 Mac이 잠들지 않게 하는 모드 (`pmset -a disablesleep 1`).
///
/// 카페인(`CaffeineFeature`, IOPMAssertion)은 유휴 잠자기만 막고, 앱이 죽으면 OS가 알아서 풀어준다.
/// 이 모드는 덮개 닫기·Apple 메뉴 잠자기까지 막는 **시스템 전역 설정**이라 재부팅 뒤에도 남는다.
/// 덮개를 닫은 채 가방에 넣으면 배터리와 발열 문제로 이어지므로:
///   • 켜는 건 항상 사용자가 직접 한다 (앱 시작 시 자동 활성화 없음)
///   • 끄는 길을 여러 개 둔다 — 배터리 시간 제한, 배터리 하한, 메뉴바 아이콘, 앱 종료
///   • 전원이 꽂혀 있는 동안은 시간 제한 없이 켜 둔다. 외장 모니터를 끈 채 24시간 원격으로 쓰는 경우.
///     전원을 뽑으면 그때부터 `batteryHours` 타이머가 돈다 — 가방에 넣는 경우.
///   • 크래시·강제 종료로 끄지 못했으면 다음 실행 때 복구한다 (`restoreIfLeftOn`)
///
/// 설정 > 전원 탭이 같은 상태를 보여주므로 `shared` 인스턴스 하나를 공유한다.
@Observable
final class LidAwakeFeature: ToggleableFeature {
    static let shared = LidAwakeFeature()

    static let batteryHourOptions = [1, 2, 4, 8]
    static let minimumBatteryPercent = 20

    /// Lumen이 켰다는 표시. 시스템 값이 1이어도 이 표시가 없으면 사용자가 터미널에서 직접 켠 것이므로 건드리지 않는다.
    private static let ownedKey = "lidAwake.ownedByLumen"
    private static let batteryHoursKey = "lidAwake.batteryHours"

    /// 전원을 뽑은 뒤 몇 시간 후에 끌지. 다음에 전원을 뽑을 때부터 적용된다.
    var batteryHours: Int = UserDefaults.standard.object(forKey: LidAwakeFeature.batteryHoursKey) as? Int ?? 2 {
        didSet { UserDefaults.standard.set(batteryHours, forKey: Self.batteryHoursKey) }
    }

    let featureDescription = "덮개를 닫아도 잠들지 않게 (전원 연결 중엔 계속)"
    let iconName = "flame"
    let searchKeywords = ["덮개", "클램쉘", "clamshell", "lid", "disablesleep", "잠자기", "슬립", "sleep"]

    private(set) var isActive = false
    private(set) var isBusy = false
    private(set) var expiresAt: Date?
    /// 설정 탭 표시용. `refreshStatus()`로 갱신한다.
    private(set) var isRuleInstalled = false
    private(set) var isSystemSleepDisabled: Bool?

    @ObservationIgnored private var statusHandle: StatusBarItemHandle?
    @ObservationIgnored private var expiryTimer: Timer?
    @ObservationIgnored private var systemCheckTimer: Timer?
    @ObservationIgnored private var battery: BatteryWatcher?

    private init() {}

    let name = "클램쉘 모드"

    var isOn: Bool { isActive || isOwned }
    var onStatus: String? {
        guard isOn else { return nil }
        guard let expiresAt else { return isActive ? "전원이 연결된 동안 계속 켜져 있어요" : "켜져 있어요" }
        return "\(LumenTime.relative(expiresAt, granularity: .calendar))에 자동으로 꺼져요"
    }

    func activate() {
        if isOn {
            turnOff(toast: "클램쉘 모드를 껐어요")
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
            accessibility: "클램쉘 모드",
            visible: false,
            onClick: { [weak self] in self?.turnOff(toast: "클램쉘 모드를 껐어요") }
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
        if let percent = BatteryWatcher.percentIfOnBattery(), percent <= Self.minimumBatteryPercent {
            LumenToast.show(text: "배터리가 \(Self.minimumBatteryPercent)% 이하라 클램쉘 모드를 켤 수 없어요", duration: 4)
            return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                // 사용자가 터미널에서 이미 막아 둔 상태면 소유하지 않는다 — 끌 때 사용자 설정을 지우게 되므로.
                if try await SleepPolicyService.offMain({ SleepPolicyService.isSleepDisabled() }) == true {
                    isSystemSleepDisabled = true
                    LumenToast.show(text: "시스템에서 이미 잠자기가 막혀 있어요 (Lumen 밖에서 설정됨)", duration: 4)
                    return
                }
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
                LumenToast.show(text: "덮개를 닫아도 깨어 있어요. 전원을 뽑으면 \(batteryHours)시간 뒤 꺼져요")
            } catch SleepPolicyService.Failure.cancelled {
                // 비밀번호 창에서 취소 — 조용히 끝낸다.
            } catch {
                LumenToast.show(text: "클램쉘 모드를 켜지 못했어요: \(error.localizedDescription)", duration: 4)
            }
        }
    }

    /// `sleepIfLidClosed`: 시간 제한·배터리처럼 사용자가 자리에 없을 수 있는 자동 끄기에서 true.
    /// 덮개가 닫힌 채 `disablesleep 0`만 되돌리면 덮개를 다시 여닫기 전까지 잠들지 않을 수 있어 바로 재운다.
    private func turnOff(toast: String?, sleepIfLidClosed: Bool = false) {
        // 크래시 뒤 복구에 실패해 isActive는 false인데 시스템 값이 남은 경우(isOwned)도 끌 수 있어야 한다.
        guard isActive || isOwned, !isBusy else { return }
        isBusy = true
        let deadline = expiresAt
        stopGuards()
        Task {
            defer { isBusy = false }
            do {
                try await SleepPolicyService.offMain {
                    try SleepPolicyService.setSleepDisabled(false)
                    if sleepIfLidClosed, SleepPolicyService.isLidClosed() {
                        try? SleepPolicyService.sleepNow()
                    }
                }
                isOwned = false
                isActive = false
                isSystemSleepDisabled = false
                statusHandle?.hide()
                if let toast { LumenToast.show(text: toast) }
            } catch {
                // 끄지 못했으면 안전장치를 다시 걸고 켜진 상태로 남겨 둔다 — 사용자가 다시 시도할 수 있게.
                // 만료 시각은 늘리지 않되, 이미 지났으면 1분 뒤 다시 시도한다.
                if isActive {
                    startGuards(resumeDeadline: deadline.map { max($0, Date().addingTimeInterval(60)) })
                }
                LumenToast.show(text: "클램쉘 모드를 끄지 못했어요: \(error.localizedDescription)", duration: 4)
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
                LumenToast.show(text: "지난번에 켜 둔 클램쉘 모드를 껐어요")
            } catch {
                LumenToast.show(text: "클램쉘 모드가 켜진 채 남아 있어요. 설정 > 전원에서 확인해 주세요", duration: 5)
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
                LumenToast.show(text: "클램쉘 모드 권한을 지웠어요")
            } catch SleepPolicyService.Failure.cancelled {
            } catch {
                LumenToast.show(text: "권한을 지우지 못했어요: \(error.localizedDescription)", duration: 4)
            }
            refreshStatus()
        }
    }

    // MARK: - 안전장치

    /// `resumeDeadline`: 끄기에 실패해 다시 걸 때, 배터리 중이면 이어서 쓸 만료 시각.
    private func startGuards(resumeDeadline: Date? = nil) {
        let watcher = battery ?? BatteryWatcher { [weak self] in self?.powerChanged() }
        battery = watcher
        watcher.start()
        startSystemCheck()
        powerChanged(resumeDeadline: resumeDeadline)
    }

    /// 켜져 있는 동안 5초마다 시스템 값을 읽어, 터미널 등 Lumen 밖에서 끈 경우를 따라간다.
    private func startSystemCheck() {
        systemCheckTimer?.invalidate()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let feature = self else { return }
            Task { @MainActor [feature] in
                await feature.followSystemValue()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        systemCheckTimer = timer
    }

    private func followSystemValue() async {
        guard let disabled = try? await SleepPolicyService.offMain({ SleepPolicyService.isSleepDisabled() }),
              !disabled, isActive, !isBusy else { return }
        stopGuards()
        isOwned = false
        isActive = false
        isSystemSleepDisabled = false
        statusHandle?.hide()
        LumenToast.show(text: "클램쉘 모드가 Lumen 밖에서 꺼졌어요")
    }

    /// 전원이 꽂혀 있으면 타이머 없이 켜 두고, 뽑혀 있으면 타이머를 건다.
    /// 잔량 변화에도 불리므로 이미 돌고 있는 타이머는 다시 걸지 않는다. 다시 꽂으면 취소돼 다음에 뽑을 때 처음부터 센다.
    private func powerChanged(resumeDeadline: Date? = nil) {
        guard isActive else { return }
        guard BatteryWatcher.isOnBattery() else {
            cancelExpiry()
            return
        }
        if expiryTimer == nil {
            scheduleExpiry(at: resumeDeadline ?? Date().addingTimeInterval(TimeInterval(batteryHours) * 3600))
        }
        checkBattery()
    }

    private func scheduleExpiry(at deadline: Date) {
        expiresAt = deadline
        let timer = Timer(timeInterval: deadline.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            guard let feature = self else { return }
            Task { @MainActor [feature] in
                feature.turnOff(toast: "전원을 뽑은 뒤 정한 시간이 지나 클램쉘 모드를 껐어요", sleepIfLidClosed: true)
            }
        }
        // 메뉴가 열려 있는 동안(eventTracking 모드)에도 만료되도록 common 모드에 건다.
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    private func cancelExpiry() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        expiresAt = nil
    }

    private func stopGuards() {
        cancelExpiry()
        systemCheckTimer?.invalidate()
        systemCheckTimer = nil
        battery?.stop()
    }

    private func checkBattery() {
        guard isActive, let percent = BatteryWatcher.percentIfOnBattery(),
              percent <= Self.minimumBatteryPercent else { return }
        turnOff(toast: "배터리가 \(Self.minimumBatteryPercent)% 이하라 클램쉘 모드를 껐어요", sleepIfLidClosed: true)
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
        'pmset -a disablesleep 0/1'과 자동으로 꺼질 때 덮개가 닫혀 있으면 재우는 'pmset sleepnow', \
        세 명령만 허용하는 규칙을 추가해요. \
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

    /// 어댑터 없이 배터리로 동작 중인지. 배터리가 없는 Mac이면 false.
    static func isOnBattery() -> Bool {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        return IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? == kIOPSBatteryPowerValue
    }

    /// 배터리로 동작 중일 때의 잔량(%). 어댑터 연결 중이거나 배터리가 없으면 nil.
    static func percentIfOnBattery() -> Int? {
        guard isOnBattery() else { return nil }
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
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
