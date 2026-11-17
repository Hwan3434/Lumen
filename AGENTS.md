# Lumen 작업 안내

Lumen은 메뉴바에 사는 macOS 런처다(SwiftUI + AppKit). 앱 소스는 `Lumen/Lumen/`, 테스트는 `Lumen/LumenTests/`.

## 빌드와 테스트

```sh
cd Lumen
xcodebuild -scheme Lumen -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/lumen-dd build
xcodebuild -scheme Lumen -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/lumen-dd test
```

- README 스크린샷 테스트 5개는 `TEST_RUNNER_LUMEN_SNAPSHOT_DIR`를 줄 때만 돈다. 평소 skipped 5는 정상이다.
- 설치된 앱을 실행하거나 끄지 않는다. 화면 확인은 스냅샷 테스트로 한다([docs/pitfalls.md](docs/pitfalls.md)).

## 폴더

- `Search/`는 기능이지만 다른 기능을 띄우는 바탕이라 `Features/` 밖에 둔다.
- `Services/`는 검색과 설정이 함께 쓰는 데이터, `Helpers/`는 어느 기능에도 속하지 않는 작은 도우미다.

## 꼭 지킬 규칙

- 파일을 더하거나 옮길 때 `project.pbxproj`를 고치지 않는다. 폴더 동기화 프로젝트라 파일만 만들면 타겟에 들어간다. 빌드 설정은 이 파일에서 고친다.
- 디버그 빌드와 배포판 모두 무료 개발자 팀(Personal Team)의 `Apple Development` 인증서로 서명한다. 다른 서명으로 바꾸면 손쉬운 사용 권한을 다시 묻는다([docs/decisions.md](docs/decisions.md)).
- 기본 격리가 MainActor이고 Swift 5 모드라 어겨도 경고가 나지 않는다. 백그라운드 큐에서 부르는 도우미는 `nonisolated`로 선언한다([docs/pitfalls.md](docs/pitfalls.md)).
- 디자인 값은 토큰으로만 쓴다. 밀도에 따라 바뀌는 값은 `static let`이나 저장 프로퍼티에 담지 않는다([DESIGN.md](DESIGN.md)).
- 테스트 호스트는 실제 앱이다. 테스트에서 `UserDefaults.standard`, `LumenStorage.baseURL`, `.saved` 설정 값에 쓰지 않고 임시 경로를 주입한다.
- `SecretStore`의 저장 파일을 지우거나 빈 값으로 덮지 않는다. 풀지 못한 파일은 옆으로 옮겨 둔다.
- 기존 UserDefaults 키와 저장 JSON 모양을 바꾸지 않는다. 바꾸면 사용자 데이터가 사라진다. 새 키 규칙은 [docs/architecture.md](docs/architecture.md).
- 화면 문구는 한국어 해요체, 코드 주석은 한국어로 쓴다.
- 릴리즈는 [docs/release.md](docs/release.md)의 절차로만 한다.

## 문서

- [docs/architecture.md](docs/architecture.md): 시작, 기능, 패널, 저장, 단축키, 일정 플러그인의 짜임
- [docs/adding-a-feature.md](docs/adding-a-feature.md): 새 기능, 새 일정 출처를 붙이는 순서
- [docs/schedule-plugins.md](docs/schedule-plugins.md): 일정 플러그인 상세
- [docs/decisions.md](docs/decisions.md): 왜 이렇게 되어 있는지, 하지 말 것, 주인이 아직 정하지 않은 것
- [docs/pitfalls.md](docs/pitfalls.md): 버그를 냈거나 낼 뻔한 함정
- [DESIGN.md](DESIGN.md): 디자인 시스템(Still) 규칙과 토큰
