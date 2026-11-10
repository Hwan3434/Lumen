import AppKit
import SwiftUI
@testable import Lumen

/// 스냅샷 테스트를 다른 테마·밀도·글래스로 그려 볼 때 쓰는 환경변수.
/// `TEST_RUNNER_LUMEN_SNAPSHOT_THEME=light`, `TEST_RUNNER_LUMEN_SNAPSHOT_DENSITY=compact|cozy|regular|spacious`,
/// `TEST_RUNNER_LUMEN_SNAPSHOT_GLASS=0`(0~0.8). 안 주면 다크 + 저장된 밀도·글래스 그대로다.
/// 밀도·글래스는 `LumenUIStore`의 메모리 값만 바꾼다. `.saved`에 쓰면 설치된 Lumen의 설정이 바뀐다.
@MainActor
enum SnapshotEnvironment {
    private static var env: [String: String] { ProcessInfo.processInfo.environment }

    private static var isLight: Bool { env["LUMEN_SNAPSHOT_THEME"] == "light" }
    static var appearance: NSAppearance? { NSAppearance(named: isLight ? .aqua : .darkAqua) }
    static var colorScheme: ColorScheme { isLight ? .light : .dark }

    static func applyUIOverrides() {
        if let density = env["LUMEN_SNAPSHOT_DENSITY"].flatMap(LumenDensity.init(rawValue:)) {
            LumenUIStore.shared.density = density
        }
        if let glass = env["LUMEN_SNAPSHOT_GLASS"].flatMap(Double.init) {
            LumenUIStore.shared.glassTransparency = glass
        }
    }

    static func restoreUI() {
        LumenUIStore.shared.density = LumenDensity.saved
        LumenUIStore.shared.glassTransparency = LumenGlass.saved
    }
}
