import AppKit
import EventKit
import SwiftUI

private typealias P = LumenTokens.Palette

/// 월간/주간 헤더 [오늘] 옆에 가로로 깔리는 캘린더 토글 스트립.
/// 권한이 없거나 연동 토글이 꺼져있으면 안내 + 액션 버튼만 인라인으로 표시.
struct CalendarVisibilityStrip: View {
    @Binding var showLocal: Bool
    @Binding var disabledProjectKeys: Set<String>
    /// 우측 종류 필터의 "캘린더" 토글 상태. OFF면 EKCalendar 칩 통째로 숨김.
    let showGoogleCalendar: Bool

    /// service를 직접 들어 @Observable 변경(disabledCalendarIDs/events)을 자동 감지 →
    /// 한 strip에서 토글해도 다른 strip의 칩 색까지 같이 갱신.
    @State private var service = EventKitService.shared
    @State private var calendars: [EKCalendar] = []
    @State private var authStatus: EKAuthorizationStatus = .notDetermined
    @State private var iCalEnabled: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LumenTokens.Space.inline) {
                FilterChip(
                    label: "내 이벤트",
                    color: CalendarItemKind.local.color,
                    isOn: $showLocal
                )

                ForEach(Constants.jiraProjects, id: \.key) { project in
                    FilterChip(
                        label: project.displayName,
                        color: jiraProjectColor(project.key),
                        isOn: projectBinding(for: project.key)
                    )
                }

                if showGoogleCalendar {
                    if calendars.isEmpty {
                        inlineEmptyState
                    } else {
                        ForEach(calendars, id: \.calendarIdentifier) { cal in
                            FilterChip(
                                label: cal.title,
                                color: Color(cgColor: cal.cgColor),
                                isOn: binding(for: cal)
                            )
                            .help(cal.source?.title ?? "")
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
        .onAppear { reload() }
    }

    private func projectBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { !disabledProjectKeys.contains(key) },
            set: { newValue in
                var next = disabledProjectKeys
                if newValue { next.remove(key) } else { next.insert(key) }
                disabledProjectKeys = next
                CredentialsStore.shared.setCalendarDisabledProjectKeys(next)
            }
        )
    }

    private func reload() {
        iCalEnabled = CredentialsStore.shared.isICalEnabled
        authStatus = EKEventStore.authorizationStatus(for: .event)
        calendars = service.availableCalendars()
    }

    private func binding(for cal: EKCalendar) -> Binding<Bool> {
        Binding(
            get: { !service.disabledCalendarIDs.contains(cal.calendarIdentifier) },
            set: { newValue in
                var next = service.disabledCalendarIDs
                if newValue {
                    next.remove(cal.calendarIdentifier)
                } else {
                    next.insert(cal.calendarIdentifier)
                }
                service.setDisabledCalendarIDs(next)
            }
        )
    }

    @ViewBuilder
    private var inlineEmptyState: some View {
        HStack(spacing: LumenTokens.Space.inline) {
            LumenIcon("calendar-off", size: .small)
                .foregroundStyle(P.inkFaint)
            Text(emptyTitle)
                .lumenText(.caption)
                .foregroundStyle(P.inkFaint)

            if iCalEnabled, authStatus != .fullAccess {
                pillButton("권한 요청") {
                    Task {
                        await EventKitService.shared.requestAccessAndFetch()
                        reload()
                    }
                }
                if authStatus == .denied || authStatus == .writeOnly {
                    pillButton("시스템 설정") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    private func pillButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))
    }

    private var emptyTitle: String {
        if !iCalEnabled { return "iCal 연동이 꺼져 있어요 (설정 > Jira)" }
        switch authStatus {
        case .notDetermined: return "캘린더 권한을 아직 요청하지 않았어요"
        case .denied, .restricted: return "캘린더 권한이 거부됐어요"
        case .writeOnly: return "캘린더를 읽을 권한이 없어요"
        case .fullAccess: return "보여줄 캘린더가 없어요"
        @unknown default: return "캘린더를 보여줄 수 없어요"
        }
    }
}
