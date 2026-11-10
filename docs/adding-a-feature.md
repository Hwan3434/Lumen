# 새 기능 붙이기

구조 설명은 [architecture.md](architecture.md)에 있다. 여기는 손댈 파일과 순서만 적는다. 파일은 폴더에 만들기만 하면 타겟에 들어간다(`project.pbxproj`를 고치지 않는다).

## 1. 패널을 여는 기능

예: `Features/Timer/`.

1. **`TimerFeature.swift`**: `final class TimerFeature: BuiltInFeature`. `name`, `featureDescription`(해요체 한 문장), `searchKeywords`, `iconName`을 적는다. `activate()`는 `windowController.toggle()`. 견본은 `Features/Clipboard/ClipboardFeature.swift`.
2. **단축키**가 필요하면 같은 파일의 `hotkeys`에 `HotkeySpec(keyCode: UInt16(kVK_…), modifiers: …, action:)`을 적는다. 다른 파일에 상수를 두지 않는다. 이미 쓰는 조합은 README 핫키 표에서 확인한다.
3. **`TimerWindowController.swift`**: `PanelWindowController`를 상속한다.
   - `createPanel()`에서 `makePanel(size:)`로 만들고 `NSHostingView`를 붙인다.
   - `onKeyEvent`에서 Escape를 받아 `hide()`한다(모든 패널이 각자 한다).
   - `densityContentSize`를 주면 밀도가 바뀔 때 크기가 따라간다.
   - `configureBeforeShow`에서 `centerUnderMouse(panel, size:)`. 위치를 기억할 패널이면 `didCreatePanel`에서 부른다.
   - 닫을 때 치울 것은 `willHide()`에 둔다.
4. **크기**: `Helpers/WindowMetrics.swift`에 `static var timerWindowSize: NSSize { size(…4단계…) }` 한 줄. `static let`으로 쓰지 않는다(밀도가 바뀌어도 그대로 남는다).
5. **뷰와 뷰 모델**: 뷰는 값을 받아 그리기만 한다. 서비스나 `shared` 싱글턴을 뷰에서 직접 부르지 않는다. 뷰 모델은 `@Observable`. 목록 선택은 인덱스가 아니라 id로 들고 있는다.
6. **디자인**: 루트 뷰는 `.lumenPanel()`, 맨 위 줄은 `LumenPanelHeader`, 아래 줄은 `LumenFooterBar`. 값은 토큰으로만([DESIGN.md](../DESIGN.md)).
7. **등록**: `AppDelegate.swift`의 `features` 배열에 `TimerFeature()`를 넣는다. 넣은 위치가 검색 기본 목록과 메뉴바 메뉴의 순서다.
8. **아이콘**: Lucide에서 받아 `Assets.xcassets/Icons/lucide-<이름>.imageset`으로 넣는다. 이름이 틀리면 빌드는 되고 화면에서 빈칸이 된다.
9. **저장**이 필요하면 `LumenStorage.Slot`에 case를 더하고 `read`/`write`를 쓴다. 설정 값은 UserDefaults에 `"timer.<이름>"` 키로 둔다([architecture.md](architecture.md#저장)).
10. **설정 탭**이 필요하면 `Features/Settings/SettingsView.swift`의 `Tab`에 case를 더하고 `label`, `icon`, `generalTabs`, `tabContent` 네 곳을 채운다. 탭 본문은 `SettingsTabContent { SettingsSection … }`이고, 바로 저장되는 탭은 `.onAppear { action.hideActionBar() }`.
11. **테스트**: 뷰 모델과 순수 함수를 `LumenTests/`에서 확인한다. 파일 경로는 임시 폴더를 주입한다. 테스트에서 `shared` 싱글턴이나 `UserDefaults.standard`에 쓰지 않는다.
12. **README**: 기능 표와 핫키 표를 손으로 고친다. 스크린샷이 필요하면 `LumenTests/ReadmeScreenshotTests.swift`에 테스트를 더한다.

## 2. 켜고 끄는 기능

패널 없이 켜고 끄기만 하면 `ToggleableFeature`를 따른다(견본: `Features/Power/CaffeineFeature.swift`).

- 클래스에 `@Observable`을 붙인다. 검색 상세 칸의 스위치가 `isOn`, `onStatus`를 따라간다.
- 스위치 밑에 설정 줄이 필요하면 `detailAccessory`에서 돌려준다(견본: `LidAwakeFeature`의 `LidAwakeHoursRow`). 검색 코드에서 기능 타입으로 분기하지 않는다.
- 켜져 있음을 메뉴바에 보이려면 `attachStatusBar`에서 `coordinator.addItem(…, visible: false)`로 받아 두고 켜질 때 `show()`.
- 켜진 상태가 눈에 보여야 한다. 메뉴바 아이콘(카페인)이나 `LumenToast.show`(클램쉘 모드) 중 하나는 둔다.

## 3. 패널도 단축키도 없는 기능

한 번 실행하고 끝나는 기능(견본: `Features/ColorPicker/ColorPickerFeature.swift`)은 `activate()`만 구현하고 등록 한 줄을 더한다.

## 4. 새 일정 출처

일정 대시보드에 출처를 붙이는 일은 기능 추가가 아니다. `AppDelegate`도 `SettingsView`도 고치지 않는다. 손대는 곳은 셋이다.

1. `Features/Schedule/Plugins/<이름>/` 폴더(저장소, 플러그인, 설정 탭)
2. 플러그인 파일 맨 위의 `nonisolated extension SchedulePluginID` 한 줄
3. `Features/Schedule/Core/SchedulePlugins.swift`의 `all`에 한 줄

자세한 순서와 지킬 약속은 [schedule-plugins.md](schedule-plugins.md).

## 끝내기 전에

- 빌드 경고 0, 테스트 통과([AGENTS.md](../AGENTS.md)의 명령).
- 화면이 바뀌었으면 스냅샷 테스트로 다크·라이트, 밀도 두 단계 이상을 본다(`LumenTests/SnapshotSupport.swift`의 환경변수).
