import SwiftUI

private typealias P = LumenTokens.Palette

/// 일정 한 줄. 일정 목록 열, 메뉴바 오늘 일정, 날짜 팝오버가 같이 쓴다.
/// 앞에 묶음 색 점, 두 번째 줄에 출처 글과 시각·마감, 오른쪽에 우선순위 깃발과 상태 배지.
/// 누르면 상세(⌘클릭이면 Jira 댓글)를 받은 뒤 팝오버로 띄운다.
struct ScheduleItemRow: View {
    @Environment(ScheduleStore.self) private var store
    let item: ScheduleItem
    var popoverEdge: Edge = .trailing

    @State private var showingDetail = false
    @State private var variant: ScheduleDetailVariant = .primary

    var body: some View {
        Button {
            variant = isCommandClick ? .secondary : .primary
            showingDetail = true
        } label: {
            HStack(alignment: .top, spacing: LumenTokens.Space.s3) {
                LumenDot(color: store.color(for: item))
                    .padding(.top, LumenTokens.Space.scaled(9))
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .lumenText(.body, weight: .medium)
                        .foregroundStyle(item.isDone ? P.inkFaint : P.ink)
                        .strikethrough(item.isDone, color: P.inkFaint)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(secondLine)
                        .lumenText(.caption)
                        .foregroundStyle(P.inkFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack(spacing: LumenTokens.Space.inline) {
                    // 두 단계를 색만으로 가르지 않는다: 가장 높음은 글자가 붙은 배지, 높음은 깃발만.
                    switch item.priority {
                    case .urgent:
                        LumenBadge(text: "긴급", tone: .danger, icon: "flag")
                            .accessibilityLabel("우선순위 가장 높음")
                    case .high:
                        LumenIcon("flag", size: .small)
                            .foregroundStyle(P.warning)
                            .accessibilityLabel("우선순위 높음")
                    case nil:
                        EmptyView()
                    }
                    if let status = item.status {
                        LumenBadge(text: status.label, tone: status.tone, icon: status.iconName)
                    }
                }
                .frame(minHeight: LumenTextStyle.body.lineHeight)
                // 배지 글자는 줄이지 않는다. 자리가 모자라면 제목이 두 줄로 내려간다.
                .fixedSize()
            }
            .padding(.vertical, LumenTokens.Space.s3)
            .padding(.horizontal, LumenTokens.Space.s4)
            .contentShape(Rectangle())
        }
        .buttonStyle(LumenListRowStyle())
        .scheduleDetailPopover(item: item, variant: variant, isPresented: $showingDetail, arrowEdge: popoverEdge)
    }

    private var secondLine: String {
        var parts: [String] = []
        if let subtitle = item.subtitle { parts.append(subtitle) }
        parts.append(ScheduleItemFormat.shortLabel(item, relativeTo: store.now))
        if let location = item.location, !location.isEmpty { parts.append(location) }
        return parts.joined(separator: " · ")
    }
}

extension ScheduleItem.Status {
    var label: String {
        switch self {
        case .todo:       return "할 일"
        case .inProgress: return "진행 중"
        case .done:       return "완료"
        }
    }

    /// 상태는 색만으로 구분하지 않는다. 할 일은 무채색, 진행 중은 info, 완료는 success. brand는 쓰지 않는다.
    var tone: LumenTone {
        switch self {
        case .todo:       return .category
        case .inProgress: return .info
        case .done:       return .success
        }
    }

    var iconName: String {
        switch self {
        case .todo:       return "circle-dashed"
        case .inProgress: return "circle-play"
        case .done:       return "circle-check"
        }
    }
}
