# 함정

버그를 냈거나 낼 뻔한 곳이다. 각 항목은 **증상**, **원인**, **규칙** 순서다. 이유가 긴 것은 [decisions.md](decisions.md)에 있다.

## 테스트가 설치된 Lumen을 건드린다
- 증상: 테스트를 돌렸더니 쓰던 클램쉘 모드가 꺼지고, ⌘Space가 잠깐 안 먹고, 클립보드 기록 파일을 두 프로세스가 같이 썼다.
- 원인: 테스트 호스트가 실제 앱이다(`TEST_HOST = Lumen.app`). 번들 id, UserDefaults, `Application Support/Lumen` 폴더가 설치된 앱과 같다.
- 규칙: `AppDelegate`는 `XCTestConfigurationFilePath` 환경변수가 있으면 글꼴과 테마만 적용하고 멈춘다. 이 가드를 옮기거나 지우지 않는다(`TestHostIsolationTests`가 확인한다). 테스트에서 `UserDefaults.standard`, `LumenStorage.baseURL`, `LumenDensity.saved`·`LumenGlass.saved` 같은 `.saved` 설정 값, `shared` 싱글턴의 저장 동작에 쓰지 않는다. 스냅샷 테스트의 밀도·글래스는 `LumenUIStore.shared`의 메모리 값만 바꾼다(`SnapshotEnvironment`).
- README 스크린샷은 예시 데이터로 그린다. 실제 앱 화면을 찍으면 클립보드, 노트, 설정 값이 그대로 찍힌다.

## 밀도 값이 바뀌지 않는다
- 증상: 설정에서 밀도를 바꿨는데 어떤 간격이나 크기만 그대로다.
- 원인: `Space.*`, `Space.scaled`, `Constants.*WindowSize`는 읽을 때마다 밀도를 따르는 계산 프로퍼티다. `static let`이나 저장 프로퍼티에 담으면 처음 값이 굳는다.
- 규칙: [DESIGN.md](../DESIGN.md) 3장. 달력 막대 간격 같은 고정 숫자만 `let`으로 둔다.

## 비밀번호가 클립보드 기록에 남는다
- 증상: 비밀번호 관리자에서 복사한 값이 기록과 `clipboard_history.json`에 평문으로 있었다.
- 원인: 감시가 모든 문자열을 기록했다.
- 규칙: `ClipboardManager.checkClipboard` 맨 앞의 Concealed/Transient 형식 검사를 지우지 않는다. 클립보드 쪽 저장 코드를 고칠 때 0600 권한 설정을 빠뜨리지 않는다.

## 저장된 Jira 토큰이 사라진다
- 증상: 업데이트나 Mac 이전 뒤 토큰이 비어 있고, 다시 넣으면 예전 값은 영영 없다.
- 원인: 가리는 키가 기기 UUID라 바뀔 수 있다. 예전 코드는 못 푼 파일을 빈 사전으로 덮었다.
- 규칙: `SecretStore`의 `load`가 nil을 돌려주는 경로와 `loadForWrite`의 백업을 유지한다. 키 만드는 법(`keyBytes`)을 바꾸면 모든 사용자의 토큰이 못 푸는 파일이 된다. 바꿔야 하면 옛 키로 읽어 새 키로 다시 쓰는 코드를 먼저 둔다.
- 저장 키 이름(`<plugin>.<이름>`, 예: `jira.apiToken`)을 바꾸는 것도 같은 결과다.

## 클램쉘 모드를 남의 것까지 끈다
- 증상: 사용자가 터미널에서 `pmset`으로 켠 값을 Lumen이 끄거나, 테스트·두 번째 실행이 설치된 앱이 켠 값을 끈다.
- 원인: 시스템 값(`SleepDisabled`)은 하나뿐이고 누가 켰는지 모른다. 소유 표시(`lidAwake.ownedByLumen`)는 UserDefaults라 같은 번들 id를 쓰는 모든 프로세스가 공유한다.
- 규칙: 끄는 모든 경로는 소유 표시를 먼저 본다. `teardown()`은 동기로 끈다(종료 직전이라 `Task`는 끝나지 않는다). 실패하면 표시를 남겨 다음 실행의 `restoreIfLeftOn`이 다시 시도한다. 테스트에서 `isSleepDisabled()`나 `pmset` 쓰기를 부르지 않는다.
- 앱을 지우기 전에 설정 › 전원에서 규칙을 지워야 `/etc/sudoers.d/lumen`이 남지 않는다.

