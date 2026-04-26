# Lumen

macOS 메뉴바 런처 + 빌트인 유틸리티 모음. 개인용.

## 기능

- **검색 런처** (Cmd+Space 대안 핫키) — 설치된 앱 빠르게 띄우기
- **Translator** (Cmd+Shift+C) — OpenAI 한↔영 번역
- **Clipboard** (Cmd+Shift+V) — 클립보드 히스토리
- **Note** (Cmd+Shift+X) — 플로팅 메모장
- **WindowMagnet** (Ctrl+Opt+←/→) — 윈도우 스냅
- **Caffeine** — 슬립 방지 토글
- **JiraDashboard** — Jira Cloud 이슈 패널
- **ResourceMonitor** — 자체 리소스 진단

## 설치

[최신 릴리즈](https://github.com/Hwan3434/Lumen/releases/latest)에서 `Lumen-x.y.z.zip` 다운 → 압축 풀고 `Lumen.app`을 `/Applications`로.

첫 실행만 우클릭 → 열기 (self-signed라 Gatekeeper 통과 한 번 필요).

## 첫 셋업

1. **권한**: 시스템 설정 → 개인정보 보호 및 보안
   - **손쉬운 사용** → Lumen ON (윈도우 마그넷·핫키)
   - **입력 모니터링** → Lumen ON (글로벌 핫키)
2. **자격증명**: Cmd+, → Settings
   - Jira: Cloud ID / 이메일 / API 토큰
   - OpenAI: API Key
   - 모두 Keychain에 저장됨
3. (선택) 메뉴바 → "로그인 시 시작" 켜기

기존 fingerprint가 누적돼 권한이 꼬이면:
```sh
tccutil reset All com.jh.Lumen
```
후 권한 다시 부여.

## 자동 업데이트

Sparkle 통합. 메뉴바 → "업데이트 확인…" 또는 24시간마다 자동 체크.

## 빌드 & 배포 (개발자용)

```sh
# 새 버전 릴리즈 — archive → zip → EdDSA 서명 → appcast → GitHub Release
./scripts/release.sh 1.2.3
```

요구사항:
- Xcode (Lumen.xcodeproj 열어서 한 번 빌드해두면 SPM dependency cache가 잡힘)
- `gh` CLI 인증 완료
- macOS Keychain에 코드사이닝 인증서 `Lumen Self-Signed` 등록
- macOS Keychain에 Sparkle EdDSA 비공개키 (최초 1회 `generate_keys` 실행으로 생성)

## 데이터 위치

- 자격증명: macOS Keychain (`com.jh.Lumen` 서비스)
- 노트/클립보드/숨김앱 설정: `~/Library/Application Support/Lumen/`
- 진단 로그: `~/Library/Logs/Lumen/memory_trace.log` (옵션)

## 스택

Swift 5 + SwiftUI + AppKit, Carbon HotKey, Sparkle 2.x, NetworkImage, swift-markdown-ui.
배포 타깃: macOS 26.2.
