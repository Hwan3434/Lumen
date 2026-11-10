# 일정 플러그인 추가하기

일정 대시보드(⌘⇧G)는 일정을 가져오는 출처를 **플러그인**으로 붙입니다. 지금 있는 플러그인은 캘린더(EventKit), Jira, 내 일정 셋입니다. Linear, Monday, Trello 같은 출처도 같은 방식으로 붙이면 됩니다. 이 문서는 무엇을 어디에 추가하는지만 적습니다.

## 1. 구조 한눈에

모든 코드는 `Lumen/Lumen/Features/Schedule/` 아래에 있습니다. Xcode 프로젝트가 폴더 동기화 방식이라 새 파일을 만들면 타겟에 자동으로 들어갑니다(`project.pbxproj`를 고치지 않습니다).

| 파일 | 역할 |
|---|---|
| `Core/ScheduleItem.swift` | 모든 플러그인이 내놓는 일정 한 줄(`ScheduleItem`)과 묶음(`ScheduleGroup`), 식별자 타입(`SchedulePluginID`) |
| `Core/SchedulePlugin.swift` | 플러그인 프로토콜 |
| `Core/SchedulePlugins.swift` | 등록 목록. 순서가 곧 칩 순서이고 색 순서 |
| `Core/ScheduleStore.swift` | 플러그인 상태를 합치고 색·갱신·캐시·시계를 맡음 |
| `Core/ScheduleCache.swift` | 플러그인별 디스크 캐시. `cacheTTL`이 있는 플러그인만 스토어가 대신 읽고 씁니다 |
| `Core/PluginSettings.swift` | 비민감 설정(`PluginSettings`)과 민감값(`PluginSecrets`) 저장 |
| `Core/DashboardSettings.swift` | 플러그인에 속하지 않는 대시보드 공통 설정(메뉴바 라벨, 기본 보기, 주 시작 요일) |
| `Plugins/<이름>/` | 플러그인 하나의 구현, 설정 탭, 상세 팝오버 |

**묶음**은 색 하나를 받는 단위입니다. 캘린더 하나, Jira 프로젝트 하나가 각각 묶음입니다. 묶음 색은 스토어가 Still 차트 색(`chart1`부터)을 켜진 플러그인 순서대로 배정하므로 보통은 플러그인이 색을 고르지 않습니다. 출처가 정한 색을 그대로 써야 하면 묶음의 `customColor`에 넣습니다(캘린더의 "캘린더 앱의 색 그대로 쓰기"). 그런 묶음은 차트 색 자리를 차지하지 않습니다.

## 2. 새 플러그인을 붙이는 순서 (Linear 예)

### 2-1. 식별자 한 줄

플러그인 파일(`Plugins/Linear/LinearPlugin.swift`) 맨 위에 둡니다. 코어 파일은 고치지 않습니다.

```swift
nonisolated extension SchedulePluginID {
    static let linear = SchedulePluginID("linear")
}
```

`nonisolated`를 빼면 이 값이 메인 액터에 묶여, 항목을 만드는 `nonisolated static` 함수에서 쓸 때 컴파일 경고가 납니다(빌드해서 확인함).

이 값은 설정 키(`schedule.linear`), 민감값 키 앞머리(`linear.`), 캐시 파일 이름(`schedule_cache/linear.json`)에 그대로 쓰입니다.

### 2-2. 파일 셋

`Plugins/Linear/` 폴더를 만들고 아래 셋을 둡니다. Jira 플러그인(`Plugins/Jira/`)이 가장 가까운 견본입니다.

| 파일 | 할 일 |
|---|---|
| `LinearRepository.swift` | API 호출만. `actor`로 만들고 자격증명은 생성자로 받습니다. 응답을 플러그인 전용 모델(이슈, 사이클 등)로 바꿉니다. 페이지를 넘기는 규칙과 응답 해석은 네트워크와 분리한 `static` 함수로 두고 샘플 JSON으로 테스트합니다(`JiraRepository.collectIssues` 참고). |
| `LinearPlugin.swift` | `@Observable @MainActor final class LinearPlugin: SchedulePlugin`. 설정 구조체, 묶음, `fetch`, 상세 뷰, 설정 탭 연결. 전용 모델을 `ScheduleItem`으로 바꾸는 함수는 `nonisolated static`으로 두고 테스트합니다. |
| `LinearSettingsTab.swift` | 설정창 탭. 사용 스위치, 자격증명 입력과 [연결 확인], 가져올 항목. |

