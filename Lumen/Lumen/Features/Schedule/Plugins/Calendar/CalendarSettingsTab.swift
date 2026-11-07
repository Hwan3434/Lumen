import AppKit
import EventKit
import SwiftUI

private typealias P = LumenTokens.Palette

/// 설정 › 일정 › 캘린더. 사용, 권한, 보여줄 캘린더, 색, 메뉴바. 모두 고르는 즉시 반영된다.
struct CalendarSettingsTab: View {
    let plugin: CalendarPlugin
    let action: SettingsActionViewModel

    @State private var store = ScheduleStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LumenTokens.Space.s7) {
                SettingsSection(title: "캘린더") {
                    SwitchRow(
                        on: Binding(get: { plugin.settings.enabled }, set: { plugin.setEnabled($0) }),
                        title: "사용",
                        description: "macOS 캘린더 앱에 연결된 일정을 보여줘요. Google 캘린더는 시스템 설정의 [인터넷 계정]에서 연결해 주세요."
                    )
                }

                if plugin.settings.enabled {
                    SettingsSection(title: "권한") {
                        permissionCard
                    }

                    SettingsSection(title: "보여줄 캘린더") {
                        if plugin.calendars.isEmpty {
                            emptyCard(text: plugin.authorizationStatus == .fullAccess
                                      ? "읽을 수 있는 캘린더가 없어요"
                                      : "캘린더 권한을 허용하면 목록이 나와요")
                        } else {
                            LumenList(data: plugin.calendars, id: \.calendarIdentifier) { cal in
                                calendarRow(cal)
                            }
                        }
                        SwitchRow(
                            on: Binding(get: { plugin.settings.useAppColors }, set: { plugin.setUseAppColors($0) }),
                            title: "캘린더 앱의 색 그대로 쓰기",
                            description: "끄면 켠 캘린더 순서대로 Still 차트 색을 써요. 켜면 캘린더 앱에서 정한 색이 그대로 보여요."
                        )
                        Text("켠 캘린더는 캘린더 위 칩에서도 켜고 끌 수 있어요. 공휴일은 Lumen이 따로 표시하니 겹치면 공휴일 캘린더를 꺼 주세요.")
                            .lumenText(.caption)
                            .foregroundStyle(P.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    SettingsSection(title: "메뉴바") {
                        SwitchRow(
                            on: Binding(get: { plugin.settings.inMenuBar }, set: { plugin.setInMenuBar($0) }),
                            title: "메뉴바 라벨에 포함",
                            description: "메뉴바의 다음 일정 라벨에 이 캘린더들의 일정을 올려요. 라벨 자체를 끄는 건 [대시보드] 탭에 있어요."
                        )
                    }
                }
            }
            .padding(LumenTokens.Space.s6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            // 토글이 곧 저장이라 저장 버튼 줄은 숨긴다.
            action.hidden = true
            action.dirty = false
            action.saved = false
        }
    }

    // MARK: - 권한

    @ViewBuilder
    private var permissionCard: some View {
        HStack(spacing: LumenTokens.Space.s3) {
            switch plugin.authorizationStatus {
            case .fullAccess:
                LumenBadge(text: "전체 접근 허용됨", tone: .success)
                Text("캘린더 \(plugin.calendars.count)개를 읽을 수 있어요.")
                    .lumenText(.label, weight: .regular)
                    .foregroundStyle(P.inkMuted)
            case .notDetermined:
                LumenBadge(text: "아직 요청하지 않았어요", tone: .category)
                Spacer(minLength: 0)
                Button("권한 요청") {
                    Task { await plugin.requestAccessIfNeeded() }
                }
                .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))
            default:
                LumenBadge(text: "읽을 권한이 없어요", tone: .danger)
                Text("시스템 설정 › 개인정보 보호 › 캘린더에서 Lumen을 켜 주세요.")
                    .lumenText(.label, weight: .regular)
                    .foregroundStyle(P.inkMuted)
                Spacer(minLength: 0)
                Button("시스템 설정 열기") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(LumenButtonStyle(variant: .secondary, size: .small))
            }
            if plugin.authorizationStatus == .fullAccess { Spacer(minLength: 0) }
        }
        .padding(LumenTokens.Space.pad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenCard()
    }

    // MARK: - 캘린더 목록

    private func calendarRow(_ cal: EKCalendar) -> some View {
        let key = ScheduleGroupKey(plugin: plugin.id, group: cal.calendarIdentifier)
        let isOn = !plugin.settings.hiddenCalendarIDs.contains(cal.calendarIdentifier)
        return Toggle(isOn: Binding(
            get: { isOn },
            set: { plugin.setGroupVisible(cal.calendarIdentifier, $0) }
        )) {
            HStack(spacing: LumenTokens.Space.s3) {
                LumenDot(color: store.groupColors[key] ?? P.chartOther)
                VStack(alignment: .leading, spacing: 0) {
                    Text(cal.title)
                        .lumenText(.body, weight: .medium)
                        .foregroundStyle(isOn ? P.ink : P.inkMuted)
                        .lineLimit(1)
                    if let source = cal.source?.title, !source.isEmpty {
                        Text(source)
                            .lumenText(.caption)
                            .foregroundStyle(P.inkFaint)
                            .lineLimit(1)
                    }
                }
            }
        }
        .toggleStyle(LumenSwitchStyle())
        .padding(.vertical, LumenTokens.Space.s3)
        .padding(.horizontal, LumenTokens.Space.s4)
    }

    private func emptyCard(text: String) -> some View {
        HStack(spacing: LumenTokens.Space.s3) {
            LumenIcon("calendar-off")
                .foregroundStyle(P.inkMuted)
            Text(text)
                .lumenText(.body)
                .foregroundStyle(P.inkMuted)
            Spacer()
        }
        .padding(.vertical, LumenTokens.Space.scaled(14))
        .padding(.horizontal, LumenTokens.Space.s4)
        .lumenCard()
    }
}
