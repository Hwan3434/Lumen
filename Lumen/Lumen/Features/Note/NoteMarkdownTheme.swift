import SwiftUI
import MarkdownUI

private typealias P = LumenTokens.Palette

extension MarkdownUI.Theme {
    static let lumen = Theme()
        .text {
            FontFamily(.custom("SUIT Variable"))
            ForegroundColor(P.ink)
            FontSize(LumenTextStyle.body.size)
        }
        .paragraph { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.3))
                .markdownMargin(top: 0, bottom: LumenTokens.Space.s4)
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: LumenTokens.Space.s6, bottom: LumenTokens.Space.stack)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(LumenTextStyle.title2.size)
                    ForegroundColor(P.ink)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: LumenTokens.Space.group, bottom: LumenTokens.Space.s2)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(LumenTextStyle.title3.size)
                    ForegroundColor(P.ink)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: LumenTokens.Space.s4, bottom: LumenTokens.Space.s2)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(LumenTextStyle.bodyLarge.size)
                    ForegroundColor(P.ink)
                }
        }
        .strong {
            FontWeight(.semibold)
            ForegroundColor(P.ink)
        }
        .emphasis {
            FontStyle(.italic)
            ForegroundColor(P.ink)
        }
        .link {
            ForegroundColor(P.brand)
            UnderlineStyle(.single)
        }
        .code {
            FontFamily(.custom("Geist Mono"))
            FontSize(.em(0.875))
            ForegroundColor(P.ink)
            BackgroundColor(P.surfaceRaised)
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamily(.custom("Geist Mono"))
                    FontSize(LumenTextStyle.codeBlock.size)
                    ForegroundColor(P.ink)
                }
                .padding(.vertical, LumenTokens.Space.s4)
                .padding(.horizontal, LumenTokens.Space.s5)
                .background(P.bg)
                .clipShape(LumenShape.rect(LumenTokens.Radius.md))
                .overlay(LumenShape.rect(LumenTokens.Radius.md).strokeBorder(P.borderSubtle, lineWidth: 1))
                .markdownMargin(top: 0, bottom: LumenTokens.Space.s4)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(P.borderStrong)
                    .frame(width: 2)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(P.inkMuted)
                    }
                    .padding(.leading, LumenTokens.Space.s3)
            }
            .markdownMargin(top: 0, bottom: LumenTokens.Space.s4)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: LumenTokens.Space.s1, bottom: LumenTokens.Space.s1)
        }
        .thematicBreak {
            LumenHairline()
                .markdownMargin(top: LumenTokens.Space.group, bottom: LumenTokens.Space.group)
        }
}
