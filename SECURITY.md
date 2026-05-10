# Security Policy

## Reporting a Vulnerability

Please report security issues privately before opening a public issue.

Include:

- A concise description of the issue.
- Steps to reproduce.
- Impact and affected versions, if known.
- Any logs or screenshots with personal data removed.

## Data Handling

Do not commit:

- WhatsApp messages, chat exports, session databases, or QR codes.
- Build logs, notary logs, crash reports, or diagnostic traces.
- Apple IDs, Team IDs, app-specific passwords, keychain profile names tied to a
  private account, certificates, provisioning profiles, or signing keys.
- Local MCP client configuration from `~/.claude.json` or
  `~/.codex/config.toml`.
- Generated app bundles, DMGs, archives, or Xcode projects.

## Local Runtime Data

The app may read or write local user data while running:

- `~/src/whatsapp-mcp`
- `~/Library/LaunchAgents/`
- `~/Library/Logs/whatsapp-bridge.log`
- `~/Library/Logs/whatsapp-bridge.err.log`
- MCP client configuration selected during onboarding.

These files are runtime state, not source code. They should stay out of git.

## Release Safety

Release signing and notarization must be configured with environment variables
or a CI secret manager:

```bash
TEAM_ID=ABCDE12345 NOTARY_PROFILE=WhatsAppConnector-notary make release
```

Never hardcode account-specific signing data in source files.
