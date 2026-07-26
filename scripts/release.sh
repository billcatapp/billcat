#!/bin/bash
set -e

# ── Config ───────────────────────────────────────────────────────────────────
SUPABASE_URL="https://xawpxbhglzhaibmcpwho.supabase.co"
SUPABASE_SERVICE_KEY="${SUPABASE_SERVICE_KEY:?Set SUPABASE_SERVICE_KEY in your environment before running this script}"
BUCKET="billcat-updates"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # set via: export GITHUB_TOKEN=ghp_...
GITHUB_REPO="billcatapp/billcat"

# Paths are derived from this script's location so the release builds from
# whichever checkout it lives in (this one is ~/billcat).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
APP_DIR="$REPO_ROOT/app"
RELEASES_DIR="$REPO_ROOT/releases"

# Ensure flutter is on PATH (this machine keeps it under ~/development/flutter).
command -v flutter >/dev/null 2>&1 || export PATH="$HOME/development/flutter/bin:$PATH"

# ── Version: auto-increment patch, or pass as arg ────────────────────────────
CURRENT_VERSION=$(grep "^version:" "$APP_DIR/pubspec.yaml" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)

VERSION="${1:-$MAJOR.$MINOR.$((PATCH + 1))}"
NOTES="${2:-Bug fixes and improvements}"
MANDATORY="${3:-false}"

echo ""
echo "╔══════════════════════════════╗"
echo "║   BillCat Release Tool 🚀    ║"
echo "╚══════════════════════════════╝"
echo ""
echo "  Version  : $VERSION  (was $CURRENT_VERSION)"
echo "  Notes    : $NOTES"
echo "  Mandatory: $MANDATORY"
echo ""
read -p "  Continue? (y/n) : " CONFIRM
[ "$CONFIRM" != "y" ] && echo "Aborted." && exit 0

ZIP_NAME="BillCat-$VERSION.zip"
DMG_NAME="BillCat-$VERSION.dmg"
mkdir -p "$RELEASES_DIR"
ZIP_PATH="$RELEASES_DIR/$ZIP_NAME"
DMG_PATH="$RELEASES_DIR/$DMG_NAME"

# ── 1. Bump version in pubspec.yaml ──────────────────────────────────────────
echo ""
echo "[ 1/6 ] Bumping version to $VERSION..."
CURRENT_BUILD=$(grep "^version:" "$APP_DIR/pubspec.yaml" | grep -oE '\+[0-9]+' | tr -d '+')
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i '' "s/^version: .*/version: $VERSION+$NEW_BUILD/" "$APP_DIR/pubspec.yaml"
echo "        pubspec.yaml → $VERSION+$NEW_BUILD"

# ── 2. Build release app ─────────────────────────────────────────────────────
echo "[ 2/6 ] Building release app (this takes ~1 min)..."
cd "$APP_DIR"
flutter build macos --release 2>&1 | grep -E "✓|Error|error" || true
echo "        Build complete"

RELEASE_APP="$APP_DIR/build/macos/Build/Products/Release/BillCat.app"

# ── 3. Create installer DMG (with Applications shortcut) ─────────────────────
echo "[ 3/6 ] Creating installer DMG..."
RW_DMG="/tmp/BillCat_rw_$VERSION.dmg"
rm -f "$RW_DMG"

# Detach any leftover mounts
hdiutil detach /Volumes/BillCat 2>/dev/null || true

# Create writable DMG
hdiutil create -size 300m -volname "BillCat" -fs "Journaled HFS+" -ov "$RW_DMG" > /dev/null

# Mount, copy app, add Applications symlink
hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen > /dev/null
cp -R "$RELEASE_APP" /Volumes/BillCat/BillCat.app
xattr -cr /Volumes/BillCat/BillCat.app
ln -s /Applications /Volumes/BillCat/Applications

# Style: large icons, BillCat left, Applications right
osascript << APPLESCRIPT
tell application "Finder"
  tell disk "BillCat"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 700, 420}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    delay 1
    set position of item "BillCat.app" of container window to {160, 160}
    set position of item "Applications" of container window to {440, 160}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