## 새 창 종류가 패널을 닫는다
- 증상: 패널 안에서 띄운 보조 창이 뜨자마자 패널이 사라진다.
- 원인: `AppDelegate`가 패널이 아닌 창이 키 창이 되면 모든 패널을 내린다. 예외는 클래스 이름(Sparkle `SP`/`SU`, `Alert`, `Popover`)과 부모가 `KeyablePanel`인 창뿐이다.
- 규칙: 패널에서 띄우는 창은 패널의 자식 창으로 붙이거나 SwiftUI popover를 쓴다.

## 팝오버 크기가 바뀌지 않는다
- 증상: 네트워크로 내용을 받은 뒤 팝오버가 잘리거나 빈 공간이 남는다.
- 원인: macOS 팝오버는 뜬 뒤 크기가 바뀌지 않는다.
- 규칙: 받을 것을 다 받은 뒤 팝오버를 연다(`SchedulePlugin.detailView` 주석, `PopoverPresentationSizeTests`).

## 백그라운드에서 부른 코드가 메인에서 돈다
- 증상: `Task.detached`로 넘겼는데 메인 스레드가 멈춘다. 또는 메인 액터 타입을 `DispatchQueue`에서 불러도 Swift 5 모드라 경고 없이 넘어간다.
- 원인: 기본 격리가 MainActor라 표시 없는 타입은 모두 메인 액터에 묶인다. detached 작업도 그 타입을 부르면 메인으로 돌아간다.
- 규칙: 백그라운드에서 쓸 도우미는 상태 없이 `nonisolated`로 만든다. 확장에 둔 상수도 마찬가지다(`nonisolated extension SchedulePluginID`). 엄격 검사(`SWIFT_STRICT_CONCURRENCY=complete`)로 가끔 확인한다.

## 큐끼리 서로 기다려 멈춘다
- 증상: 앱이 멈춘다(교착).
- 원인: `ClipboardManager.flushPendingSave()`는 메인에서 `diskQueue.sync`로 기다린다. 그 큐에서 `DispatchQueue.main.sync`를 부르면 서로 기다린다.
- 규칙: 디스크 큐에서 메인으로 돌아갈 때는 `main.async`.

## 날짜가 하루 밀린다
- 증상: 종일 일정이 하루 더 길게 그려지거나, 자정에 끝나는 일정이 다음 날에도 보인다.
- 원인: EventKit은 종일 일정의 끝을 "다음 날 0시"로 줄 때가 있고, 시간 일정의 끝이 정확히 0시일 수 있다.
- 규칙: 하루 단위 계산은 `ScheduleItem.lastDay`. `startOfDay(end ?? start)`를 직접 쓰지 않는다. 출처의 "다음 날 0시"는 플러그인이 바꿔 넣는다.

## 공휴일 표가 끝난다
- 증상: 어느 해부터 설·추석이 빨간색이 아니다.
- 원인: `Features/Schedule/Calendar/KoreanHolidays.swift`의 음력 공휴일과 대체공휴일은 손으로 적은 표이고 2028년까지만 있다.
- 규칙: 해가 바뀌면 다음 해 표를 더한다. 공식 발표 전 값은 주석대로 계산한 값이다.

## 아이콘이 빈칸이다
- 증상: 메뉴나 목록의 아이콘 자리가 비어 있다.
- 원인: Lucide 이름이 틀려도 빌드는 성공한다. 이미지는 실행 중에야 못 찾는다.
- 규칙: 이미지 세트를 지우거나 이름을 바꾸기 전에 따옴표 붙인 이름을 `Lumen`과 `LumenTests`에서 grep한다. `LumenIcon`이 `"lucide-\(name)"`으로 만들기 때문에 `lucide-`를 뺀 이름도 찾는다.

## 앱 번들 정보를 읽을 때
- `Bundle(url:)`은 만든 번들을 프로세스가 끝날 때까지 들고 있다. 앱 목록을 만들 때는 `Contents/Info.plist`를 `NSDictionary`로 읽는다(`AppIndexer.makeItem`). `Bundle(url:)`은 그 파일이 없는 앱에만 쓴다.

## 이름이 SwiftUI와 겹친다
- `Features/Schedule/Calendar/TimelineView.swift`의 `TimelineView`는 SwiftUI의 `TimelineView`와 이름이 같다. 같은 파일에서 SwiftUI 쪽을 쓰려면 `SwiftUI.TimelineView`로 적는다.

## 디버그 빌드가 업데이트를 제안한다
- `project.pbxproj`의 `MARKETING_VERSION`은 옛 값(1.0.75)이다. 릴리즈 스크립트가 명령줄로 버전을 덮으므로 배포에는 문제없지만, 로컬 디버그 빌드는 자기를 1.0.75로 알고 Sparkle이 업데이트를 띄울 수 있다. 디버그 빌드에서 그 창이 떠도 버그가 아니다.
