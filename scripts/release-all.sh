#!/bin/bash
# Releases macOS and Windows together.
#
# Windows is tagged FIRST so GitHub Actions starts building on a real Windows
# runner while the Mac build runs here — the two genuinely overlap, so the whole
# thing costs about as long as the slower one rather than both added together.
#
#   ./release-all.sh 1.1.12 1.7.6 "Release notes here"
#
set -euo pipefail

[ -f "$HOME/.billcat-release.env" ] && source "$HOME/.billcat-release.env"
: "${GITHUB_TOKEN:?GITHUB_TOKEN missing from ~/.billcat-release.env}"
: "${SUPABASE_SERVICE_KEY:?SUPABASE_SERVICE_KEY missing from ~/.billcat-release.env}"

MAC_REPO=billcatapp/billcat
WIN_REPO=billcatapp/billcatwin
MAC_DIR="$HOME/billcat"
WIN_DIR="$HOME/billcatwin"
SUPABASE_URL="https://xawpxbhglzhaibmcpwho.supabase.co"

MAC_V="${1:?usage: release-all.sh <mac-version> <win-version> [notes]}"
WIN_V="${2:?usage: release-all.sh <mac-version> <win-version> [notes]}"
NOTES="${3:-Bug fixes and improvements}"

command -v flutter >/dev/null 2>&1 || export PATH="$HOME/development/flutter/bin:$PATH"
gh_api() { curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" "$@"; }

echo "▸ macOS $MAC_V   ▸ Windows $WIN_V"

# ── 1. Kick Windows off first so CI builds while the Mac compiles ────────────
echo "[1/6] Tagging Windows — CI starts now and runs while we build the Mac"
cd "$WIN_DIR"
WIN_BUILD=$(grep '^version:' pubspec.yaml | grep -oE '\+[0-9]+' | tr -d '+')
sed -i '' "s/^version: .*/version: $WIN_V+$((WIN_BUILD + 1))/" pubspec.yaml
git add -A
git diff --cached --quiet || git commit -q -m "Release $WIN_V"
git push -q origin master
git tag -f "v$WIN_V" >/dev/null
git push -q -f origin "v$WIN_V"
echo "      pushed v$WIN_V"

# ── 2. Build the Mac locally, in parallel with that ──────────────────────────
echo "[2/6] Building macOS release (CI is working in the background)"
cd "$MAC_DIR"
MAC_BUILD=$(grep '^version:' app/pubspec.yaml | grep -oE '\+[0-9]+' | tr -d '+')
NEW_MAC_BUILD=$((MAC_BUILD + 1))
sed -i '' "s/^version: .*/version: $MAC_V+$NEW_MAC_BUILD/" app/pubspec.yaml
(cd app && flutter build macos --release >/dev/null 2>&1)
echo "      built"

# ── 3. Package DMG + update zip ──────────────────────────────────────────────
echo "[3/6] Packaging DMG and update zip"
APP="$MAC_DIR/app/build/macos/Build/Products/Release/BillCat.app"
RW="/tmp/BillCat_rw_$MAC_V.dmg"
hdiutil detach /Volumes/BillCat >/dev/null 2>&1 || true
rm -f "$RW" "releases/BillCat-$MAC_V.dmg" "releases/BillCat-$MAC_V.zip"
mkdir -p releases
hdiutil create -size 300m -volname BillCat -fs "Journaled HFS+" -ov "$RW" >/dev/null
hdiutil attach "$RW" -readwrite -noverify -noautoopen >/dev/null
cp -R "$APP" /Volumes/BillCat/BillCat.app
xattr -cr /Volumes/BillCat/BillCat.app
ln -s /Applications /Volumes/BillCat/Applications
hdiutil detach /Volumes/BillCat >/dev/null
sleep 1
hdiutil convert "$RW" -format UDZO -o "releases/BillCat-$MAC_V.dmg" >/dev/null
rm -f "$RW"
(cd app/build/macos/Build/Products/Release && zip -qr "$MAC_DIR/releases/BillCat-$MAC_V.zip" BillCat.app)

# ── 4. Publish the Mac release + update feed ─────────────────────────────────
echo "[4/6] Publishing macOS release"
RID=$(gh_api -X POST -H "Content-Type: application/json" \
  "https://api.github.com/repos/$MAC_REPO/releases" \
  -d "{\"tag_name\":\"v$MAC_V\",\"name\":\"BillCat $MAC_V\",\"body\":\"$NOTES\"}" \
  | grep -o '"id": *[0-9]*' | head -1 | grep -o '[0-9]*')
[ -z "$RID" ] && { echo "      ✗ could not create the macOS release"; exit 1; }
for f in zip dmg; do
  CT=$([ "$f" = zip ] && echo application/zip || echo application/octet-stream)
  curl -sS -o /dev/null -X POST -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Content-Type: $CT" \
    "https://uploads.github.com/repos/$MAC_REPO/releases/$RID/assets?name=BillCat-$MAC_V.$f" \
    --data-binary @"releases/BillCat-$MAC_V.$f"
done
printf '{"version":"%s","build":%s,"download_url":"https://github.com/%s/releases/download/v%s/BillCat-%s.zip","dmg_url":"https://github.com/%s/releases/download/v%s/BillCat-%s.dmg","release_notes":"%s","mandatory":false}' \
  "$MAC_V" "$NEW_MAC_BUILD" "$MAC_REPO" "$MAC_V" "$MAC_V" "$MAC_REPO" "$MAC_V" "$MAC_V" "$NOTES" \
  | curl -sS -o /dev/null -X POST \
      "$SUPABASE_URL/storage/v1/object/billcat-updates/version.json" \
      -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
      -H "Content-Type: application/json" -H "x-upsert: true" --data-binary @-
echo "      macOS live"

# ── 5. Wait for the Windows CI that has been running all along ───────────────
echo "[5/6] Waiting for the Windows build"
EXE_URL=""
for _ in $(seq 1 60); do   # up to ~20 min
  EXE_URL=$(gh_api "https://api.github.com/repos/$WIN_REPO/releases/tags/v$WIN_V" \
    | grep -o '"browser_download_url": *"[^"]*\.exe"' | cut -d'"' -f4 | head -1 || true)
  [ -n "$EXE_URL" ] && break
  sleep 20
done
[ -z "$EXE_URL" ] && { echo "      ✗ Windows installer never appeared — check the Actions tab"; exit 1; }
echo "      installer ready"

# ── 6. Put the new installer on the website ──────────────────────────────────
# The filename is fixed: the site's Download button and printed links use it.
echo "[6/6] Updating the website download"
curl -sSL -H "Authorization: Bearer $GITHUB_TOKEN" -o /tmp/BillCat-Setup.exe "$EXE_URL"
[ -s /tmp/BillCat-Setup.exe ] || { echo "      ✗ installer download was empty"; exit 1; }
cp /tmp/BillCat-Setup.exe "$MAC_DIR/website/public/downloads/BillCat-Setup.exe"
cd "$MAC_DIR"
git add app/pubspec.yaml website/public/downloads/BillCat-Setup.exe releases/version.json 2>/dev/null || true
git diff --cached --quiet || git commit -q -m "Release macOS $MAC_V / Windows $WIN_V"
git push -q origin main

echo
echo "✅ macOS $MAC_V and Windows $WIN_V are both live."
echo "   Website installer refreshed; Vercel will deploy shortly."
