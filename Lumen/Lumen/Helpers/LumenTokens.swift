import SwiftUI

enum LumenTokens {
    enum BG {
        static let window       = Color(red: 0x16/255, green: 0x12/255, blue: 0x2A/255).opacity(0.72)
        static let windowSolid  = Color(red: 0x16/255, green: 0x12/255, blue: 0x2A/255)
        static let card         = Color.white.opacity(0.04)
        static let cardHover    = Color(red: 0xB5/255, green: 0xA8/255, blue: 0xFF/255).opacity(0.10)
        static let rowHover     = Color(red: 0xB5/255, green: 0xA8/255, blue: 0xFF/255).opacity(0.06)
        static let rowActive    = Color(red: 0xFF/255, green: 0xB4/255, blue: 0x54/255).opacity(0.10)
        static let sidePanel    = Color.white.opacity(0.02)
        static let footer       = Color.black.opacity(0.18)
    }

    enum Accent {
        static let amber       = Color(red: 0xFF/255, green: 0xB4/255, blue: 0x54/255)
        static let amberDim    = Color(red: 0xFF/255, green: 0xB4/255, blue: 0x54/255).opacity(0.55)
        static let violet      = Color(red: 0x7B/255, green: 0x6B/255, blue: 0xFF/255)
        static let violetSoft  = Color(red: 0xB5/255, green: 0xA8/255, blue: 0xFF/255)
    }

    enum TextColor {
        static let primary     = Color(red: 0xF2/255, green: 0xEE/255, blue: 0xFF/255)
        static let secondary   = Color(red: 0xB6/255, green: 0xAE/255, blue: 0xD6/255)
        static let muted       = Color(red: 0x73/255, green: 0x6C/255, blue: 0x90/255)
        static let placeholder = Color(red: 0x6E/255, green: 0x67/255, blue: 0x90/255)
    }

    static let divider       = Color.white.opacity(0.06)
    static let stroke        = Color(red: 0xB5/255, green: 0xA8/255, blue: 0xFF/255).opacity(0.10)
    static let strokeStrong  = Color(red: 0xB5/255, green: 0xA8/255, blue: 0xFF/255).opacity(0.20)

    enum Radius {
        static let window: CGFloat = 16
        static let card: CGFloat = 10
        static let row: CGFloat = 8
        static let kbd: CGFloat = 4
        static let appTile: CGFloat = 6
    }

    enum ErrorTone {
        static let title  = Color(red: 0xE1/255, green: 0xA0/255, blue: 0xA0/255)
        static let icon   = Color(red: 0xE1/255, green: 0x8A/255, blue: 0x8A/255)
        static let bg     = Color(red: 1.0, green: 90/255, blue: 90/255).opacity(0.04)
        static let border = Color(red: 1.0, green: 110/255, blue: 110/255).opacity(0.18)
    }
}

struct LumenSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.0)
            .foregroundStyle(LumenTokens.TextColor.muted)
    }
}

struct LumenKbd: View {
    let label: String
    var primary: Bool = false
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(primary ? LumenTokens.TextColor.secondary : LumenTokens.TextColor.muted)
            .padding(.horizontal, 4)
            .frame(minWidth: 16, minHeight: 16)
            .background(
                RoundedRectangle(cornerRadius: LumenTokens.Radius.kbd)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: LumenTokens.Radius.kbd)
                            .stroke(LumenTokens.stroke, lineWidth: 0.5)
                    )
            )
    }
}

/// Edge-faded hairline divider — 12% → 88% to match the design spec.
struct LumenHairline: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: LumenTokens.divider, location: 0.12),
                        .init(color: LumenTokens.divider, location: 0.88),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

/// Glass material wrapper — backdrop blur, ambient violet glow, top edge highlight.
struct LumenGlassBackground: View {
    var radius: CGFloat = LumenTokens.Radius.window

    var body: some View {
        ZStack {
            // Base material — uses .hudWindow vibrancy plus a tinted overlay so we
            // pick up the desktop without losing the violet character of the window.
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            LumenTokens.BG.window

            // Top inner highlight (1px gradient).
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.18), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 1)
                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)

            // Ambient violet glow — top-left ellipse.
            GeometryReader { geo in
                Ellipse()
                    .fill(LumenTokens.Accent.violet.opacity(0.18))
                    .frame(width: 360, height: 200)
                    .blur(radius: 60)
                    .position(x: geo.size.width * 0.35, y: -20)
            }
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(LumenTokens.strokeStrong, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.55), radius: 30, x: 0, y: 20)
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

/// NSVisualEffectView wrapper for use inside SwiftUI.
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.isEmphasized = true
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