### 2-3. 등록 한 줄

`Core/SchedulePlugins.swift`의 `all`에 넣습니다. 넣은 위치가 칩과 색 순서를 정합니다.

```swift
static let all: [any SchedulePlugin] = [
    CalendarPlugin.shared,
    JiraPlugin.shared,
    LinearPlugin.shared,
    LocalPlugin.shared,
]
```

설정창 "일정" 섹션의 탭은 이 목록에서 `hasSettingsTab`이 true인 플러그인을 순서대로 보여 주므로 따로 등록할 곳이 없습니다.

## 3. 프로토콜에서 정할 것

| 멤버 | 뜻 | 기본값 |
|---|---|---|
| `id`, `displayName`, `iconName` | 식별자, 칩·설정 탭 이름, Lucide 아이콘 이름 | 없음 |
| `isEnabled` | 설정의 "사용". 꺼지면 가져오지도 그리지도 않고 캐시도 지웁니다 | 없음 |
| `groups` | 묶음 목록과 표시 여부. 칩과 설정 탭 스위치가 같이 씁니다 | 없음 |
| `fetch(window:)` | 오늘 앞뒤 90일 범위의 항목을 돌려줍니다. 숨긴 묶음의 항목도 함께 돌려줍니다(칩을 켜고 끌 때 다시 받지 않기 위해서입니다). 실패하면 던지세요. 스토어가 마지막 데이터를 유지하고 목록 위에 오류 배너를 띄웁니다 | 없음 |
| `setGroupVisible(_:_:)` | 묶음 표시 여부를 설정 구조체에 저장합니다. 저장만 하고 `startObserving`의 콜백은 부르지 않습니다 | 없음 |
| `detailView(for:accent:variant:dismiss:)` | 항목을 눌렀을 때의 팝오버. 네트워크가 필요하면 받은 **뒤에** 돌려줍니다(macOS 팝오버는 뜬 뒤 크기가 안 바뀝니다). `.secondary`는 ⌘클릭입니다. nil을 돌려주면 스토어가 기본 미리보기(`ScheduleItemPreview`)를 띄웁니다 | nil |
| `cacheTTL` | 네트워크 출처면 초 단위 TTL(Jira는 1800). nil이면 열 때마다 읽고 디스크 캐시도 두지 않습니다 | nil |
| `contributesToMenuBarLabel` | 메뉴바의 다음 일정 라벨에 올릴지. 앱을 켤 때 이 플러그인만 미리 받습니다 | false |
| `startObserving(_:)` | 설정 저장, 시스템 변경 알림 등으로 다시 받아야 할 때 부를 콜백을 받아 둡니다 | 아무것도 안 함 |
| `setupHint` | 켜져 있지만 사용자가 할 일이 있을 때(권한 거부) 목록 위에 띄울 한 문장 | nil |
| `newItemView(on:dismiss:)` | 빈 날짜 더블클릭·⌘N으로 새 항목을 만들 수 있으면 그 뷰 | nil |
| `hasSettingsTab`, `makeSettingsTab(action:)` | 설정창 탭. 즉시 반영되는 탭은 `action.hideActionBar()`로 저장 버튼 줄을 숨깁니다 | 탭 없음 |

### 가져오기에서 지킬 것

- **잘린 결과를 성공으로 돌려주지 않습니다.** 페이지를 넘기다 중간 응답이 깨지면 모은 데까지 돌려주지 말고 던집니다. 돌려주면 스토어가 그 목록을 성공으로 보고 캐시까지 덮어씁니다.
- **부가 정보 조회의 실패를 전부 삼키지 않습니다.** Jira의 스프린트·에픽처럼 없어도 되는 조회라도 인증 실패(401), 요청 제한(429), 서버 오류(5xx), 네트워크 오류는 던집니다. "이 프로젝트엔 없다"에 해당하는 나머지 실패만 로그를 남기고 넘어갑니다(`JiraRepository.failsRefresh`).
- **조회 중에 설정이 바뀌는 경우는 스토어가 처리합니다.** 조회가 도는 중에 `startObserving`의 콜백이 불리면 스토어가 끝난 뒤 한 번 더 받습니다. 플러그인은 `fetch`를 시작할 때 설정을 읽기만 하면 됩니다.

