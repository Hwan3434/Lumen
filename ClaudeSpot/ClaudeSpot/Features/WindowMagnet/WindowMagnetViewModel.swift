import Foundation
import Observation

struct MagnetOption {
    let label: String
    let direction: WindowMagnetManager.Direction
    let ratio: CGFloat
}

@Observable
final class WindowMagnetViewModel {
    var selectedIndex = 0

    let options: [MagnetOption] = [
        MagnetOption(label: "← 왼쪽 20%", direction: .left, ratio: 0.2),
        MagnetOption(label: "← 왼쪽 40%", direction: .left, ratio: 0.4),
        MagnetOption(label: "← 왼쪽 60%", direction: .left, ratio: 0.6),
        MagnetOption(label: "← 왼쪽 80%", direction: .left, ratio: 0.8),
        MagnetOption(label: "← 왼쪽 100%", direction: .left, ratio: 1.0),
        MagnetOption(label: "→ 오른쪽 20%", direction: .right, ratio: 0.2),
        MagnetOption(label: "→ 오른쪽 40%", direction: .right, ratio: 0.4),
        MagnetOption(label: "→ 오른쪽 60%", direction: .right, ratio: 0.6),
        MagnetOption(label: "→ 오른쪽 80%", direction: .right, ratio: 0.8),
        MagnetOption(label: "→ 오른쪽 100%", direction: .right, ratio: 1.0),
    ]

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
