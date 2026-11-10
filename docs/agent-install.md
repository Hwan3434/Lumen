# AI 에이전트용 자동 설치 절차

> AI 에이전트가 새 macOS에 Lumen을 자율 설치할 수 있도록 명령어와 검증 단계를 명시합니다. **[USER ACTION]** 마커가 있는 단계는 GUI/Touch ID가 필요하므로 사용자에게 위임하세요.

## 0. 사전 요건

```bash
sw_vers -productVersion   # 26.2+ 필요
```

## 1. 옛 버전 정리

```bash
osascript -e 'tell application "Lumen" to quit' 2>/dev/null
sleep 1

# 예전 안내대로 /Applications 에 깐 사본도 지운다. 지금 설치 위치는 ~/Applications 다.
[ -d /Applications/Lumen.app ] && rm -rf /Applications/Lumen.app
[ -d ~/Applications/Lumen.app ] && rm -rf ~/Applications/Lumen.app

tccutil reset All com.jh.Lumen 2>/dev/null
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
# ~/Applications 에 둔다: 자동 업데이트(Sparkle)가 관리자 암호 없이 앱을 바꿔 끼울 수 있는 위치다.
mkdir -p ~/Applications
mv Lumen.app ~/Applications/
xattr -dr com.apple.quarantine ~/Applications/Lumen.app 2>/dev/null

INSTALLED=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
  ~/Applications/Lumen.app/Contents/Info.plist)
[ "$INSTALLED" = "$VERSION" ] && echo "[OK] $VERSION" || echo "[FAIL] $INSTALLED ≠ $VERSION"
```

## 3. 첫 실행 + 권한 부여 [USER ACTION]

```bash
open -a ~/Applications/Lumen.app
```

사용자에게 안내:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
# 손쉬운 사용 → + → ~/Applications/Lumen.app → ON
```

권한 부여 후:

```bash
osascript -e 'tell application "Lumen" to quit'; sleep 1
open -a ~/Applications/Lumen.app
```

## 4. 자격증명 (선택)

### 사용자가 GUI로 [USER ACTION]
`⌘,` → **일정 › Jira** 탭에서 사용을 켜고 워크스페이스 도메인, 이메일, API 토큰을 넣은 뒤 [저장] → [연결 확인]. 저장하면 바로 적용돼서 재시작은 필요 없어요.

자격증명은 키체인이 아니라 `~/Library/Application Support/Lumen/secrets.dat`(기기 UUID로 난독화, 0600)에 들어가므로 에이전트가 직접 주입하지 않아요. 캘린더 연동은 **일정 › 캘린더** 탭에서 켜고, 처음 한 번 macOS가 묻는 캘린더 권한을 허용해 주세요.

## 5. 검증

```bash
# 실행 중?
pgrep -lf "$HOME/Applications/Lumen.app/Contents/MacOS/Lumen" >/dev/null \
  && echo "[OK] running" || echo "[FAIL]"
```

## 트러블슈팅

| 증상 | 조치 |
|---|---|
| Gatekeeper "확인되지 않은 개발자" | self-signed 빌드라 정상. Finder 우클릭 → "열기" 1회. |
| 핫키 무반응 | 단축키는 권한과 상관없어요. 시작할 때 "단축키를 등록하지 못했어요" 토스트가 떴다면 다른 앱과 겹친 거예요(⌘Space는 Spotlight 기본값). |
| 윈도우 마그넷 무반응 | 손쉬운 사용 권한이 꺼져 있거나 TCC 잔재. `tccutil reset All com.jh.Lumen` 후 권한 재부여. |
| 핫키가 다른 앱에 가로채짐 | 시스템 설정 → 키보드 → 단축키에서 충돌 항목 비활성화. |
| 메뉴바 아이콘 안 보임 | Bartender 등 메뉴바 정리 도구 가능성. 화살표 클릭으로 확장. |
