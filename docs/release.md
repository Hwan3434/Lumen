# 배포

`scripts/release.sh <버전>` 하나로 한다. 예: `scripts/release.sh 1.7.0`. 주인이 직접 돌린다. 에이전트는 요청 없이 돌리지 않는다(GitHub 릴리즈가 만들어지고 모든 사용자에게 자동 업데이트로 나간다).

## 전제 조건

스크립트가 빌드 전에 확인하고, 하나라도 어긋나면 멈춘다.

- **작업 트리가 깨끗하다**(`git status --porcelain`이 비어 있음). 폴더 동기화 프로젝트라 커밋하지 않은 `.swift` 파일도 빌드에 들어간다. 그러면 태그에 없는 코드가 배포된다.
- **`HEAD`가 GitHub의 `main`과 같다**(`gh api repos/Hwan3434/Lumen/commits/main`으로 확인). `main`을 push하고 그 커밋에서 실행한다.
- **로그인 Keychain에 유효한 `Apple Development` 인증서가 있다.** 무료 개발자 팀(Personal Team)의 것이다. 서명 팀이 바뀌면 macOS가 앱을 다른 앱으로 보고 손쉬운 사용 권한을 잊는다. 이유는 [decisions.md](decisions.md)의 「서명은 무료 개발자 팀 하나로」.

스크립트가 확인하지 않는 것:

- `gh` 로그인.
- Sparkle EdDSA 비밀 키가 이 Mac의 로그인 Keychain에 있다(Sparkle `generate_keys`로 한 번 만든 것). 공개 키는 `Info.plist`의 `SUPublicEDKey`다. 비밀 키를 잃으면 기존 사용자에게 업데이트를 보낼 수 없다.
- 테스트. 배포 전에 [AGENTS.md](../AGENTS.md)의 테스트 명령을 따로 돌린다.
- 같은 버전 태그가 이미 있는지. 있으면 빌드가 끝난 뒤 마지막 단계에서 실패한다.

## 하는 일

1. **archive**: Release 구성으로 빌드한다. 버전은 인자로 받은 값을 `MARKETING_VERSION`과 `CURRENT_PROJECT_VERSION`에 넣는다(`project.pbxproj`의 값은 쓰지 않는다). DerivedData는 `dist/DerivedData`를 따로 쓴다. 다른 프로젝트의 Sparkle 도구를 집어 오지 않기 위해서다. 그래서 이 방식의 첫 배포는 패키지를 새로 받고 처음부터 빌드한다.
2. 서명 팀이 `928X8H4B4T`인지 `codesign`으로 다시 확인한다. 아니면 멈춘다.
3. **zip**: `dist/Lumen-<버전>.zip`.
4. **sign**: `dist/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update`로 EdDSA 서명을 만든다. 출력에서 읽은 서명과 길이의 모양이 맞지 않으면 멈춘다(형식이 다르면 깨진 appcast가 나갈 뻔했다).
5. **appcast**: `dist/appcast.xml`. 항목은 이번 버전 하나뿐이다.
6. **gh release**: 태그 `v<버전>`을 빌드한 커밋(`--target`)에 걸고 zip과 appcast를 올린다.

`dist/`는 `.gitignore`에 있어 작업 트리를 더럽히지 않는다.

## 업데이트가 사용자에게 가는 길

- 앱의 `SUFeedURL`은 `releases/latest/download/appcast.xml`이다. 가장 최근 릴리즈의 appcast를 읽는다는 뜻이다.
- Sparkle이 1시간마다 확인하고 자동으로 설치한다(`Info.plist`의 `SUScheduledCheckInterval`, `SUAutomaticallyUpdate`).
- 설치 도우미 서비스를 끄고(`SUEnableInstallerLauncherService = false`) 앱 안에서 교체한다. 관리자 암호 없이 교체할 수 있는 위치에 설치돼 있어야 해서 `~/Applications`에 둔다([decisions.md](decisions.md)).

## 잘못 나간 릴리즈

appcast는 가장 최근 릴리즈의 것을 읽으므로, 고친 코드를 더 높은 버전으로 다시 내면 사용자는 그 버전을 받는다. 이미 설치된 잘못된 버전을 되돌리는 장치는 없다.
