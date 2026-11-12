# Lumen 작업 안내

Lumen은 메뉴바에 사는 macOS 런처다(SwiftUI + AppKit, 개인 프로젝트). 이 파일은 어떤 AI 에이전트든 처음 읽는 입구다. 자세한 내용은 아래 문서에 있고, 같은 규칙을 여러 곳에 적지 않는다.

## 빌드와 테스트

```sh
cd Lumen
xcodebuild -scheme Lumen -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/lumen-dd build
xcodebuild -scheme Lumen -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/lumen-dd test
```

- 테스트는 30초 안팎이다. README 스크린샷 테스트 5개는 `TEST_RUNNER_LUMEN_SNAPSHOT_DIR`를 줄 때만 돌고, 평소에는 건너뛴다(skipped 5는 정상).
- 경고 0개가 기준이다. 새 경고를 남기지 않는다.
- 설치된 앱을 실행하거나 끄지 않는다. 화면 확인은 스냅샷 테스트로 한다([docs/pitfalls.md](docs/pitfalls.md)).

## 폴더

앱 소스는 `Lumen/Lumen/`, 테스트는 `Lumen/LumenTests/`.

| 폴더 | 내용 |
|---|---|
| `AppDelegate.swift` | 시작과 종료. 기능 목록을 등록하는 곳 |
| `Core/` | 기능 프로토콜(`BuiltInFeature`), `FeatureRegistry`, `HotkeyRegistry`, 패널 기반 클래스(`Window/`), 메뉴바(`AppStatusBar`, `StatusBarCoordinator`), 저장(`LumenStorage`, `SecretStore`), `MemoryTrace` |
| `DesignSystem/` | 토큰과 공통 부품. 규칙은 [DESIGN.md](DESIGN.md) |
| `Features/<이름>/` | 기능 하나씩. Clipboard, Note, Translator, Schedule, Power(카페인, 클램쉘 모드), WindowMagnet, ColorPicker, ResourceMonitor, Settings |
| `Search/` | ⌘Space 검색 패널. 기능이지만 다른 기능을 띄우는 바탕이라 `Features/` 밖에 둔다 |
| `Services/` | 검색과 설정이 함께 쓰는 데이터(`AppIndexer`, `UsageTracker`, `HiddenAppsStore`, `CurrencyService`, `LoginItemService`) |
| `Helpers/` | 기능에 속하지 않는 작은 도우미(`WindowMetrics`, `DateParsers`, `ArithmeticEvaluator` 등) |

## 꼭 지킬 규칙

- **파일을 더하거나 옮길 때 `project.pbxproj`를 고치지 않는다.** 폴더 동기화 프로젝트라 파일을 만들고 옮기고 지우기만 하면 타겟에 반영된다. 서명 같은 빌드 설정은 이 파일에서 고친다.
- **디버그 빌드는 무료 개발자 팀(Personal Team)의 `Apple Development` 인증서로 서명한다.** 즉석 서명(`-`)으로 돌아가면 빌드마다 손쉬운 사용 권한을 다시 묻는다. 배포판 서명은 [docs/release.md](docs/release.md)대로 `Lumen Self-Signed`다.
- **기본 격리가 MainActor다**(`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Swift 5 모드). 백그라운드 큐에서 부르는 도우미는 `nonisolated`로 선언한다([docs/pitfalls.md](docs/pitfalls.md)).
- **디자인 값은 토큰으로만** 쓴다. 밀도에 따라 바뀌는 값은 `static let`이나 저장 프로퍼티에 담지 않는다([DESIGN.md](DESIGN.md)).
- **테스트 호스트는 실제 앱이다.** `AppDelegate`는 XCTest 아래에서 시작 작업을 건너뛴다. 테스트에서 `UserDefaults.standard`, `LumenStorage.baseURL`, `.saved` 설정 값에 쓰지 않는다. 임시 경로를 주입한다.
- **`SecretStore`의 저장 파일을 지우거나 빈 값으로 덮지 않는다.** 풀지 못한 파일은 옆으로 옮겨 둔다([docs/decisions.md](docs/decisions.md)).
- **기존 UserDefaults 키와 저장 JSON 모양을 바꾸지 않는다.** 바꾸면 사용자 데이터가 사라진다. 새 키 규칙은 [docs/architecture.md](docs/architecture.md).
- 화면 문구는 한국어 해요체, 코드 주석은 한국어로 쓰고 "왜"만 적는다. 그만둔 코드는 주석 처리하지 않고 지운다.
- 메인 브랜치는 `main`. 릴리즈는 [docs/release.md](docs/release.md)의 절차로만 한다.

## 문서

- [docs/architecture.md](docs/architecture.md): 앱이 어떻게 짜여 있는지(시작, 기능, 패널, 저장, 단축키, 일정 플러그인)
- [docs/adding-a-feature.md](docs/adding-a-feature.md): 새 기능, 새 일정 출처를 붙이는 순서
- [docs/schedule-plugins.md](docs/schedule-plugins.md): 일정 플러그인 상세
- [docs/decisions.md](docs/decisions.md): 왜 이렇게 되어 있는지, 하지 말아야 할 것, 주인이 아직 정하지 않은 것
- [docs/pitfalls.md](docs/pitfalls.md): 버그를 냈거나 낼 뻔한 함정
- [docs/release.md](docs/release.md): 배포 스크립트
- [DESIGN.md](DESIGN.md): 디자인 시스템(Still) 규칙과 토큰
