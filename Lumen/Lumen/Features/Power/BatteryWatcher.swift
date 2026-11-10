import Foundation
import IOKit.ps

/// 전원 상태 변화(어댑터 연결·해제, 잔량 변화)를 알림으로 받는다. 폴링하지 않는다.
final class BatteryWatcher {
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
