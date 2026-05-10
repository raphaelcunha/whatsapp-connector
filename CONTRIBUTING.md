# Contributing

Thanks for helping improve WhatsApp Connector.

## Local Setup

```bash
brew install xcodegen
make dev-build
make run
```

The generated Xcode project, build output, release artifacts, and local logs are
ignored by git.

## Before Opening a Pull Request

Run:

```bash
make dev-build
find . -maxdepth 3 -type f \( -name "*.log" -o -name "*.dmg" -o -name "*.p12" -o -name "*.pem" -o -name "*.key" \)
```

Do not commit personal data, WhatsApp data, signing data, generated app bundles,
DMGs, Xcode projects, or machine-specific configuration.

## UI Copy

Keep user-facing app copy in English. Keep setup screens simple and friendly for
non-technical users.

## Release Changes

Release signing must stay configurable through environment variables and secret
managers. Do not hardcode Apple IDs, Team IDs, app-specific passwords, or
private notary profiles.
