#!/bin/bash
# release.sh — build, sign, package, notarize, and staple "WhatsApp Connector.dmg" for distribution.
#
# Prerequisites (one-time):
#   1. Developer ID Application certificate installed in Keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application)
#   2. Notarytool credentials stored:  ./scripts/setup-signing.sh
#   3. TEAM_ID exported in the shell, or configured by your CI secret manager.
#
# Output: dist/WhatsApp-Connector-<version>.dmg (notarized, ready to share)

set -euo pipefail

cd "$(dirname "$0")/.."

PROFILE="${NOTARY_PROFILE:-WhatsAppConnector-notary}"
PROJECT="WhatsAppConnector.xcodeproj"
SCHEME="WhatsAppConnector"
CONFIG="Release"
DERIVED="build"
BUNDLE_ID="${BUNDLE_ID:-app.whatsappconnector.mac}"
TEAM_ID="${TEAM_ID:-}"
APP_NAME="WhatsApp Connector"
SIGN_IDENTITY="Developer ID Application"

VERSION=$(awk '/CFBundleShortVersionString:/ { gsub(/"/, "", $2); print $2; exit }' project.yml)
[ -n "$VERSION" ] || VERSION="1.0"

DIST="dist"
APP_PATH="$DERIVED/Build/Products/$CONFIG/$APP_NAME.app"
DMG_STAGING="$DIST/dmg-staging"
DMG_PATH="$DIST/WhatsApp-Connector-$VERSION.dmg"

mkdir -p "$DIST"

step() { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }
ok()   { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
fail() { printf "  \033[1;31m✗\033[0m %s\n" "$*"; exit 1; }

# ---------------- 0. Sanity ----------------
if [ -z "$TEAM_ID" ]; then
    fail "TEAM_ID is required. Example: TEAM_ID=ABCDE12345 NOTARY_PROFILE=WhatsAppConnector-notary ./scripts/release.sh"
fi

step "Verifying Developer ID Application cert"
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application.*$TEAM_ID"; then
    fail "No Developer ID Application cert for team $TEAM_ID. Create one in Xcode → Settings → Accounts → Manage Certificates."
fi
ok "Cert installed for team $TEAM_ID"

step "Verifying notarytool credentials"
if ! xcrun notarytool history --keychain-profile "$PROFILE" --output-format json >/dev/null 2>&1; then
    fail "Notary profile '$PROFILE' not set up. Run: ./scripts/setup-signing.sh"
fi
ok "Notarytool credentials present"

# ---------------- 1. Generate xcodeproj ----------------
step "Regenerating Xcode project from project.yml"
xcodegen generate
ok "Project regenerated"

# ---------------- 2. Build & sign ----------------
step "Building $APP_NAME (Release, signed with Developer ID)"
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
    clean build | tee "$DIST/build.log" | grep -E "^(error|warning|\*\* )" || true

[ -d "$APP_PATH" ] || fail "Build did not produce $APP_PATH (see $DIST/build.log)"
ok "Built $APP_PATH"

# ---------------- 3. Verify signature ----------------
step "Verifying code signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | tail -5
ok "Signature OK"

# ---------------- 4. Create DMG for notarization ----------------
step "Creating DMG for distribution"
rm -rf "$DMG_STAGING"
rm -f "$DMG_PATH"
mkdir -p "$DMG_STAGING"
ditto "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null
rm -rf "$DMG_STAGING"
ok "Created $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"

step "Signing DMG"
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
ok "DMG signature OK"

# ---------------- 5. Submit to Apple ----------------
step "Submitting to Apple notary service (this can take 1–10 min)"
SUBMIT_LOG="$DIST/notary-submit.log"
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$PROFILE" \
    --wait \
    --output-format json | tee "$SUBMIT_LOG"

STATUS=$(grep -Eo '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$SUBMIT_LOG" | tail -1 | sed 's/.*"status"[[:space:]]*:[[:space:]]*"//;s/"//')
SUBMISSION_ID=$(grep -Eo '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "$SUBMIT_LOG" | head -1 | sed 's/.*"id"[[:space:]]*:[[:space:]]*"//;s/"//')

if [ "$STATUS" != "Accepted" ]; then
    echo
    echo "Notarization status: $STATUS"
    if [ -n "$SUBMISSION_ID" ]; then
        echo "Fetching detailed log…"
        xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$PROFILE" "$DIST/notary-log.json"
        echo "  See $DIST/notary-log.json for the failure details."
    fi
    fail "Notarization rejected"
fi
ok "Notarization accepted (id: $SUBMISSION_ID)"

# ---------------- 6. Staple ----------------
step "Stapling the notarization ticket to the DMG"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
ok "Stapled"

# ---------------- 7. Final verify ----------------
step "Verifying with spctl (Gatekeeper) — what your friends' Macs will see"
spctl --assess --verbose=2 --type execute "$APP_PATH" 2>&1 || true
spctl --assess --verbose=2 --type open --context context:primary-signature "$DMG_PATH" 2>&1 || true

cat <<EOF

\033[1;32m✓ Release build ready!\033[0m

  App:           $APP_PATH
  Distributable: $DMG_PATH
  Version:       $VERSION
  Team ID:       $TEAM_ID
  Notarization:  $SUBMISSION_ID

To share with friends:
  • Send them $DMG_PATH (AirDrop, Slack, Drive, etc.)
  • They open the DMG and drag WhatsApp Connector.app to Applications.

EOF
