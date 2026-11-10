import Foundation
import Observation

struct MagnetOption {
    let label: String
    let direction: WindowMagnetService.Direction
    let ratio: CGFloat
}

@Observable
final class WindowMagnetViewModel {
    var selectedIndex = 0

    let options: [MagnetOption] =
        Constants.magnetSteps.map { MagnetOption(label: "← 왼쪽 \(Int(($0 * 100).rounded()))%", direction: .left, ratio: $0) }
        + Constants.magnetSteps.map { MagnetOption(label: "→ 오른쪽 \(Int(($0 * 100).rounded()))%", direction: .right, ratio: $0) }

    func moveUp() {
        if selectedIndex > 0 { selectedIndex -= 1 }
    }

    func moveDown() {
        if selectedIndex < options.count - 1 { selectedIndex += 1 }
    }

    var selectedOption: MagnetOption {
        options[selectedIndex]
    }
}
