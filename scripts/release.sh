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
#  - 로그인 Keychain에 코드 서명 인증서 'Lumen Self-Signed'
#  - main 이 origin 에 push 돼 있고 작업 트리가 깨끗해야 함 (태그가 빌드한 커밋을 가리키도록)

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

# 릴리즈 전용 DerivedData. Sparkle 도구(sign_update)도 이 빌드가 받은 패키지에서 꺼내 쓴다 —
# ~/Library/Developer/Xcode/DerivedData 를 뒤지면 다른 프로젝트·다른 버전의 Sparkle 이 걸릴 수 있다.
DERIVED="$DIST/DerivedData"
SIGN_IDENTITY="Lumen Self-Signed"

# 서명 인증서가 바뀌면 macOS 가 손쉬운 사용 권한을 잊는다 — 없으면 빌드 전에 멈춘다.
# (grep -q 는 파이프 앞쪽을 SIGPIPE 로 끊어 pipefail 에 걸릴 수 있어 출력을 먼저 받아 둔다)
IDENTITIES="$(security find-identity -p codesigning)"
if [[ "$IDENTITIES" != *"\"$SIGN_IDENTITY\""* ]]; then
  echo "코드 서명 인증서 '$SIGN_IDENTITY' 가 Keychain 에 없음." >&2
  exit 1
fi

# 태그는 빌드한 커밋에 건다. 커밋 안 된 파일(폴더 동기화 프로젝트라 추적 안 된 .swift 도 빌드된다)이나
# push 안 된 커밋이 바이너리에만 들어가지 않도록, 깨끗한 트리 + origin/main 과 같은 HEAD 만 허용한다.
cd "$ROOT"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "작업 트리가 깨끗하지 않음 (git status 확인)." >&2
  exit 1
fi
HEAD_SHA="$(git rev-parse HEAD)"
REMOTE_SHA="$(gh api repos/Hwan3434/Lumen/commits/main -q .sha)"
if [[ "$HEAD_SHA" != "$REMOTE_SHA" ]]; then
  echo "HEAD($HEAD_SHA)가 origin/main($REMOTE_SHA)과 다름. main 을 push 하고 그 커밋에서 실행하세요." >&2
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
  -derivedDataPath "$DERIVED" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$VERSION" \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  archive >/dev/null

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -R "$ARCHIVE/Products/Applications/Lumen.app" "$APP_DIR/"

# 검증: Lumen Self-Signed 가 실제로 서명에 사용됐는지
SIGNER=$(codesign -dvvv "$APP_DIR/Lumen.app" 2>&1 | awk -F= '/Authority=/{print $2; exit}' || true)
echo "  signer: ${SIGNER:-<unknown>}"
if [[ "$SIGNER" != "$SIGN_IDENTITY" ]]; then
  echo "서명이 '$SIGN_IDENTITY'가 아님 — 이대로 배포하면 사용자의 손쉬운 사용 권한이 풀린다." >&2
  exit 1
fi

echo "[2/5] zip..."
ditto -c -k --keepParent "$APP_DIR/Lumen.app" "$ZIP"

echo "[3/5] sign..."
SIGN_UPDATE="$DERIVED/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
if [[ ! -x "$SIGN_UPDATE" ]]; then
  echo "Sparkle sign_update 를 못 찾음: $SIGN_UPDATE" >&2
  exit 1
fi
SIG_OUTPUT="$("$SIGN_UPDATE" "$ZIP")"
# sign_update 출력 예: sparkle:edSignature="..." length="12345"
# 형식이 다르면 sed 가 출력 전체를 그대로 돌려주므로, 값 모양을 확인하고 아니면 멈춘다.
SIGNATURE=$(echo "$SIG_OUTPUT" | sed -E 's/.*sparkle:edSignature="([^"]+)".*/\1/')
LENGTH=$(echo "$SIG_OUTPUT"   | sed -E 's/.*length="([^"]+)".*/\1/')
if [[ ! "$SIGNATURE" =~ ^[A-Za-z0-9+/=]+$ || ! "$LENGTH" =~ ^[0-9]+$ ]]; then
  echo "sign_update 출력을 읽지 못함: $SIG_OUTPUT" >&2
  exit 1
fi
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
  --target "$HEAD_SHA" \
  --title "v$VERSION" \
  --notes "Lumen v$VERSION"

echo ""
echo "릴리즈 완료: https://github.com/Hwan3434/Lumen/releases/tag/v$VERSION"
echo "appcast: $FEED_URL"
