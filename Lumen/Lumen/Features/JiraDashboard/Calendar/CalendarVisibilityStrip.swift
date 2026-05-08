import AppKit
import EventKit
import SwiftUI

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
            HStack(spacing: 6) {
                FilterChip(
                    label: "내 이벤트",
                    color: LumenTokens.TextColor.secondary,
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
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.muted)
            Text(emptyTitle)
                .font(.system(size: 11))
                .foregroundStyle(LumenTokens.TextColor.muted)

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
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LumenTokens.Accent.violetSoft)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyTitle: String {
        if !iCalEnabled { return "iCal 연동 꺼짐 (설정 > Jira)" }
        switch authStatus {
        case .notDetermined: return "캘린더 권한 미요청"
        case .denied, .restricted: return "캘린더 권한 거부됨"
        case .writeOnly: return "캘린더 읽기 권한 없음"
        case .fullAccess: return "표시할 캘린더 없음"
        @unknown default: return "캘린더 표시 불가"
        }
    }
}
