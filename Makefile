PROJECT  := WhatsAppConnector.xcodeproj
SCHEME   := WhatsAppConnector
CONFIG   := Release
DERIVED  := build
TEAM_ID  ?=
BUNDLE_ID ?= app.whatsappconnector.mac
APP      := build/Build/Products/$(CONFIG)/WhatsApp\ Connector.app

.PHONY: all gen build dev-build run install open clean release setup-signing

# Default target — dev build (ad-hoc signing, fast)
all: dev-build

# Regenerate the .xcodeproj from project.yml
gen:
	xcodegen generate

# Build with Developer ID signing (real cert + hardened runtime)
build: gen
	@test -n "$(TEAM_ID)" || (echo "Set TEAM_ID=<Apple Developer Team ID> before running make build." && exit 1)
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="Developer ID Application" \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		PRODUCT_BUNDLE_IDENTIFIER=$(BUNDLE_ID) \
		ENABLE_HARDENED_RUNTIME=YES \
		CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
		OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
		build

# Quick local build with ad-hoc signing (skips cert + hardened runtime).
# Use during development when you don't want to sign with the real cert.
dev-build: gen
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY=- \
		DEVELOPMENT_TEAM= \
		PRODUCT_BUNDLE_IDENTIFIER=$(BUNDLE_ID) \
		ENABLE_HARDENED_RUNTIME=NO \
		CODE_SIGN_ENTITLEMENTS= \
		build

run: dev-build
	open $(APP)

install: build
	rm -rf "/Applications/WhatsApp Connector.app"
	cp -R $(APP) /Applications/
	open "/Applications/WhatsApp Connector.app"

# Full release pipeline: build + sign + DMG + notarize + staple for distribution
release:
	./scripts/release.sh

# One-time setup of notarytool credentials in Keychain
setup-signing:
	./scripts/setup-signing.sh

open: gen
	open $(PROJECT)

clean:
	rm -rf $(DERIVED) $(PROJECT) dist
