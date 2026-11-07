# Lumen

> 메뉴바에서 시작해 메뉴바에서 끝나는, macOS용 개인 런처 + 유틸리티 모음.

[![Latest Release](https://img.shields.io/github/v/release/Hwan3434/Lumen?label=release&color=8b6bff)](https://github.com/Hwan3434/Lumen/releases/latest)
![Platform](https://img.shields.io/badge/macOS-26.2%2B-lightgrey)
![License](https://img.shields.io/badge/license-personal-lightgrey)

Lumen은 **⌘Space**로 떠오르는 한 장짜리 패널에서 앱 실행 · 계산 · 환율 변환 · 번역 · 클립보드 · 메모 · 일정을 처리합니다. 작업의 맥락을 끊지 않는 게 핵심 — 패널을 띄우고, 일을 마치고, 사라집니다.

---

## ✨ 화면

### 검색 — `⌘Space`

![검색 패널](docs/screenshots/Lumen.png)

설치된 앱 빠른 실행, 사칙연산(`5 * (3+2)`), 환율 변환(`100 usd`, `5만원`), 빠른 실행 카드.

### 번역 — `⌘⇧C`

![번역 패널](docs/screenshots/Translator.png)

Apple 온디바이스 번역(`Translation` 프레임워크) 기반 한↔영 번역. API 키도 네트워크도 필요 없고, 입력 언어는 자동 감지해 반대 방향으로 번역합니다. 발음 표기 토글, 우측에 최근 번역 30건 히스토리. 입력·결과 모두 *발음 복사*/*결과 복사* 버튼으로 즉시 클립보드.

### 노트 — `⌘⇧X`

![노트 패널](docs/screenshots/Note.png)

마크다운 메모. 좌측 사이드바로 노트 여러 개를 탭처럼 관리합니다. `⌘N` 새 노트, `⌘1`~`⌘9` 탭 이동, `⌘⇧]/[` 다음·이전, `⌘⌫` 삭제, `⌘⇧E` 편집/미리보기 토글. 입력은 1초 디바운스로 자동 저장.

### 클립보드 — `⌘⇧V`

![클립보드 패널](docs/screenshots/Clipboard.png)

최근 텍스트·이미지 히스토리. 좌측에서 항목 선택 → 우측에서 본문/메타데이터(앱·시간·크기) 확인 → 그대로 복사 또는 붙여넣기.

### 설정 — `⌘,`

![설정 패널](docs/screenshots/Settings.png)

사이드바가 **일반**(UI, 숨긴 앱, 전원)과 **일정**(대시보드, 캘린더, Jira)으로 나뉩니다. 일정 플러그인 설정은 저장하면 바로 적용돼요. 검색 결과에서 호버 시 나오는 작은 숨기기 버튼으로 가린 앱은 **숨긴 앱** 탭에서 한 번에 되돌리기 가능.

### 일정 — `⌘⇧G`

![일정 대시보드](docs/screenshots/Schedule.png)

캘린더 앱의 일정, Jira 담당 이슈, 직접 적은 내 일정을 한 화면에 모읍니다. 연동이 없어도 열리고, 일정 출처는 플러그인으로 붙습니다(새 출처 붙이는 법: [docs/schedule-plugins.md](docs/schedule-plugins.md)). 왼쪽은 지난 기한부터 그 이후까지 날짜로 묶은 목록, 오른쪽은 월간·주간 캘린더예요. 패널 안에서 `⌘1` 월간, `⌘2` 주간, `⌘T` 오늘, `⌘N` 새 일정. 메뉴바에는 다음 일정 라벨이 뜨고, 누르거나 `⌘⇧A`를 누르면 오늘 일정이 열려요. *(스크린샷은 예시 데이터)*

---

## 핫키

| 핫키 | 동작 |
|---|---|
| `⌘Space` | 검색 패널 |
| `⌘⇧C` | 번역 |
| `⌘⇧V` | 클립보드 |
| `⌘⇧X` | 노트 (단일 패널 정책 예외 — 다른 패널과 공존) |
| `⌘⇧G` | 일정 대시보드 |
| `⌘⇧A` | 오늘 일정 (메뉴바) |
| `⌘⇧M` | 윈도우 마그넷 좌/우 분할 (`⌃⌥←/→`) |
| `⌘,` | Settings |

검색/번역/클립보드/일정은 한 번에 하나만 떠 있습니다 (single-panel policy). 노트만 다른 패널과 나란히 띄울 수 있어요.

---

## ⚡ 빠른 시작 (사람용)

1. [최신 릴리즈](https://github.com/Hwan3434/Lumen/releases/latest)에서 `Lumen-x.y.z.zip` 다운로드
2. 압축 풀고 `Lumen.app`을 `/Applications`로 이동
3. **첫 실행만** Finder에서 우클릭 → **열기** (self-signed 빌드라 Gatekeeper 통과 1회 필요)
4. 시스템 설정 → **손쉬운 사용** / **입력 모니터링** 에서 Lumen 토글 ON
5. `⌘,` 로 Settings 열어 **일정** 섹션에서 캘린더·Jira 연동 켜기 (일정 대시보드에 연동 일정을 보고 싶을 때만)

이후 새 버전은 메뉴바 → "업데이트 확인…" 또는 24시간마다 Sparkle이 자동으로 받습니다.

---

## 외부 의존성

**필수: 없음.** macOS 표준 프레임워크만으로 동작합니다.

기능별 선택 의존:

| 기능 | 필요한 것 |
|---|---|
| 검색 / 클립보드 / 노트 / 윈도우 마그넷 / 카페인 | 없음 |
| 환율 변환 | 인터넷 (open.er-api.com 일 1회 fetch, 캐시로 오프라인 동작) |
| 번역 | 없음 (Apple 온디바이스 번역 — 첫 사용 시 macOS가 언어 모델 다운로드를 물어봅니다) |
| 일정 대시보드 | 없음. 캘린더 연동은 캘린더 접근 권한, Jira 연동은 Jira Cloud 워크스페이스 + 이메일 + API 토큰 |

---

## 🤖 AI 에이전트용 자동 설치 / 트러블슈팅

Antigravity 등 AI 에이전트가 새 macOS에 Lumen을 자율 설치하기 위한 명령어·검증 단계 + 흔한 문제 해결법은 별도 문서로 분리했습니다 → **[docs/agent-install.md](docs/agent-install.md)**

---

## 🛠️ 빌드 & 배포

```sh
./scripts/release.sh 1.2.3   # archive → zip → EdDSA 서명 → appcast → GitHub Release
```

요구사항:
- Xcode (Lumen.xcodeproj 1회 빌드해 SPM 캐시 채워두기)
- `gh` CLI 인증
- macOS Keychain에 코드사이닝 인증서 `Lumen Self-Signed`
- macOS Keychain에 Sparkle EdDSA 비공개키 (`generate_keys` 1회)

---

## 데이터 위치

- **자격증명**: macOS Keychain (`com.jh.Lumen` 서비스)
- **노트**: `~/Library/Application Support/Lumen/notes/<id>.md` (탭마다 1파일)
- **클립보드 / 숨긴 앱 / 환율 캐시**: `~/Library/Application Support/Lumen/`
- **진단 로그**: `~/Library/Logs/Lumen/memory_trace.log`

---

## 스택

Swift · SwiftUI · AppKit · Carbon HotKey · Sparkle 2.x · NetworkImage · swift-markdown-ui. 배포 타깃 macOS 26.2.
