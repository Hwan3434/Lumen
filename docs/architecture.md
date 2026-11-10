# 앱 구조

Lumen이 어떻게 짜여 있는지 적는다. 왜 그렇게 정했는지는 [decisions.md](decisions.md), 조심할 곳은 [pitfalls.md](pitfalls.md)에 있다. 경로는 모두 `Lumen/Lumen/` 기준이다.

## 의존 방향

`Features/`는 `Search/`, `Services/`, `Core/`, `DesignSystem/`, `Helpers/`를 쓸 수 있다. 반대로 `Features/` 밖의 폴더는 `Features/` 안의 타입 이름을 부르지 않는다. 예외는 조립하는 곳 두 군데뿐이다. `AppDelegate.swift`(기능 목록)와 `LumenApp.swift`(`SettingsView`).

검색 패널이 특정 기능을 알아야 할 것 같으면 프로토콜에 선택 멤버를 더한다. 클램쉘 모드의 끄기 시간 줄이 그 예다(`ToggleableFeature.detailAccessory`).

## 시작과 종료

`AppDelegate.applicationDidFinishLaunching` 순서:

1. 글꼴 등록(`LumenFont.register()`)과 테마 적용. 스냅샷 테스트도 쓰므로 테스트 가드보다 앞에 있다.
2. XCTest 아래면 여기서 멈춘다(`isRunningTests`). 아래 작업은 설치된 Lumen의 상태를 건드리기 때문이다.
3. 제거된 기능이 남긴 파일 정리(`LumenStorage.purgeRetiredFilesIfNeeded`).
4. 기능 배열을 순서대로 `FeatureRegistry.shared.register`. 등록하면서 각 기능의 `setup()`이 불린다. 배열 순서가 검색 기본 목록과 메뉴바 메뉴의 순서다.
5. 단축키 등록. 앱 전역 두 개(검색 ⌘Space, 포커스 복귀 ⌘⇧L)는 `Core/Hotkeys/HotkeyDefinitions.swift`, 나머지는 각 기능의 `hotkeys`. 등록에 실패한 조합은 토스트로 한 번 알린다.
6. 환율 캐시 갱신, `AppStatusBar` 생성, 각 기능의 `attachStatusBar`.
7. 창 옵저버 두 개. 패널이 아닌 창(설정 창 등)이 키 창이 되면 떠 있는 패널을 모두 내린다. Sparkle 창(클래스 이름이 `SP`/`SU`로 시작), alert, popover, 패널의 자식 창은 예외다.

종료(`applicationWillTerminate`)는 단축키 해제, `FeatureRegistry.teardownAll()`, 메뉴바 정리 순서다. `teardown()`은 동기로 끝나야 한다. 프로세스가 곧 사라지므로 `Task`로 넘긴 일은 끝나지 않는다(노트 저장, 클램쉘 모드 끄기).

## 기능 (`BuiltInFeature`)

`Core/BuiltInFeature.swift`의 프로토콜 하나가 기능의 전부다.

- `name`, `featureDescription`, `searchKeywords`, `iconName`(Lucide 이름): 검색 목록과 메뉴바 메뉴에 쓰인다.
- `activate()`: 검색에서 고르거나 메뉴에서 눌렀을 때. 보통 패널 `toggle()`.
- `setup()`: 등록 때 한 번. 기능 고유의 시작 작업(클립보드 감시 시작, 손쉬운 사용 권한 요청, 클램쉘 복구)은 `AppDelegate`가 아니라 여기에 둔다.
- `hotkeys`: 등록 때 한 번 읽는다. `kVK_*`를 그 자리에 적는다.
- `attachStatusBar(_:)`: 메뉴바 아이콘이 필요하면 `StatusBarCoordinator.addItem`으로 받는다. `NSStatusBar.system`을 직접 만지지 않는다.
- `teardown()`: 종료 때.

창을 여는 대신 켜고 끄는 기능(카페인, 클램쉘 모드)은 `ToggleableFeature`다. `@Observable`이어야 검색 상세 칸의 스위치가 상태를 따라간다.

`isEnabled`는 프로토콜에 있지만 지금은 모든 기능이 true다.

## 패널 (`PanelWindowController`, `KeyablePanel`)

떠 있는 창은 모두 `Core/Window/PanelWindowController.swift`를 상속한 컨트롤러가 만든다.

- **처음 열 때 한 번 만들고 계속 살려 둔다**(`isReleasedWhenClosed = false`). 뷰 모델도 살아 있으므로, 열 때마다 초기화할 상태는 `configureBeforeShow`에서, 닫을 때 치울 것은 `willHide()`에서 다룬다.
- 훅 순서: 처음 열 때 `createPanel()`과 `didCreatePanel`이 한 번 불린다. 열 때마다 `configureBeforeShow`, 화면에 뜬 뒤 `didShow`가 불린다. 닫힐 때는 `willHide()`.
- `willHide()`는 `KeyablePanel.orderOut`에서 불린다. 컨트롤러의 `hide()`를 거치지 않고 닫히는 경로(설정 창이 떠서 내려가는 경우)도 있기 때문이다. 직접 부르지 않는다.
- 패널은 `.nonactivatingPanel`이다. 키 입력은 `KeyablePanel.onKeyEvent`(키 코드만)와 `onCommandKey`(⌘ 조합)가 첫 응답자보다 먼저 받는다. true를 돌려주면 그 키는 텍스트 칸에 가지 않는다. 창 끌기는 `WindowDragArea`나 `LumenPanelHeader`가 맡는다.
- 한 번에 하나만 뜬다(`isExclusive`). 노트만 false라서 다른 패널 옆에 같이 뜬다.
- 크기는 `Helpers/WindowMetrics.swift`의 `Constants.<이름>WindowSize`이고 밀도마다 다르다. 밀도가 바뀌면 `densityContentSize`를 준 패널만 `applyDensityToPanels()`가 다시 맞춘다.
- 위치는 `centerUnderMouse`. 열 때마다 가운데로 오는 패널은 `configureBeforeShow`에서, 사용자가 옮긴 자리를 기억하는 패널(노트, 일정)은 `didCreatePanel`에서 부른다.
- 패널 뷰의 루트는 `.lumenPanel()`로 끝난다([DESIGN.md](../DESIGN.md)).

