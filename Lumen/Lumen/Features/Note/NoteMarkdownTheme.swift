import SwiftUI
import MarkdownUI

extension MarkdownUI.Theme {
    static let lumen = Theme()
        .text {
            ForegroundColor(LumenTokens.TextColor.primary)
            FontSize(14)
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: 18, bottom: 8)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(20)
                    ForegroundColor(LumenTokens.Accent.violetSoft)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: 14, bottom: 6)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(15)
                    ForegroundColor(LumenTokens.Accent.violetSoft)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: 12, bottom: 4)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(14)
                    ForegroundColor(LumenTokens.Accent.violetSoft)
                }
        }
        .strong {
            FontWeight(.semibold)
            ForegroundColor(LumenTokens.TextColor.primary)
        }
        .emphasis {
            FontStyle(.italic)
            ForegroundColor(LumenTokens.TextColor.primary)
        }
        .link {
            ForegroundColor(LumenTokens.Accent.violetSoft)
            UnderlineStyle(.single)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(12.5)
            ForegroundColor(LumenTokens.Accent.violetSoft)
            BackgroundColor(LumenTokens.BG.card)
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(12.5)
                    ForegroundColor(LumenTokens.TextColor.primary)
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .background(LumenTokens.BG.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .markdownMargin(top: 6, bottom: 12)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(LumenTokens.Accent.violetSoft.opacity(0.4))
                    .frame(width: 2)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(LumenTokens.TextColor.secondary)
                        FontSize(14)
                    }
                    .padding(.leading, 12)
            }
            .markdownMargin(top: 8, bottom: 8)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 4, bottom: 4)
        }
        .thematicBreak {
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: LumenTokens.divider, location: 0.12),
                            .init(color: LumenTokens.divider, location: 0.88),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .markdownMargin(top: 14, bottom: 14)
        }
}