## 4. 항목 만들기 규칙

- `id`는 `"linear.<출처 고유 id>"`처럼 플러그인 이름을 앞에 붙여 다른 플러그인과 겹치지 않게 합니다. 반복 일정처럼 같은 id가 여러 번 나오면 시작 시각을 붙입니다(캘린더 플러그인 참고). 같은 것이 묶음마다 한 번씩 나올 수 있으면 묶음 id도 넣습니다(Jira 스프린트는 `jira.sprint.<프로젝트 키>.<id>`). id가 겹치면 달력 막대가 잘못 그려집니다.
- `end`는 **포함하는 마지막 날**입니다. 종일 항목은 마지막 날 0시, 하루짜리는 nil로 둡니다. 출처가 "다음 날 0시"를 끝으로 주면 플러그인이 바꿉니다(`CalendarPlugin.makeItem`). 시간 일정(`isAllDay == false`)의 끝은 실제 끝 시각을 그대로 넣습니다. 자정에 끝나는 일정이 다음 날로 넘어가지 않게 하는 일은 `ScheduleItem.lastDay`가 합니다.
- `group`은 `groups`의 묶음 id 중 하나여야 합니다. 없는 묶음의 항목은 보이지 않습니다.
- `kind`는 셋 중 하나입니다.
  - `.event`: 시간을 차지하는 일정. 목록에서 오늘 이후 처음 걸치는 날로 묶입니다.
  - `.task`: 마감형 일. 마감일(`end ?? start`)로 묶이고, 지나면 "지난 기한"에 갑니다.
  - `.span`: 스프린트·사이클 같은 기간. 캘린더 막대로만 보이고 목록에는 안 나옵니다.
- `isAllDay`가 false면 막대 앞에 시각이 붙습니다. 날짜만 있는 출처는 true로 둡니다.
- `status`(할 일 / 진행 중 / 완료)와 `priority`(가장 높음 / 높음)는 출처의 분류를 이 셋·둘로 줄여 넣습니다. 보통·낮음은 nil입니다. 완료 항목을 기본으로 숨길지는 플러그인 설정으로 둡니다(Jira의 `showDone`).
- `subtitle`은 목록 두 번째 줄 앞부분입니다(이슈 키, 캘린더 이름). `url`이 있으면 기본 미리보기에 [열기] 버튼이 붙습니다. 상세 뷰를 직접 만드는 플러그인은 `PreviewOpenFooter(label:url:)`를 footer에 넣습니다.

## 5. 설정과 자격증명

- 비민감 설정은 Codable 구조체 하나로 만들고 `PluginSettings.load(.linear, default:)` / `PluginSettings.save(_:for:)`로 읽고 씁니다. 사용 여부, 묶음 목록과 표시 여부, 가져올 항목 스위치를 여기 둡니다.
- 토큰 같은 민감값은 `PluginSecrets(plugin: .linear)`로 읽고 씁니다. `~/Library/Application Support/Lumen/secrets.dat`에 `linear.apiToken` 같은 키로 들어갑니다. 이 파일은 암호화가 아니라 기기 UUID XOR 난독화와 0600 권한에 기대므로, 코드나 로그에 값을 남기지 않습니다.
- 자격증명을 저장하면 저장소(`LinearRepository`)를 새로 만들고 `startObserving`으로 받은 콜백을 불러 즉시 다시 받게 합니다. 앱 재시작이 필요 없어야 합니다.

## 6. 테스트

- 전용 모델을 `ScheduleItem`으로 바꾸는 순수 함수를 `LumenTests/`에서 확인합니다(`ParserAndModelTests.testJiraPluginBuildsItems` 참고).
- 화면은 `LumenTests/ScheduleTestSupport.swift`의 `FakeSchedulePlugin`으로 네트워크 없이 그려 볼 수 있습니다(`ScheduleSnapshotTests` 참고).

```bash
xcodebuild test -project Lumen/Lumen.xcodeproj -scheme Lumen -destination 'platform=macOS'
```
