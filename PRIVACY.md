# Privacy

WhatsApp Connector is a local macOS utility. It does not add analytics,
telemetry, remote logging, or a hosted backend.

## What Stays Local

The app and bridge use local files on the user's Mac:

- WhatsApp bridge source and session data in `~/src/whatsapp-mcp`.
- LaunchAgent configuration in `~/Library/LaunchAgents/`.
- Bridge logs in `~/Library/Logs/`.
- MCP client configuration only when the user selects an agent setup option.

## Conversation History

The history view reads local WhatsApp bridge data and displays it in the app.
Exported conversations are created only when the user chooses to export a chat.

Do not attach exported conversations to issues or commits unless all personal
data has been removed.

## Logs

Logs can contain local paths, service output, contact identifiers, or diagnostic
details from the bridge. Treat logs as private user data.

The repository ignores generated logs and release artifacts by default.
