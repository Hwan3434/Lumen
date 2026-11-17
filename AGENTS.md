# Lumen 작업 안내

Lumen은 메뉴바에 사는 macOS 런처다(SwiftUI + AppKit). 앱 소스는 `Lumen/Lumen/`, 테스트는 `Lumen/LumenTests/`.

## 빌드와 테스트

```sh
cd Lumen
xcodebuild -scheme Lumen -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/lumen-dd build
xcodebuild -scheme Lumen -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/lumen-dd test
```

- 레포 규칙(서명, `project.pbxproj`, 테스트 격리, 디자인 토큰)은 `LumenTests/RepoRulesTests.swift`가 검사한다.
- 화면 확인은 스냅샷 테스트로 한다. README 스크린샷 테스트 5개는 `TEST_RUNNER_LUMEN_SNAPSHOT_DIR`를 줄 때만 돌고, 평소 skipped 5는 정상이다.

## 이 레포의 사실

- `Search/`는 기능이지만 다른 기능을 띄우는 바탕이라 `Features/` 밖에 둔다.
- `Services/`는 검색과 설정이 함께 쓰는 데이터, `Helpers/`는 어느 기능에도 속하지 않는 작은 도우미다.
- 기본 격리가 MainActor이고 Swift 5 모드라 액터 위반에 경고가 나지 않는다. 백그라운드 큐에서 부르는 도우미는 `nonisolated`로 선언한다([docs/pitfalls.md](docs/pitfalls.md)).
- 화면 문구는 한국어 해요체, 코드 주석은 한국어로 쓴다.

## 문서

- [docs/architecture.md](docs/architecture.md): 시작, 기능, 패널, 저장(UserDefaults 키 규칙 포함), 단축키, 일정 플러그인의 짜임
- [docs/adding-a-feature.md](docs/adding-a-feature.md): 새 기능, 새 일정 출처를 붙이는 순서
- [docs/schedule-plugins.md](docs/schedule-plugins.md): 일정 플러그인 상세
- [docs/decisions.md](docs/decisions.md): 왜 이렇게 되어 있는지, 주인이 아직 정하지 않은 것
- [docs/pitfalls.md](docs/pitfalls.md): 버그를 냈거나 낼 뻔한 함정
- [docs/release.md](docs/release.md): 배포 절차(`scripts/release.sh`)
- [DESIGN.md](DESIGN.md): 디자인 시스템(Still) 규칙과 토큰
