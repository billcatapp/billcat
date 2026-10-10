#!/bin/bash
set -e
# Publishes the already-built BillCat 1.1.2 artifacts.
# Run after: export SUPABASE_SERVICE_KEY=... ; export GITHUB_TOKEN=ghp_...
#
# Uploads the zip + dmg to GitHub Releases and points version.json at them,
# which triggers the auto-update banner for every user on next launch.

SUPABASE_URL="https://xawpxbhglzhaibmcpwho.supabase.co"
SUPABASE_SERVICE_KEY="${SUPABASE_SERVICE_KEY:?Set SUPABASE_SERVICE_KEY first}"
GITHUB_TOKEN="${GITHUB_TOKEN:?Set GITHUB_TOKEN first}"
BUCKET="billcat-updates"
GITHUB_REPO="billcatapp/billcat"

VERSION="1.1.2"
BUILD=47
NOTES="${1:-Thermal receipt printing for ESC/POS printers (58/80/112mm, auto-cut) - no driver setup; fixes data loss on token refresh; product variants; Settings crash fix; remembers last-used print options}"
MANDATORY="${2:-false}"

REL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../releases" && pwd)"
ZIP_PATH="$REL_DIR/BillCat-$VERSION.zip"
DMG_PATH="$REL_DIR/BillCat-$VERSION.dmg"
[ -f "$ZIP_PATH" ] || { echo "Missing $ZIP_PATH"; exit 1; }
[ -f "$DMG_PATH" ] || { echo "Missing $DMG_PATH"; exit 1; }

echo "Publishing BillCat $VERSION (build $BUILD)"
echo "  notes: $NOTES"
read -p "  Continue? this pushes an update to ALL users (y/n): " C
[ "$C" != "y" ] && echo "Aborted." && exit 0

echo "[1/3] Creating GitHub release v$VERSION..."
RESP=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" \
  "https://api.github.com/repos/$GITHUB_REPO/releases" \
  -d "{\"tag_name\":\"v$VERSION\",\"name\":\"BillCat $VERSION\",\"body\":\"$NOTES\",\"draft\":false,\"prerelease\":false}")
RELEASE_ID=$(echo "$RESP" | grep -o '"id": *[0-9]*' | head -1 | grep -o '[0-9]*')
[ -z "$RELEASE_ID" ] && { echo "Failed to create release:"; echo "$RESP"; exit 1; }
UP="https://uploads.github.com/repos/$GITHUB_REPO/releases/$RELEASE_ID/assets"

echo "[2/3] Uploading zip + dmg..."
ZIP_URL=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/zip" \
  "$UP?name=BillCat-$VERSION.zip" --data-binary @"$ZIP_PATH" \
  | grep -o '"browser_download_url":"[^"]*"' | cut -d'"' -f4)
DMG_URL=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/octet-stream" \
  "$UP?name=BillCat-$VERSION.dmg" --data-binary @"$DMG_PATH" \
  | grep -o '"browser_download_url":"[^"]*"' | cut -d'"' -f4)
[ -z "$ZIP_URL" ] && { echo "Zip upload failed"; exit 1; }
[ -z "$DMG_URL" ] && { echo "Dmg upload failed"; exit 1; }
echo "  zip -> $ZIP_URL"
echo "  dmg -> $DMG_URL"

echo "[3/3] Publishing version.json..."
JSON="{\"version\":\"$VERSION\",\"build\":$BUILD,\"download_url\":\"$ZIP_URL\",\"dmg_url\":\"$DMG_URL\",\"release_notes\":\"$NOTES\",\"mandatory\":$MANDATORY}"
CODE=$(echo "$JSON" | curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$SUPABASE_URL/storage/v1/object/$BUCKET/version.json" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" -H "Content-Type: application/json" \
  -H "x-upsert: true" --data-binary @-)
[ "$CODE" != "200" ] && [ "$CODE" != "201" ] && { echo "version.json failed (HTTP $CODE)"; exit 1; }
echo "$JSON" > "$REL_DIR/version.json"

echo ""
echo "✅ BillCat $VERSION published. Users get the update banner on next launch."
