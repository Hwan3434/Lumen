# AI 에이전트용 자동 설치 절차

> Claude/AI 에이전트가 새 macOS에 Lumen을 자율 설치할 수 있도록 명령어와 검증 단계를 명시합니다. **[USER ACTION]** 마커가 있는 단계는 GUI/Touch ID가 필요하므로 사용자에게 위임하세요.

## 0. 사전 요건

```bash
sw_vers -productVersion   # 26.2+ 필요
```

## 1. 옛 버전 / 옛 이름(ClaudeSpot) 정리

```bash
osascript -e 'tell application "Lumen" to quit' 2>/dev/null
osascript -e 'tell application "ClaudeSpot" to quit' 2>/dev/null
sleep 1

[ -d /Applications/Lumen.app ] && rm -rf /Applications/Lumen.app
[ -d /Applications/ClaudeSpot.app ] && rm -rf /Applications/ClaudeSpot.app

tccutil reset All com.jh.Lumen 2>/dev/null
tccutil reset All com.jh.ClaudeSpot 2>/dev/null
```

## 2. 최신 릴리즈 설치

```bash
LATEST=$(gh release view -R Hwan3434/Lumen --json tagName -q .tagName 2>/dev/null \
  || curl -sL https://api.github.com/repos/Hwan3434/Lumen/releases/latest \
     | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
VERSION="${LATEST#v}"

cd /tmp
rm -rf Lumen.app "Lumen-${VERSION}.zip"
curl -sL -o "Lumen-${VERSION}.zip" \
  "https://github.com/Hwan3434/Lumen/releases/download/${LATEST}/Lumen-${VERSION}.zip"
unzip -q "Lumen-${VERSION}.zip"
mv Lumen.app /Applications/
xattr -dr com.apple.quarantine /Applications/Lumen.app 2>/dev/null

INSTALLED=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
  /Applications/Lumen.app/Contents/Info.plist)
[ "$INSTALLED" = "$VERSION" ] && echo "[OK] $VERSION" || echo "[FAIL] $INSTALLED ≠ $VERSION"
```

## 3. 첫 실행 + 권한 부여 [USER ACTION]

```bash
open -a /Applications/Lumen.app
```

사용자에게 안내:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
# 손쉬운 사용 → + → /Applications/Lumen.app → ON

open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
# 입력 모니터링 → + → /Applications/Lumen.app → ON
```

권한 부여 후:

```bash
osascript -e 'tell application "Lumen" to quit'; sleep 1
open -a /Applications/Lumen.app
```

## 4. 자격증명 (선택)

### 사용자가 GUI로 [USER ACTION]
`⌘,` → Jira / OpenAI 탭에서 입력 → 저장 → 첫 키체인 prompt에서 **항상 허용**.

### 또는 에이전트가 키체인에 직접 주입
```bash
# Jira — 워크스페이스 slug만 넣으면 cloudId는 첫 fetch에서 자동 resolve됨
security add-generic-password -s com.jh.Lumen -a jiraWorkspaceSlug -w "<your-workspace>" -U
security add-generic-password -s com.jh.Lumen -a jiraEmail         -w "<EMAIL>"          -U
security add-generic-password -s com.jh.Lumen -a jiraApiToken      -w "<TOKEN>"          -U

# OpenAI
security add-generic-password -s com.jh.Lumen -a openAIAPIKey -w "<API_KEY>" -U

# 적용 위해 재시작 (앱은 init 시점에 키를 1회 캐싱)
osascript -e 'tell application "Lumen" to quit'; sleep 1
open -a /Applications/Lumen.app
```

## 5. 검증

```bash
# 실행 중?
pgrep -lf "/Applications/Lumen.app/Contents/MacOS/Lumen" >/dev/null \
  && echo "[OK] running" || echo "[FAIL]"

# 자격증명 저장 여부
for acct in jiraWorkspaceSlug jiraEmail jiraApiToken openAIAPIKey; do
  security find-generic-password -s com.jh.Lumen -a "$acct" >/dev/null 2>&1 \
    && echo "[OK] $acct" || echo "[--] $acct (미설정)"
done
```

## 트러블슈팅

| 증상 | 조치 |
|---|---|
| Gatekeeper "확인되지 않은 개발자" | self-signed 빌드라 정상. Finder 우클릭 → "열기" 1회. |
| 권한 ON인데 핫키 무반응 | TCC DB 잔재. `tccutil reset All com.jh.Lumen` 후 권한 재부여. |
| 키체인 prompt가 매번 뜸 | 옛 fingerprint 잔재. Settings에서 자격증명 한 번 비우고 다시 입력 (1.0.46+에서 자동 ACL 부여됨). |
| 핫키가 다른 앱에 가로채짐 | 시스템 설정 → 키보드 → 단축키에서 충돌 항목 비활성화. |
| 메뉴바 아이콘 안 보임 | Bartender 등 메뉴바 정리 도구 가능성. 화살표 클릭으로 확장. |
