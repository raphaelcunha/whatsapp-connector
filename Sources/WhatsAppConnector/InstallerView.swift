import SwiftUI
import AppKit

struct InstallerView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if !state.isRunningFromApplications {
            ApplicationInstallLocationView()
                .environmentObject(state)
        } else {
            setupView
        }
    }

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: state.menuBarIcon)
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(headerTint)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Install WhatsApp Connector")
                        .font(.title)
                        .bold()
                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }
            .padding(20)

            Divider()

            mainPane
            .frame(maxHeight: .infinity)

            Divider()

            // Footer — actions
            HStack {
                if state.awaitingQRScan {
                    Label("Scan the QR Code in the window that opened", systemImage: "qrcode")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") {
                    if let win = NSApp.windows.first(where: { $0.identifier?.rawValue == "installer" }) {
                        win.close()
                    }
                }
                .keyboardShortcut(.cancelAction)
                .disabled(state.isInstalling)

                Button(primaryButtonTitle) {
                    Task { await state.installer.runAll(state) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(state.isInstalling)
            }
            .padding(16)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var mainPane: some View {
        if state.installStatus == .installed && !state.isInstalling {
            reinstallPane
        } else {
            installPane
        }
    }

    private var headerTint: Color {
        switch state.installStatus {
        case .installed: return .green
        case .notInstalled: return .orange
        case .unknown: return .secondary
        }
    }

    private var headerSubtitle: String {
        if state.isInstalling {
            return "This can take a few minutes. Keep this window open."
        }
        switch state.installStatus {
        case .installed:
            return "Everything is ready. Run setup again only if you need to repair it."
        case .notInstalled:
            return "No pre-install needed. We'll prepare everything during setup."
        case .unknown:
            return "Checking..."
        }
    }

    private var primaryButtonTitle: String {
        if state.isInstalling { return "Installing..." }
        return state.installStatus == .installed ? "Repair setup" : "Install"
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.runStatus == .running ? .green : .gray)
                .frame(width: 8, height: 8)
            Text(state.runStatus == .running ? "Running" : "Stopped")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
    }

    private var installPane: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 24)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(phaseTint.opacity(0.12))
                        .frame(width: 108, height: 108)
                    Image(systemName: phaseIcon)
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(phaseTint)
                }

                VStack(spacing: 8) {
                    Text(phaseTitle)
                        .font(.system(size: 27, weight: .bold))
                    Text(phaseMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 470)
                }

                VStack(spacing: 12) {
                    ProgressView(value: installProgress)
                        .tint(Color.accentColor)
                        .frame(maxWidth: 460)

                    HStack(spacing: 10) {
                        ForEach(InstallPhase.allCases, id: \.self) { phase in
                            FriendlyPhasePill(
                                title: phase.title,
                                icon: phase.icon,
                                state: visualState(for: phase)
                            )
                        }
                    }
                }
            }

            if let problemMessage {
                FriendlyMessageBox(icon: "exclamationmark.triangle.fill", title: "Setup could not finish", message: problemMessage, tint: .orange)
                    .frame(maxWidth: 520)
            } else if !state.isInstalling {
                FriendlyMessageBox(icon: "lock.shield.fill", title: "Private and local", message: "WhatsApp Connector runs on your Mac and appears as an icon in the menu bar.", tint: Color.accentColor)
                    .frame(maxWidth: 520)
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 48)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var reinstallPane: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 28)

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.13))
                    .frame(width: 96, height: 96)
                Image(systemName: state.runStatus == .running ? "checkmark.circle.fill" : "wrench.and.screwdriver.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(state.runStatus == .running ? .green : .orange)
            }

            VStack(spacing: 8) {
                Text(state.runStatus == .running ? "WhatsApp Connector is ready" : "WhatsApp Connector is installed")
                    .font(.system(size: 24, weight: .bold))
                Text(reinstallMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 12) {
                StatusPill(icon: "checkmark.seal.fill", text: "App installed")
                StatusPill(icon: state.runStatus == .running ? "bolt.fill" : "pause.circle.fill",
                           text: state.runStatus == .running ? "Running" : "Stopped")
                StatusPill(icon: state.bridge.hasSession() ? "link.circle.fill" : "qrcode",
                           text: state.bridge.hasSession() ? "WhatsApp connected" : "QR pending")
            }

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 44)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var reinstallMessage: String {
        if state.runStatus == .running {
            return "You can close this window and use the menu bar icon. If something stops working, run setup again."
        }
        return "The app is already installed. Open it from the menu bar icon, or run setup again to repair it."
    }

    private var currentPhase: InstallPhase {
        guard state.isInstalling else { return .prepare }
        guard state.currentStepIndex >= 0, state.currentStepIndex < state.steps.count else { return .prepare }

        switch state.steps[state.currentStepIndex].id {
        case "qr":
            return .connect
        case "launch":
            return .activate
        case "claude-mcp":
            return .finish
        default:
            return .prepare
        }
    }

    private var hasFailure: Bool {
        state.steps.contains { $0.status == .failed }
    }

    private var problemMessage: String? {
        guard hasFailure else { return nil }
        return "Try again. If the problem continues, open Logs from the WhatsApp Connector menu."
    }

    private var installProgress: Double {
        if state.installStatus == .installed && !state.isInstalling { return 1 }
        if !state.isInstalling { return 0 }

        switch currentPhase {
        case .prepare:
            let hiddenStepCount = max(index(for: "qr"), 1)
            let completed = min(max(state.currentStepIndex, 0), hiddenStepCount)
            return 0.10 + (Double(completed) / Double(hiddenStepCount)) * 0.35
        case .connect:
            return 0.56
        case .activate:
            return 0.78
        case .finish:
            return 0.92
        }
    }

    private var phaseTitle: String {
        if hasFailure { return "Something needs attention" }
        if !state.isInstalling { return "Ready to start" }

        switch currentPhase {
        case .prepare:
            return "Preparing the app"
        case .connect:
            return "Connect WhatsApp"
        case .activate:
            return "Adding it to the menu bar"
        case .finish:
            return "Finishing"
        }
    }

    private var phaseMessage: String {
        if hasFailure {
            return "Setup stopped before finishing. You can try again now."
        }
        if !state.isInstalling {
            return "Click Install. We'll install anything this Mac needs, then you'll scan a QR Code."
        }

        switch currentPhase {
        case .prepare:
            return "We're checking this Mac and installing any required tools automatically."
        case .connect:
            return "Use your phone to scan the QR Code. Setup continues automatically after it connects."
        case .activate:
            return "We're adding WhatsApp Connector to the macOS menu bar for quick access."
        case .finish:
            return "We're finishing the last details. Almost done."
        }
    }

    private var phaseIcon: String {
        if hasFailure { return "exclamationmark.triangle.fill" }
        if !state.isInstalling { return "sparkles" }

        switch currentPhase {
        case .prepare: return "arrow.down.app.fill"
        case .connect: return "qrcode"
        case .activate: return "menubar.rectangle"
        case .finish: return "checkmark.seal.fill"
        }
    }

    private var phaseTint: Color {
        if hasFailure { return .orange }
        if state.isInstalling { return Color.accentColor }
        return .green
    }

    private func index(for id: String) -> Int {
        state.steps.firstIndex(where: { $0.id == id }) ?? 0
    }

    private func visualState(for phase: InstallPhase) -> FriendlyPhasePill.VisualState {
        if hasFailure && phase == currentPhase { return .failed }
        guard state.isInstalling else { return .pending }

        if phase.rawValue < currentPhase.rawValue { return .done }
        if phase == currentPhase { return .running }
        return .pending
    }
}

