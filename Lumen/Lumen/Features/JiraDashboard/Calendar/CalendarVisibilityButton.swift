import AppKit
import EventKit
import SwiftUI

/// 캘린더 헤더 [오늘] 옆에 두는 popover 트리거.
/// 클릭하면 사용 가능한 EKCalendar 목록이 펼쳐지고 항목별 토글로 즉시 disabled ID 갱신.
/// EventKitService.events가 @Observable이라 토글 시 캘린더 막대도 실시간 재렌더.
struct CalendarVisibilityButton: View {
    @State private var isOpen = false
    @State private var calendars: [EKCalendar] = []
    @State private var disabledIDs: Set<String> = []
    @State private var authStatus: EKAuthorizationStatus = .notDetermined
    @State private var iCalEnabled: Bool = false

    var body: some View {
        Button {
            reload()
            isOpen.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .medium))
                Text("캘린더")
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(LumenTokens.Accent.violetSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(LumenTokens.stroke, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            popoverBody
        }
    }

    private func reload() {
        iCalEnabled = CredentialsStore.shared.isICalEnabled
        authStatus = EKEventStore.authorizationStatus(for: .event)
        calendars = EventKitService.shared.availableCalendars()
        disabledIDs = CredentialsStore.shared.iCalDisabledCalendarIDs
    }

    @ViewBuilder
    private var popoverBody: some View {
        if calendars.isEmpty {
            emptyStateView
                .padding(16)
                .frame(width: 280)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(calendars.enumerated()), id: \.element.calendarIdentifier) { index, cal in
                    if index > 0 {
                        Rectangle().fill(LumenTokens.divider).frame(height: 0.5)
                    }
                    row(for: cal)
                }
            }
            .frame(width: 280)
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LumenTokens.TextColor.muted)
            Text(emptyTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LumenTokens.TextColor.secondary)
            Text(emptyDescription)
                .font(.system(size: 11))
                .foregroundStyle(LumenTokens.TextColor.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Text("상태: 토글=\(iCalEnabled ? "ON" : "OFF") · 권한=\(authLabel)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(LumenTokens.TextColor.muted)
                .padding(.top, 2)

            HStack(spacing: 8) {
                Button("권한 요청 / 다시 시도") {
                    Task {
                        await EventKitService.shared.requestAccessAndFetch()
                        reload()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LumenTokens.Accent.violetSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(LumenTokens.stroke, lineWidth: 0.5)
                )

                if authStatus == .denied || authStatus == .writeOnly {
                    Button("시스템 설정 열기") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LumenTokens.Accent.violetSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(LumenTokens.stroke, lineWidth: 0.5)
                    )
                }
            }
            .padding(.top, 4)
        }
    }

    private var authLabel: String {
        switch authStatus {
        case .notDetermined: return "미요청"
        case .restricted:    return "제한됨"
        case .denied:        return "거부"
        case .fullAccess:    return "전체"
        case .writeOnly:     return "쓰기전용"
        @unknown default:    return "알수없음"
        }
    }

    private var emptyTitle: String {
        if !iCalEnabled { return "iCal 연동이 꺼져 있습니다" }
        switch authStatus {
        case .notDetermined: return "캘린더 권한이 아직 요청되지 않았습니다"
        case .denied, .restricted: return "캘린더 권한이 거부되었습니다"
        case .writeOnly: return "캘린더 읽기 권한이 없습니다"
        case .fullAccess: return "표시할 캘린더가 없습니다"
        @unknown default: return "표시할 캘린더가 없습니다"
        }
    }

    private var emptyDescription: String {
        if !iCalEnabled {
            return "설정 > Jira > 캘린더 연동 토글을 켜세요."
        }
        switch authStatus {
        case .notDetermined:
            return "아래 버튼을 눌러 권한을 허용하세요."
        case .denied, .restricted, .writeOnly:
            return "시스템 설정 > 개인정보 보호 및 보안 > 캘린더에서 Lumen에 전체 접근을 허용해야 합니다."
        case .fullAccess:
            return "macOS 캘린더에 등록된 일반 캘린더가 없습니다. (휴일 전용 캘린더만 있을 수 있음)"
        @unknown default:
            return ""
        }
    }

    private func row(for cal: EKCalendar) -> some View {
        let isOn = !disabledIDs.contains(cal.calendarIdentifier)
        return HStack(spacing: 10) {
            Circle()
                .fill(Color(cgColor: cal.cgColor))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(cal.title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(LumenTokens.TextColor.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let source = cal.source?.title, !source.isEmpty {
                    Text(source)
                        .font(.system(size: 10.5))
                        .foregroundStyle(LumenTokens.TextColor.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    var next = disabledIDs
                    if newValue {
                        next.remove(cal.calendarIdentifier)
                    } else {
                        next.insert(cal.calendarIdentifier)
                    }
                    disabledIDs = next
                    EventKitService.shared.setDisabledCalendarIDs(next)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(LumenTokens.Accent.violet)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
