import SwiftUI

// Still 컴포넌트 명세(project/components/*/README.md)를 SwiftUI로 옮긴 공용 부품.

private typealias P = LumenTokens.Palette

// MARK: - Status tone (Badge, Banner, Toast)

enum LumenTone {
    case category, success, warning, danger, info

    var color: Color {
        switch self {
        case .category: P.inkMuted
        case .success: P.success
        case .warning: P.warning
        case .danger: P.danger
        case .info: P.info
        }
    }

    var soft: Color {
        switch self {
        case .category: .clear
        case .success: P.successSoft
        case .warning: P.warningSoft
        case .danger: P.dangerSoft
        case .info: P.infoSoft
        }
    }

    /// 상태는 색만으로 구분하지 않는다: 체크, 경고 삼각형, 원 안의 X, 원 안의 i.
    var icon: String? {
        switch self {
        case .success: "circle-check"
        case .warning: "triangle-alert"
        case .danger: "circle-x"
        case .info: "info"
        case .category: nil
        }
    }
}

struct LumenBadge: View {
    let text: String
    var tone: LumenTone = .category
    /// 상태 톤의 기본 아이콘 대신 쓸 아이콘.
    var icon: String? = nil

    var body: some View {
        HStack(spacing: LumenTokens.Space.s1) {
            if let name = icon ?? tone.icon {
                LumenIcon(name, size: .small)
            }
            Text(text)
                .lumenText(.caption, weight: .semibold)
                .lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.vertical, LumenTokens.Space.scaled(4))
        .padding(.horizontal, LumenTokens.Space.scaled(8))
        .background(tone.soft, in: LumenShape.rect(LumenTokens.Radius.xs))
        .overlay {
            if tone == .category {
                LumenShape.rect(LumenTokens.Radius.xs).strokeBorder(P.borderSubtle, lineWidth: 1)
            }
        }
    }
}

struct LumenBanner<Action: View>: View {
    let tone: LumenTone
    let title: String
    var message: String? = nil
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: LumenTokens.Space.s3) {
            if let icon = tone.icon {
                LumenIcon(icon).foregroundStyle(tone.color)
            }
            VStack(alignment: .leading, spacing: LumenTokens.Space.s1) {
                Text(title)
                    .lumenText(.label, weight: .semibold)
                    .foregroundStyle(P.ink)
                if let message {
                    Text(message)
                        .lumenText(.label, weight: .regular)
                        .foregroundStyle(P.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                action()
                    .padding(.top, LumenTokens.Space.s1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, LumenTokens.Space.scaled(14))
        .padding(.horizontal, LumenTokens.Space.scaled(16))
        .background(tone.soft, in: LumenShape.rect(LumenTokens.Radius.md))
        .accessibilityElement(children: .combine)
    }
}

extension LumenBanner where Action == EmptyView {
    init(tone: LumenTone, title: String, message: String? = nil) {
        self.init(tone: tone, title: title, message: message, action: { EmptyView() })
    }
}

// MARK: - Dot

/// 계열 색 표식(지름 8). 차트 범례, 프로젝트·캘린더 구분처럼 색으로 계열을 알릴 때만 쓴다.
struct LumenDot: View {
    let color: Color

    private static var side: CGFloat { LumenDensity.current.pick(compact: 6, cozy: 8, regular: 8, spacious: 8) }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: Self.side, height: Self.side)
    }
}