private enum InstallPhase: Int, CaseIterable {
    case prepare
    case connect
    case activate
    case finish

    var title: String {
        switch self {
        case .prepare: return "Prepare"
        case .connect: return "Connect"
        case .activate: return "Activate"
        case .finish: return "Finish"
        }
    }

    var icon: String {
        switch self {
        case .prepare: return "arrow.down.app.fill"
        case .connect: return "qrcode"
        case .activate: return "menubar.rectangle"
        case .finish: return "checkmark"
        }
    }
}

private struct FriendlyPhasePill: View {
    enum VisualState {
        case pending
        case running
        case done
        case failed
    }

    let title: String
    let icon: String
    let state: VisualState

    var body: some View {
        HStack(spacing: 7) {
            marker
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(background)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var marker: some View {
        switch state {
        case .pending:
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
        case .running:
            ProgressView()
                .controlSize(.mini)
                .frame(width: 12, height: 12)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
        }
    }

    private var foreground: Color {
        switch state {
        case .pending: return .secondary
        case .running: return Color.accentColor
        case .done: return .green
        case .failed: return .orange
        }
    }

    private var background: Color {
        switch state {
        case .pending: return Color(nsColor: .controlBackgroundColor)
        case .running: return Color.accentColor.opacity(0.10)
        case .done: return Color.green.opacity(0.10)
        case .failed: return Color.orange.opacity(0.12)
        }
    }
}

private struct FriendlyMessageBox: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.11))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StatusPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
    }
}

private struct ApplicationInstallLocationView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 28)

            VStack(spacing: 10) {
                Text("Move WhatsApp Connector to Applications")
                    .font(.system(size: 28, weight: .bold))
                Text("Drag the app into the Applications folder, then open it from there to continue setup.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 470)
                    .lineSpacing(3)
            }

            HStack(spacing: 24) {
                InstallTile(title: "WhatsApp Connector", subtitle: "This app") {
                    ModernAppIcon()
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                InstallTile(title: "Applications", subtitle: "Drop it here") {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 8)

            VStack(spacing: 8) {
                Text("Current location")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(state.appBundleURL.path)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Spacer(minLength: 18)

            HStack(spacing: 12) {
                Button("Open Applications") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
                }
                .controlSize(.large)

                Button("Quit and reopen") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 26)
        }
        .frame(width: 680, height: 520)
        .padding(.horizontal, 42)
        .background(
            LinearGradient(
                colors: [
                    Color.green.opacity(0.13),
                    Color.teal.opacity(0.08),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct InstallTile<Content: View>: View {
    let title: String
    let subtitle: String
    let content: () -> Content

    init(title: String, subtitle: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 6)
                content()
            }
            .frame(width: 118, height: 104)

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 150)
    }
}
