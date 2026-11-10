import Foundation
import Observation

@Observable
final class HiddenAppsManager {
    @MainActor static let shared = HiddenAppsManager()

    /// 외부에는 표현(Set)을 직접 노출하지 않고 함수로만 접근. SwiftUI 뷰가 변경을
    /// 감지할 수 있도록 @Observable 추적 대상으로 두되 set은 private.
    private var hiddenIDs: Set<String>

    private init() {
        hiddenIDs = LumenStorage.read(Set<String>.self, from: .hiddenApps) ?? []
    }

    func isHidden(_ bundleID: String) -> Bool {
        hiddenIDs.contains(bundleID)
    }

    func hide(_ bundleID: String) {
        guard !hiddenIDs.contains(bundleID) else { return }
        hiddenIDs.insert(bundleID)
        save()
    }

    func unhide(_ bundleID: String) {
        guard hiddenIDs.contains(bundleID) else { return }
        hiddenIDs.remove(bundleID)
        save()
    }

    private func save() {
        LumenStorage.write(hiddenIDs, to: .hiddenApps)
    }
}
