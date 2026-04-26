import SwiftUI

/// Result-row press feedback. Selected state is rendered by the row itself
/// (amber stripe + tinted background), so this style only handles the brief
/// scale dip on press without duplicating the selected fill.
struct PressableRowStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: LumenTokens.Radius.row)
                    .fill(
                        configuration.isPressed
                            ? LumenTokens.Accent.amberDim.opacity(0.18)
                            : Color.clear
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
    }
}
