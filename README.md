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

## 빠른 시작 (사람용)

1. [최신 릴리즈](https://github.com/Hwan3434/Lumen/releases/latest)에서 `Lumen-x.y.z.zip` 다운
2. 압축 풀고 `Lumen.app`을 `/Applications`로
3. 첫 실행만 우클릭 → 열기 (self-signed라 Gatekeeper 통과 한 번 필요)
4. 시스템 설정 → 손쉬운 사용 / 입력 모니터링에서 Lumen ON
5. Cmd+, 로 Settings 열어 Jira/OpenAI 키 입력 (선택, 해당 기능 쓸 때만)

자동 업데이트는 메뉴바 → "업데이트 확인…" 또는 24시간마다 자동.

---

## 외부 의존성

**필수 외부 프로그램: 없음.** macOS 표준 프레임워크만 사용합니다.

기능별 선택 의존:

| 기능 | 필요 |
|---|---|
| 검색 / Clipboard / Note / WindowMagnet / Caffeine / ResourceMonitor | 없음 (앱만) |
| Translator | OpenAI API 키 |
| JiraDashboard | Jira Cloud 계정 (Cloud ID + 이메일 + API 토큰) |
| Claude 사용량 패널 | `~/.claude/projects/` (Claude Code CLI가 만드는 디렉토리) |
| Claude 사용량 게이지(세션/주간 %) | 별도 셸 스크립트가 만드는 `~/develop/claude_status/usage-history.csv` (선택) |

---

## AI 에이전트용 상세 설치 절차

> 이 섹션은 Claude/AI 에이전트가 새 macOS에서 Lumen을 자율 설치할 수 있도록
> 명령어와 검증 단계를 명시합니다. 각 단계의 [SUCCESS]/[FAIL] 분기를 따라가세요.
> **[USER ACTION]** 마커가 있는 단계는 시스템 설정 GUI 또는 Touch ID/비밀번호
> 입력이 필요해 사용자에게 위임해야 합니다.

### 사전 요건 검증

```bash
# macOS 버전 (Lumen은 macOS 26.2+)
sw_vers -productVersion
# [FAIL: 26.2 미만] 사용자에게 OS 업데이트 필요 안내 후 중단
```

### 1단계: 옛 버전 / 옛 이름(ClaudeSpot) 정리

```bash
# 실행 중인 인스턴스 종료
osascript -e 'tell application "Lumen" to quit' 2>/dev/null
osascript -e 'tell application "ClaudeSpot" to quit' 2>/dev/null
sleep 1

# 옛 .app 제거
[ -d /Applications/Lumen.app ] && rm -rf /Applications/Lumen.app
[ -d /Applications/ClaudeSpot.app ] && rm -rf /Applications/ClaudeSpot.app

# 옛 fingerprint TCC 누적분 정리 (없으면 무해)
tccutil reset All com.jh.Lumen 2>/dev/null
tccutil reset All com.jh.ClaudeSpot 2>/dev/null
```

### 2단계: 최신 릴리즈 다운로드 + 설치

```bash
# 최신 버전 태그 조회 (gh CLI 우선, 없으면 GitHub API)
LATEST=$(gh release view -R Hwan3434/Lumen --json tagName -q .tagName 2>/dev/null \
  || curl -sL https://api.github.com/repos/Hwan3434/Lumen/releases/latest \
     | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
VERSION="${LATEST#v}"
echo "installing $VERSION"
# [FAIL: LATEST 비어있음] 네트워크/리포 접근 확인 후 재시도

# 다운로드 + 압축 해제 + 설치
cd /tmp
rm -rf Lumen.app "Lumen-${VERSION}.zip"
curl -sL -o "Lumen-${VERSION}.zip" \
  "https://github.com/Hwan3434/Lumen/releases/download/${LATEST}/Lumen-${VERSION}.zip"
unzip -q "Lumen-${VERSION}.zip"
mv Lumen.app /Applications/

# Gatekeeper quarantine 제거 (curl 다운은 보통 안 붙지만 안전 차원)
xattr -dr com.apple.quarantine /Applications/Lumen.app 2>/dev/null

# 검증
INSTALLED=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
  /Applications/Lumen.app/Contents/Info.plist)
[ "$INSTALLED" = "$VERSION" ] && echo "[SUCCESS] $VERSION 설치됨" \
  || echo "[FAIL] 버전 불일치: expected=$VERSION installed=$INSTALLED"
```

### 3단계: 첫 실행

```bash
open -a /Applications/Lumen.app
sleep 3
pgrep -lf "/Applications/Lumen.app/Contents/MacOS/Lumen" \
  && echo "[SUCCESS] 실행 중" || echo "[FAIL] 실행 안 됨"
```

이 시점에 권한 요청 다이얼로그가 뜰 수 있습니다.

### 4단계: 권한 부여 [USER ACTION]

다음 권한이 필요하며, **macOS 보안 정책상 GUI 토글과 Touch ID/비밀번호가 필수**라
에이전트가 자동화할 수 없습니다. 사용자에게 다음을 안내하세요:

```bash
# 시스템 설정의 해당 페이지를 직접 열어 사용자 작업을 줄임
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

사용자가 해야 할 일:
1. **손쉬운 사용** 패널에서 `+` → `/Applications/Lumen.app` 추가 → 토글 ON
2. 그 다음:
   ```bash
   open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
   ```
   **입력 모니터링** 패널에서도 동일하게 추가 → 토글 ON

권한 부여 후 Lumen 재시작:

```bash
osascript -e 'tell application "Lumen" to quit'; sleep 1
open -a /Applications/Lumen.app
```

### 5단계: 자격증명 입력 (사용 기능별, 선택)

자격증명은 macOS Keychain의 `com.jh.Lumen` 서비스에 저장됩니다.

#### 옵션 A: Lumen GUI에서 입력 [USER ACTION]
1. Lumen 실행 상태에서 **Cmd+,** 로 Settings 열기
2. Jira / OpenAI / Claude 탭에서 값 입력 → "저장"
3. 첫 저장 시 Keychain 접근 다이얼로그 → **"항상 허용"** 누르고 비밀번호

#### 옵션 B: 에이전트가 직접 키체인에 주입 (사용자 키 보유 시)
```bash
# Jira (모두 또는 일부)
security add-generic-password -s com.jh.Lumen -a jiraCloudId  -w "<CLOUD_ID>"  -U
security add-generic-password -s com.jh.Lumen -a jiraEmail    -w "<EMAIL>"    -U
security add-generic-password -s com.jh.Lumen -a jiraApiToken -w "<TOKEN>"    -U

# OpenAI
security add-generic-password -s com.jh.Lumen -a openAIAPIKey -w "<API_KEY>"  -U

# 검증 (값 노출 주의 — prefix만 확인)
security find-generic-password -s com.jh.Lumen -a openAIAPIKey -w | head -c 10
echo "..."

# 적용 위해 Lumen 재시작 (앱은 init 시점에 키를 1회 캐싱)
osascript -e 'tell application "Lumen" to quit'; sleep 1
open -a /Applications/Lumen.app
```

### 6단계: 정상 동작 검증

```bash
# 1. 실행 중인지
pgrep -lf "/Applications/Lumen.app/Contents/MacOS/Lumen" >/dev/null \
  && echo "[OK] running" || echo "[FAIL] not running"

# 2. 메뉴바 아이콘은 GUI라 셸로 확인 불가 — 사용자에게 "메뉴바에 작은 빛 아이콘
#    보이나요?" 질문해 확인

# 3. 자격증명 저장 여부
for acct in jiraCloudId jiraEmail jiraApiToken openAIAPIKey; do
  security find-generic-password -s com.jh.Lumen -a "$acct" >/dev/null 2>&1 \
    && echo "[OK] $acct" || echo "[--] $acct (not set, OK if 미사용)"
done

# 4. (선택) 로그인 시 자동 시작 — Lumen 메뉴바 → "로그인 시 시작" 체크 [USER ACTION]
```

### 트러블슈팅

| 증상 | 원인 / 조치 |
|---|---|
| 첫 실행 시 "확인되지 않은 개발자" Gatekeeper | self-signed라 정상. **사용자에게**: Finder에서 `/Applications/Lumen.app` 우클릭 → "열기" → 다이얼로그의 "열기" 한 번. 이후 안 뜸 |
| 권한이 ON인데 핫키 안 먹음 | TCC DB 잔재 가능성. `tccutil reset All com.jh.Lumen` 후 권한 다시 부여 |
| 키체인 prompt가 매 시작마다 뜸 | 옛 fingerprint 잔재. Lumen 종료 → 모든 `com.jh.Lumen` 키체인 항목 삭제 → 다시 입력 |
| Translator 핫키(Cmd+Shift+C)가 다른 앱에 가로채짐 | 시스템 설정 → 키보드 → 키보드 단축키에서 충돌 항목 비활성화 |
| 메뉴바 아이콘 안 보임 | macOS의 메뉴바 자동 숨김 / Bartender 같은 도구 가능성. 화살표 클릭해서 가려진 항목 펼치기 |

### 자동 업데이트

설치 이후 새 버전은 메뉴바 → "업데이트 확인…" 또는 24시간 자동 체크로
Sparkle이 처리합니다. 자동 업데이트는 권한 재부여 없이 동작합니다 (서명
fingerprint가 동일하기 때문). 단 첫 자동 업데이트 1회만 키체인 prompt가
뜰 수 있고, 이후엔 조용히 갱신됩니다.

---

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
