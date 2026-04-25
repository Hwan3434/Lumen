import AppKit
import Carbon.HIToolbox

final class ColorPickerFeature: BuiltInFeature {
    let name = "컬러 피커"
    let featureDescription = "화면 색상 추출 → HEX 복사"
    let iconName = "eyedropper"
    let searchKeywords = ["컬러", "색상", "color", "picker", "스포이드", "hex", "rgb"]

    var hotkeys: [HotkeySpec] {
        [
            HotkeySpec(
                keyCode: UInt16(kVK_ANSI_D),
                modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
                description: "Cmd+Shift+D",
                action: { [weak self] in
                    self?.activate()
                }
            )
        ]
    }

    private var isActive = false

    func activate() {
        guard !isActive else { return }
        isActive = true
        let sampler = NSColorSampler()
        sampler.show { [weak self] color in
            self?.isActive = false
            guard let color = color else { return }
            self?.copyColor(color)
        }
    }

    private func copyColor(_ color: NSColor) {
        guard let rgb = color.usingColorSpace(.sRGB) else { return }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        let hex = String(format: "#%02X%02X%02X", r, g, b)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
    }
}
