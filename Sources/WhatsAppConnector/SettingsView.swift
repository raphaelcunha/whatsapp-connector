import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var configuringClient: MCPSettingsClient?
    @State private var feedback: SettingsFeedback?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ModernAppIcon()
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold))
                    Text("Quick actions for WhatsApp Connector.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SettingsStatusPill(icon: state.runStatus == .running ? "bolt.fill" : "pause.circle.fill",
                                   text: state.runStatus == .running ? "Running" : "Stopped")
            }
            .padding(22)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsSection(title: "Connection", message: "Pair WhatsApp, inspect logs, or repair the local service.") {
                        SettingsActionRow(
                            icon: "qrcode",
                            title: "Scan QR Code",
                            message: "Connect or reconnect WhatsApp on this Mac.",
                            buttonTitle: "Open QR Code"
                        ) {
                            NSApp.activate(ignoringOtherApps: true)
                            state.refresh()
                            if state.bridge.isInstalled() {
                                state.openOnboarding(page: 1)
                            } else {
                                openWindow(id: "installer")
                            }
                        }

                        SettingsActionRow(
                            icon: "doc.text.magnifyingglass",
                            title: "Logs",
                            message: "View technical details when something is not working.",
                            buttonTitle: "View logs"
                        ) {
                            NSApp.activate(ignoringOtherApps: true)
                            openWindow(id: "logs")
                        }

                        SettingsActionRow(
                            icon: "arrow.clockwise.circle",
                            title: "Repair setup",
                            message: "Run setup again to rebuild dependencies and refresh the service.",
                            buttonTitle: "Open setup"
                        ) {
                            NSApp.activate(ignoringOtherApps: true)
                            openWindow(id: "installer")
                        }
                    }

                    SettingsSection(title: "MCP clients", message: "Register WhatsApp Connector with your AI client or copy the manual setup text.") {
                        ForEach(MCPSettingsClient.allCases, id: \.self) { client in
                            SettingsMCPRow(
                                client: client,
                                isRunning: configuringClient == client,
                                isInstalled: state.bridge.isInstalled(),
                                install: { configure(client) },
                                copy: { copyManualSetup(for: client) }
                            )
                        }
                    }

                    if let feedback {
                        SettingsFeedbackRow(feedback: feedback)
                    }
                }
                .padding(22)
            }

            Spacer()
        }
    }

    private func configure(_ client: MCPSettingsClient) {
        state.refresh()
        guard state.bridge.isInstalled() else {
            feedback = SettingsFeedback(
                icon: "wrench.and.screwdriver.fill",
                message: "Run setup before configuring MCP clients.",
                detail: "The MCP server path is created during setup.",
                isSuccess: false
            )
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "installer")
            return
        }

        configuringClient = client
        feedback = nil

        Task {
            let result: MCPConfigurationResult
            switch client {
            case .claude:
                result = await MCPConfigurator.installClaude(bridge: state.bridge)
            case .codex:
                result = await MCPConfigurator.installCodex(bridge: state.bridge)
            case .other:
                copyManualSetup(for: client)
                configuringClient = nil
                return
            }

            feedback = SettingsFeedback(
                icon: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                message: result.message,
                detail: result.detail,
                isSuccess: result.success
            )
            configuringClient = nil
            state.refresh()
        }
    }

    private func copyManualSetup(for client: MCPSettingsClient) {
        let text = client.manualSetup(bridge: state.bridge)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        feedback = SettingsFeedback(
            icon: "doc.on.clipboard.fill",
            message: "Copied \(client.title) setup text.",
            detail: "Paste it into your client setup flow or a terminal, depending on the client.",
            isSuccess: true
        )
    }
}

private enum MCPSettingsClient: String, CaseIterable {
    case claude
    case codex
    case other

    var title: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .other: return "Other MCP client"
        }
    }

    var icon: String {
        switch self {
        case .claude: return "sparkles"
        case .codex: return "terminal.fill"
        case .other: return "square.stack.3d.up.fill"
        }
    }

    var message: String {
        switch self {
        case .claude:
            return "Install automatically through Claude when available, with config-file fallback."
        case .codex:
            return "Write the WhatsApp MCP server into your Codex config."
        case .other:
            return "Copy the command and args for any MCP-compatible client."
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .claude: return "Install in Claude"
        case .codex: return "Install in Codex"
        case .other: return "Copy setup"
        }
    }

    var copyButtonTitle: String {
        switch self {
        case .claude: return "Copy command"
        case .codex: return "Copy config"
        case .other: return "Copy setup"
        }
    }

    func manualSetup(bridge: BridgeController) -> String {
        switch self {
        case .claude:
            return MCPConfigurator.claudeManualSetup(bridge: bridge)
        case .codex:
            return MCPConfigurator.codexManualSetup(bridge: bridge)
        case .other:
            return MCPConfigurator.otherManualSetup(bridge: bridge)
        }
    }
}

private struct SettingsFeedback {
    let icon: String
    let message: String
    let detail: String?
    let isSuccess: Bool
}

private struct SettingsStatusPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let message: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                content
            }
        }
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(buttonTitle, action: action)
                .controlSize(.large)
        }
        .padding(14)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct SettingsMCPRow: View {
    let client: MCPSettingsClient
    let isRunning: Bool
    let isInstalled: Bool
    let install: () -> Void
    let copy: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: client.icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(client.title)
                    .font(.system(size: 15, weight: .semibold))
                Text(isInstalled ? client.message : "Run setup first, then configure this MCP client.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer()

            HStack(spacing: 8) {
                Button(client.copyButtonTitle, action: copy)
                    .controlSize(.regular)

                Button(action: install) {
                    HStack(spacing: 6) {
                        if isRunning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isInstalled ? client.primaryButtonTitle : "Open setup")
                    }
                }
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
            }
        }
        .padding(14)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct SettingsFeedbackRow: View {
    let feedback: SettingsFeedback

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feedback.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(feedback.isSuccess ? .green : .orange)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(feedback.message)
                    .font(.system(size: 13.5, weight: .semibold))
                if let detail = feedback.detail {
                    Text(detail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(13)
        .background((feedback.isSuccess ? Color.green : Color.orange).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke((feedback.isSuccess ? Color.green : Color.orange).opacity(0.25), lineWidth: 1)
        )
    }
}
