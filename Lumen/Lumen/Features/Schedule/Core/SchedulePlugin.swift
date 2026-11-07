import SwiftUI

/// 항목 상세의 두 갈래. 보통 클릭은 primary, ⌘클릭은 secondary(Jira는 댓글). 없는 플러그인은 primary를 돌려준다.
enum ScheduleDetailVariant {
    case primary, secondary
}

/// 일정을 가져오는 출처 하나. 캘린더, Jira, 내 일정이 각각 하나다.
/// 구현체는 `@Observable`이어야 한다 — 설정과 묶음이 바뀌면 화면이 바로 따라간다.
@MainActor
protocol SchedulePlugin: AnyObject, Observable {
    var id: SchedulePluginID { get }
    var displayName: String { get }
    /// Lucide 아이콘 이름.
    var iconName: String { get }
    /// 설정의 "사용". 꺼진 플러그인은 가져오지도 그리지도 않는다.
    var isEnabled: Bool { get }
    /// 묶음 목록. 표시 여부와 색 override를 함께 든다.
    var groups: [ScheduleGroup] { get }
    /// nil이면 열 때마다 새로 읽고 디스크 캐시도 두지 않는다(캘린더, 내 일정).
    var cacheTTL: TimeInterval? { get }
    /// 메뉴바의 다음 일정 라벨에 이 플러그인 항목을 올릴지.
    var contributesToMenuBarLabel: Bool { get }

    func fetch(window: DateInterval) async throws -> [ScheduleItem]
    /// 데이터가 바뀌었을 때(설정, 시스템 변경 알림, 직접 편집) 부를 콜백을 받아 둔다. 스토어가 한 번 등록한다.
    func startObserving(_ onChange: @escaping @MainActor () -> Void)
    /// 캘린더 위 칩과 설정 탭 스위치가 같이 부른다.
    func setGroupVisible(_ groupID: String, _ visible: Bool)
    /// 항목 상세. 네트워크가 필요하면 받은 뒤에 돌려준다 — macOS 팝오버는 뜬 뒤 크기가 안 바뀌기 때문이다.
    func detailView(for item: ScheduleItem,
                    accent: Color,
                    variant: ScheduleDetailVariant,
                    dismiss: @escaping @MainActor () -> Void) async throws -> AnyView
    /// 빈 날짜를 더블클릭했을 때 새 항목을 만드는 뷰. 지원하지 않으면 nil.
    func newItemView(on day: Date, dismiss: @escaping @MainActor () -> Void) -> AnyView?
    /// 켜져 있지만 사용자가 무언가 해야 가져올 수 있을 때(권한 거부 등) 목록 위에 띄울 안내. 없으면 nil.
    var setupHint: String? { get }
    /// 설정창에 탭이 있는지. 내 일정처럼 설정이 없는 플러그인은 false.
    var hasSettingsTab: Bool { get }
    /// 설정창 탭 내용. 저장 버튼 줄은 `action`으로 제어한다(즉시 반영되는 탭은 숨긴다).
    func makeSettingsTab(action: SettingsActionViewModel) -> AnyView
}

extension SchedulePlugin {
    var cacheTTL: TimeInterval? { nil }
    var contributesToMenuBarLabel: Bool { false }
    func startObserving(_ onChange: @escaping @MainActor () -> Void) {}
    func newItemView(on day: Date, dismiss: @escaping @MainActor () -> Void) -> AnyView? { nil }
    var setupHint: String? { nil }
    var hasSettingsTab: Bool { false }
    func makeSettingsTab(action: SettingsActionViewModel) -> AnyView { AnyView(EmptyView()) }
}