설정 창은 패널이 아니다. SwiftUI `Settings` 장면(`LumenApp.swift`)이고, 탭은 `Features/Settings/SettingsView.swift`의 `Tab`에 있다. 일정 플러그인 탭은 `SchedulePlugins.all`에서 자동으로 나온다.

## 메뉴바

- `Core/AppStatusBar.swift`: Lumen 아이콘과 메뉴(기능 목록, 로그인 시 시작, 업데이트 확인, 종료). 로그인 항목 체크는 열 때마다 `SMAppService.mainApp.status`를 읽는다.
- `Core/StatusBarCoordinator.swift`: 기능이 요청한 추가 아이콘(카페인, 클램쉘 모드, 일정 라벨)을 만들고 종료 때 지운다. 아이콘은 밀도와 상관없이 16pt다.

## 저장

모든 파일은 `~/Library/Application Support/Lumen/` 아래에 있고, 경로는 `Core/LumenStorage.swift`만 만든다.

| 무엇 | 어디 |
|---|---|
| JSON 파일 | `LumenStorage.Slot`의 이름. 읽기·쓰기는 `LumenStorage.read`/`write`(쓰기는 atomic). 슬롯 폴더 안의 파일은 URL을 받는 판을 쓴다 |
| 노트 | `notes/<id>.md`와 `notes/.order.json`. 입출력은 `Features/Note/NoteStore.swift`의 직렬 큐 하나로만 한다 |
| 클립보드 | `clipboard_history.json`(0600)과 `images/`의 PNG. 항목은 이미지 경로만 갖는다 |
| 자격증명 | `secrets.dat`. `Core/SecretStore.swift`만 읽고 쓴다. 일정 플러그인은 `PluginSecrets`를 거친다 |
| 진단 로그 | `~/Library/Logs/Lumen/memory_trace.log`(`MemoryTrace`, 리소스 모니터에서 켬) |
| 설정 값 | `UserDefaults` |

새로 만드는 UserDefaults 키는 `"<기능>.<이름>"`(lower camel case)로 짓고, 값을 가진 타입 안에 `private static let …Key`로 둔다. 키를 모아 둔 파일은 없다. 지금 있는 키 중 이 규칙과 다른 것(`Lumen.appUsageCounts`, `memory_trace_enabled`, `didPurgeRetiredFilesV1`)은 이름을 바꾸지 않는다.

기능을 없애서 남는 파일은 `LumenStorage.retiredFiles`에 이름을 적어 지운다. 폴더를 훑어 모르는 파일을 지우는 방식은 쓰지 않는다. 다음에 새로 생긴 파일까지 지울 수 있다.

## 단축키

`Core/HotkeyManager.swift`가 Carbon `RegisterEventHotKey`로 등록한다. 입력 모니터링 권한이 필요 없다. 다른 앱이 이미 잡은 조합은 등록이 실패하고 `failedRegistrations`에 남는다. 사람이 읽는 라벨("⌘⇧V")은 `HotkeyManager.describe`가 만든다.

패널 안 단축키(노트의 ⌘N, 일정의 ⌘1 등)는 전역 단축키가 아니다. 각 윈도우 컨트롤러의 `onKeyEvent`/`onCommandKey`가 처리한다.

## 토스트

`LumenToast.show(text:)`는 마우스가 있는 화면 아래쪽에 잠깐 뜨는 알림이다. 눈에 보이는 결과가 없는 동작(색 복사, 번역 결과 복사, 백그라운드 켜기·끄기, 실패 안내)에 쓴다. macOS 알림 센터는 쓰지 않는다.

## 일정 대시보드

`Features/Schedule/`은 기능 하나지만 안에 플러그인 구조가 있다.

- `Core/SchedulePlugin.swift`: 일정 출처 프로토콜. 캘린더(EventKit), Jira, 내 일정 셋이 `Plugins/` 아래에 있다.
- `Core/SchedulePlugins.swift`: 등록 목록. 순서가 칩 순서이자 색 순서다.
- `Core/ScheduleStore.swift`: 플러그인 결과를 합치고, 묶음 색, 갱신(같은 플러그인의 중복 조회를 막음), 디스크 캐시(`ScheduleCache`), 시계(`now`, `today`)를 맡는다. 자는 동안 날짜가 바뀌어도 깨어날 때 시계가 맞춰진다.
- 화면: 왼쪽 목록(`Agenda/`), 오른쪽 월간·주간(`Calendar/`), 메뉴바 라벨과 오늘 일정 팝오버(`MenuBar/`).

새 출처를 붙이는 법과 지켜야 할 약속(잘린 결과를 성공으로 돌려주지 않기, 항목 id, `end`의 뜻)은 [schedule-plugins.md](schedule-plugins.md)에 있다.

## 클램쉘 모드

`Features/Power/`에 카페인과 함께 있다. 코드 이름은 LidAwake다. 설치(sudoers 규칙), 소유 표시, 크래시 뒤 복구, 자동 끄기의 이유는 `SleepPolicyService.swift`와 `LidAwakeFeature.swift` 맨 위 주석에 있다. 바꾸기 전에 그 주석과 [pitfalls.md](pitfalls.md)의 클램쉘 항목을 읽는다.
