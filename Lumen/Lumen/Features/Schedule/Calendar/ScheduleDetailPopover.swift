import AppKit
import SwiftUI

/// 클릭 시점의 ⌘ 여부. 항목을 여는 지점이 월간·주간·오늘 일정으로 흩어져 있어
/// 각 호출부에서 제스처를 새로 짜는 대신 클릭 순간의 수정자 플래그를 읽는다.
@MainActor
var isCommandClick: Bool {
    NSEvent.modifierFlags.contains(.command)
}

// 항목 상세 팝오버를 **데이터를 받은 뒤에** 띄우는 modifier.
//
// macOS SwiftUI popover는 표시되는 순간 크기가 고정되고, 그 뒤 내용이 커져도 창이 따라
// 자라지 않는다. 그래서 로딩 상태로 먼저 띄우면 본문이 도착해도 로딩 크기에 갇힌다.
// 내용에 맞춰 크기가 정해지려면 뜨는 시점에 이미 내용이 있어야 한다. 그래서 클릭 →
// 플러그인에 상세 요청 → (도착하면) 표시 순서로 간다. 캘린더·내 일정은 바로 돌아오고,
// Jira는 네트워크 왕복이 보이는 대신 플러그인이 짧게 캐시해 같은 이슈를 다시 열 때는 즉시 뜬다.

extension View {
    /// `isPresented`가 true가 되면 상세를 요청하고, 도착한 뒤에 뜬다.
    func scheduleDetailPopover(item: ScheduleItem?,
                               variant: ScheduleDetailVariant = .primary,
                               isPresented: Binding<Bool>,
                               arrowEdge: Edge = .top) -> some View {
        modifier(ScheduleDetailPopoverModifier(item: item, variant: variant,
                                               isRequested: isPresented, arrowEdge: arrowEdge))
    }
}

extension View {
    /// 빈 날짜 더블클릭·⌘N으로 뜨는 새 항목 팝오버. `selection`이 `day`와 같은 날이면 뜬다.
    func newItemPopover(day: Date, selection: Binding<Date?>, arrowEdge: Edge) -> some View {
        modifier(NewItemPopoverModifier(day: day, selection: selection, arrowEdge: arrowEdge))
    }
}

private struct NewItemPopoverModifier: ViewModifier {
    @Environment(ScheduleStore.self) private var store

    let day: Date
    @Binding var selection: Date?
    let arrowEdge: Edge

    func body(content: Content) -> some View {
        content.popover(isPresented: Binding(
            get: { selection.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false },
            set: { if !$0 { selection = nil } }
        ), arrowEdge: arrowEdge) {
            if let view = store.newItemView(on: day, dismiss: { selection = nil }) {
                view
            }
        }
    }
}

private struct ScheduleDetailPopoverModifier: ViewModifier {
    @Environment(ScheduleStore.self) private var store

    let item: ScheduleItem?
    let variant: ScheduleDetailVariant
    @Binding var isRequested: Bool
    let arrowEdge: Edge

    @State private var content: AnyView?
    @State private var errorMessage: String?
    @State private var isShowing = false
    @State private var loadingID: String?

    func body(content: Content) -> some View {
        content
            .popover(isPresented: $isShowing, arrowEdge: arrowEdge) { popoverContent }
            .onChange(of: isRequested) { _, requested in
                if requested {
                    load()
                } else {
                    isShowing = false
                }
            }
            .onChange(of: isShowing) { _, showing in
                // 팝오버를 닫으면 호출부 상태도 정리한다. 다음 클릭이 다시 조회를 걸도록.
                if !showing {
                    isRequested = false
                    self.content = nil
                    errorMessage = nil
                }
            }
    }

    @ViewBuilder
    private var popoverContent: some View {
        if let content {
            content
        } else {
            VStack(alignment: .leading, spacing: LumenTokens.Space.stack) {
                Text(item?.subtitle ?? item?.title ?? "")
                    .font(LumenFont.mono(LumenTextStyle.caption.size, .medium))
                    .foregroundStyle(LumenTokens.Palette.inkMuted)
                LumenBanner(tone: .danger, title: "내용을 불러오지 못했어요", message: errorMessage)
            }
            .padding(LumenTokens.Space.pad)
            .frame(width: CalendarPreviewMetrics.width, alignment: .leading)
            .background(LumenTokens.Palette.surfaceRaised)
        }
    }

    private func load() {
        guard let item else { return }
        // 조회 중 같은 대상을 다시 누르면 무시 — 두 번 받아올 이유가 없다.
        guard loadingID != item.id else { return }
        loadingID = item.id

        Task { @MainActor in
            defer { loadingID = nil }
            do {
                content = try await store.detailView(for: item, variant: variant) { isShowing = false }
                errorMessage = nil
            } catch {
                content = nil
                errorMessage = error.networkErrorMessage
            }
            // 그 사이 사용자가 다른 곳을 눌러 요청이 취소됐으면 띄우지 않는다.
            guard isRequested else { return }
            isShowing = true
        }
    }
}
