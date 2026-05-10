#!/bin/bash
# setup-signing.sh — register notarytool credentials in the macOS Keychain.
# Run this ONCE per machine. Stores under the profile name in NOTARY_PROFILE,
# or "WhatsAppConnector-notary" by default.
# After this, scripts/release.sh can submit builds for notarization without
# re-asking for the password.

set -euo pipefail

PROFILE="${NOTARY_PROFILE:-WhatsAppConnector-notary}"
TEAM_ID="${TEAM_ID:-}"
APPLE_ID="${APPLE_ID:-}"

if [ -z "$APPLE_ID" ]; then
    printf "Apple ID email: "
    read -r APPLE_ID
fi

if [ -z "$TEAM_ID" ]; then
    printf "Apple Developer Team ID: "
    read -r TEAM_ID
fi

if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ]; then
    echo "Apple ID and Team ID are required."
    exit 1
fi

cat <<EOF
This will store your Apple ID + app-specific password in the macOS Keychain
under the profile name '$PROFILE'.

You'll need:
  • Apple ID:               $APPLE_ID
  • Team ID:                $TEAM_ID
  • App-specific password:  generate one at https://account.apple.com
                            (Sign-In and Security → App-Specific Passwords)

The password is the 4-group format: xxxx-xxxx-xxxx-xxxx
Press Enter to continue, Ctrl+C to abort.
EOF
read -r

xcrun notarytool store-credentials "$PROFILE" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID"

echo
echo "✓ Credentials saved. You can now run 'make release' to build, sign,"
echo "  notarize, staple, and package the app as a DMG for distribution."