# Finalise
hdiutil detach /Volumes/BillCat > /dev/null
sleep 1
rm -f "$DMG_PATH"
hdiutil convert "$RW_DMG" -format UDZO -o "$DMG_PATH" > /dev/null
rm -f "$RW_DMG"

DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
echo "        $DMG_PATH ($DMG_SIZE)  ← send this to new users"

# ── 4. Create zip for auto-updates ───────────────────────────────────────────
echo "[ 4/7 ] Creating update zip..."
cd "$APP_DIR/build/macos/Build/Products/Release"
zip -qr "$ZIP_PATH" BillCat.app
ZIP_SIZE=$(du -sh "$ZIP_PATH" | cut -f1)
echo "        $ZIP_PATH ($ZIP_SIZE)  ← used for silent auto-updates"

# ── 5. Upload zip + DMG to GitHub Releases ───────────────────────────────────
echo "[ 5/7 ] Uploading to GitHub Releases..."

# Create the release
RELEASE_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/$GITHUB_REPO/releases" \
  -d "{\"tag_name\":\"v$VERSION\",\"name\":\"BillCat $VERSION\",\"body\":\"$NOTES\",\"draft\":false,\"prerelease\":false}")

RELEASE_ID=$(echo "$RELEASE_RESPONSE" | grep -o '"id": *[0-9]*' | head -1 | grep -o '[0-9]*')

if [ -z "$RELEASE_ID" ]; then
  echo "        ✗ Failed to create GitHub release"
  echo "$RELEASE_RESPONSE"
  exit 1
fi
UPLOAD_URL="https://uploads.github.com/repos/$GITHUB_REPO/releases/$RELEASE_ID/assets"

# Upload the zip asset
ASSET_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/zip" \
  "$UPLOAD_URL?name=$ZIP_NAME" \
  --data-binary @"$ZIP_PATH")

ZIP_URL=$(echo "$ASSET_RESPONSE" | grep -o '"browser_download_url":"[^"]*"' | cut -d'"' -f4)

if [ -z "$ZIP_URL" ]; then
  echo "        ✗ Failed to upload zip to GitHub"
  echo "$ASSET_RESPONSE"
  exit 1
fi
echo "        Uploaded zip → $ZIP_URL"

# Upload the DMG asset
DMG_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  "$UPLOAD_URL?name=$DMG_NAME" \
  --data-binary @"$DMG_PATH")

DMG_URL=$(echo "$DMG_RESPONSE" | grep -o '"browser_download_url":"[^"]*"' | cut -d'"' -f4)

if [ -z "$DMG_URL" ]; then
  echo "        ✗ Failed to upload DMG to GitHub"
  echo "$DMG_RESPONSE"
  exit 1
fi
echo "        Uploaded DMG → $DMG_URL"

# ── 6. Update version.json on Supabase ───────────────────────────────────────
echo "[ 6/7 ] Publishing version.json..."
VERSION_JSON="{
  \"version\": \"$VERSION\",
  \"build\": $NEW_BUILD,
  \"download_url\": \"$ZIP_URL\",
  \"dmg_url\": \"$DMG_URL\",
  \"release_notes\": \"$NOTES\",
  \"mandatory\": $MANDATORY
}"

UPDATE_RESULT=$(echo "$VERSION_JSON" | curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$SUPABASE_URL/storage/v1/object/$BUCKET/version.json" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "x-upsert: true" \
  --data-binary @-)

if [ "$UPDATE_RESULT" != "200" ] && [ "$UPDATE_RESULT" != "201" ]; then
  echo "        ✗ version.json update failed (HTTP $UPDATE_RESULT)"
  exit 1
fi
echo "$VERSION_JSON" > "$RELEASES_DIR/version.json"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  ✅  BillCat v$VERSION released!"
echo ""
echo "  📦 New users     → send them $DMG_NAME"
echo "                     (open DMG → drag to Applications)"
echo ""
echo "  🔄 Existing users → update banner appears"
echo "                     automatically on next launch"
echo "══════════════════════════════════════════════════════"
echo ""
