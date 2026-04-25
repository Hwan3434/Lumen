import SwiftUI

struct PressableRowStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        configuration.isPressed
                            ? Color.blue.opacity(0.5)
                            : isSelected
                                ? Color.blue.opacity(0.3)
                                : Color.clear
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}
