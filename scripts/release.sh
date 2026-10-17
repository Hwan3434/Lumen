#!/usr/bin/env bash
# Lumen 릴리즈 스크립트
# 사용법: scripts/release.sh <version>   (예: scripts/release.sh 1.1.0)
#
# 동작:
#  1) Lumen.xcodeproj를 Release 구성으로 archive
#  2) .app 추출 + zip 압축 -> dist/Lumen-<ver>.zip
#  3) Sparkle EdDSA 서명 -> length/signature 산출
#  4) dist/appcast.xml 생성 (단일 enclosure)
#  5) gh CLI로 릴리즈 생성 + zip + appcast.xml 업로드
#
# 사전 준비:
#  - Sparkle generate_keys 가 1회 실행돼 macOS Keychain에 비공개키가 저장돼 있어야 함
#  - gh auth 로그인 완료
#  - jq 설치 (brew install jq)

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version>  (e.g. $0 1.1.0)"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/Lumen/Lumen.xcodeproj"
SCHEME="Lumen"
DIST="$ROOT/dist"
ARCHIVE="$DIST/Lumen-$VERSION.xcarchive"
APP_DIR="$DIST/Lumen-$VERSION"
ZIP="$DIST/Lumen-$VERSION.zip"
APPCAST="$DIST/appcast.xml"
FEED_URL="https://github.com/Hwan3434/Lumen/releases/latest/download/appcast.xml"

# Sparkle 도구 경로 (DerivedData 안에 있음)
SPARKLE_BIN=$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*sparkle/Sparkle/bin/sign_update' -type f 2>/dev/null | head -1 | xargs -n1 dirname || true)
if [[ -z "$SPARKLE_BIN" ]]; then
  echo "Sparkle CLI를 못 찾음. 한 번이라도 빌드 후 다시 시도하세요." >&2
  exit 1
fi

mkdir -p "$DIST"
rm -rf "$ARCHIVE" "$APP_DIR" "$ZIP"

echo "[1/5] archive..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$VERSION" \
  CODE_SIGN_IDENTITY="Lumen Self-Signed" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  archive >/dev/null

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -R "$ARCHIVE/Products/Applications/Lumen.app" "$APP_DIR/"

# 검증: Lumen Self-Signed 가 실제로 서명에 사용됐는지
SIGNER=$(codesign -dvvv "$APP_DIR/Lumen.app" 2>&1 | awk -F= '/Authority=/{print $2; exit}' || true)
echo "  signer: ${SIGNER:-<unknown>}"
case "$SIGNER" in
  "Lumen Self-Signed") ;;
  *) echo "  WARN: 서명이 'Lumen Self-Signed'가 아님 — Keychain 항목 확인 필요" ;;
esac

echo "[2/5] zip..."
ditto -c -k --keepParent "$APP_DIR/Lumen.app" "$ZIP"

echo "[3/5] sign..."
SIG_OUTPUT="$("$SPARKLE_BIN/sign_update" "$ZIP")"
# sign_update 출력 예: sparkle:edSignature="..." length="12345"
SIGNATURE=$(echo "$SIG_OUTPUT" | sed -E 's/.*sparkle:edSignature="([^"]+)".*/\1/')
LENGTH=$(echo "$SIG_OUTPUT"   | sed -E 's/.*length="([^"]+)".*/\1/')
PUBDATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
DOWNLOAD_URL="https://github.com/Hwan3434/Lumen/releases/download/v$VERSION/Lumen-$VERSION.zip"
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" "$APP_DIR/Lumen.app/Contents/Info.plist" 2>/dev/null || echo "")

echo "[4/5] appcast..."
cat > "$APPCAST" <<XML
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Lumen</title>
    <link>$FEED_URL</link>
    <description>Lumen update feed</description>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUBDATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <enclosure
        url="$DOWNLOAD_URL"
        length="$LENGTH"
        type="application/octet-stream"
        sparkle:edSignature="$SIGNATURE" />
    </item>
  </channel>
</rss>
XML

echo "[5/5] gh release..."
gh release create "v$VERSION" "$ZIP" "$APPCAST" \
  --title "v$VERSION" \
  --notes "Lumen v$VERSION"

echo ""
echo "릴리즈 완료: https://github.com/Hwan3434/Lumen/releases/tag/v$VERSION"
echo "appcast: $FEED_URL"
