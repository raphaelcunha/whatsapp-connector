import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

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

            VStack(spacing: 12) {
                SettingsActionRow(
                    icon: "qrcode",
                    title: "Scan QR Code",
                    message: "Connect or reconnect WhatsApp on this Mac.",
                    buttonTitle: "Open QR Code"
                ) {
                    NSApp.activate(ignoringOtherApps: true)
                    state.openOnboarding(page: 1)
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
                    title: "Reinstall",
                    message: "Run setup again to repair the installation.",
                    buttonTitle: "Reinstall"
                ) {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "installer")
                }
            }
            .padding(22)

            Spacer()
        }
    }
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
