import Foundation
import Observation

@Observable
final class HiddenAppsStore {
    @MainActor static let shared = HiddenAppsStore()

    /// 바꾸는 건 `hide`/`unhide`로만 한다. 읽기는 설정의 숨긴 앱 탭이 목록을 만들 때 쓴다.
    private(set) var hiddenIDs: Set<String>

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
