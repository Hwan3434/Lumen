import AppKit

final class ColorPickerFeature: BuiltInFeature {
    let name = "컬러 피커"
    let featureDescription = "화면에서 색을 골라 HEX 값을 복사해요"
    let iconName = "pipette"
    let searchKeywords = ["컬러", "색상", "color", "picker", "스포이드", "hex", "rgb"]

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

        NSPasteboard.general.copy(hex)

        LumenToast.show(text: "\(hex)를 복사했어요", swatch: rgb)
    }
}
