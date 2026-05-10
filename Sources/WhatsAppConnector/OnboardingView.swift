import SwiftUI
import AppKit

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var page: Int = 0

    private let totalPages = 4

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                ZStack {
                    if page == 0 {
                        PresentationPage(advance: advance)
                            .transition(slide)
                    }
                    if page == 1 {
                        QRCodePage(advance: advance, back: back)
                            .environmentObject(state)
                            .transition(slide)
                    }
                    if page == 2 {
                        AgentSetupPage(advance: advance, back: back)
                            .transition(slide)
                    }
                    if page == 3 {
                        SuccessPage(close: close)
                            .environmentObject(state)
                            .transition(slide)
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.88), value: page)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.22))
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.35), value: page)
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .frame(width: 820, height: 620)
        .onAppear {
            page = state.requestedOnboardingPage
        }
        .onChange(of: state.requestedOnboardingPage) { _, requestedPage in
            page = requestedPage
        }
    }

    private var slide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        guard page < totalPages - 1 else { return }
        page += 1
    }

    private func back() {
        guard page > 0 else { return }
        page -= 1
    }

    private func close() {
        state.markInitialOnboardingCompleted()
        state.refresh()
        if let win = NSApp.windows.first(where: { $0.identifier?.rawValue == "onboarding" }) {
            win.close()
        }
    }
}

private struct OnboardingBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(red: 0.16, green: 0.81, blue: 0.42).opacity(0.08),
                Color(red: 0.05, green: 0.49, blue: 0.36).opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Page 1: Presentation

private struct PresentationPage: View {
    let advance: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 34) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    ModernAppIcon()
                        .frame(width: 72, height: 72)

                    Text("WhatsApp Connector")
                        .font(.system(size: 34, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                    Text("Connect WhatsApp once, then send messages from Claude, Codex, or any compatible MCP client.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .frame(maxWidth: 430, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    SetupPreviewRow(icon: "qrcode", title: "Scan the QR Code", detail: "Link this Mac from WhatsApp on your phone.")
                    SetupPreviewRow(icon: "bolt.fill", title: "Runs in the background", detail: "Access it anytime from the macOS menu bar.")
                    SetupPreviewRow(icon: "sparkles", title: "Choose your agent", detail: "Use it with Claude Code, Codex, or another MCP client.")
                }

                Spacer(minLength: 0)

                Button(action: advance) {
                    HStack(spacing: 8) {
                        Text("Get started")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 26)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .frame(width: 420, alignment: .leading)
            .layoutPriority(1)

            VStack(spacing: 0) {
                OnboardingNotificationPreview()
            }
            .frame(width: 290)
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 40)
    }
}

private struct SetupPreviewRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct OnboardingNotificationPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Setup")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 16)

            PreviewNotificationRow(title: "App installed", detail: "WhatsApp Connector is in Applications.", icon: "checkmark.circle.fill")
            Divider()
            PreviewNotificationRow(title: "Bridge configured", detail: "Local service is ready to start.", icon: "gearshape.fill")
            Divider()
            PreviewNotificationRow(title: "Ready to connect", detail: "Scan the QR Code in the next step.", icon: "qrcode")

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Progress")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("66%")
                        .font(.system(size: 14, weight: .bold))
                }
                ProgressView(value: 0.66)
                    .tint(Color.accentColor)
            }
            .padding(22)
        }
        .frame(height: 410)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 28, x: 0, y: 16)
    }
}

private struct PreviewNotificationRow: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor.opacity(0.8))
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(Circle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(minHeight: 82, alignment: .center)
    }
}

// MARK: - Page 2: QR Code

private struct QRCodePage: View {
    @EnvironmentObject var state: AppState
    let advance: () -> Void
    let back: () -> Void
    @StateObject private var runner = BridgeRunner()
    @State private var didAutoAdvance: Bool = false

    private var isConnected: Bool {
        runner.connected
    }

    var body: some View {
        HStack(spacing: 34) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generate QR Code")
                        .font(.system(size: 31, weight: .bold))
                    Text("Open WhatsApp on your phone, go to Linked Devices, and scan the code on the right.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    InstructionRow(number: "1", text: "Open WhatsApp on your phone.")
                    InstructionRow(number: "2", text: "Tap Settings, then Linked Devices.")
                    InstructionRow(number: "3", text: "Tap Link a Device and point the camera at this QR Code.")
                }

                Spacer()

                HStack {
                    Button("Back", action: back)
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                    Spacer()

                    Button(isConnected ? "Continue" : "Waiting for scan") {
                        if isConnected {
                            runner.stop()
                            state.refresh()
                            advance()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isConnected)
                    .opacity(isConnected ? 1 : 0.55)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            QRPanel(isConnected: isConnected, qrCode: runner.qrCode, error: runner.lastError)
                .frame(width: 300)
        }
        .padding(44)
        .onAppear { startCapture() }
        .onDisappear { runner.stop() }
        .onChange(of: runner.connected) { _, connected in
            guard connected else { return }
            finishConnection()
        }
    }

    private func startCapture() {
        didAutoAdvance = false
        guard state.bridge.isInstalled() else {
            runner.lastError = "WhatsApp Connector must be installed before it can generate a QR Code."
            return
        }
        state.bridge.resetSessionForPairing()
        runner.start(binary: state.bridge.bridgeBinary, workdir: state.bridge.bridgeDir)
    }

    private func finishConnection() {
        guard !didAutoAdvance else { return }
        didAutoAdvance = true
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            runner.stop()
            _ = ShellRunner.runSync("/bin/launchctl", ["unload", state.bridge.plistPath.path])
            _ = ShellRunner.runSync("/bin/launchctl", ["load", state.bridge.plistPath.path])
            state.refresh()
            try? await Task.sleep(nanoseconds: 500_000_000)
            advance()
        }
    }
}

private struct QRPanel: View {
    let isConnected: Bool
    let qrCode: String?
    let error: String?

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.10), radius: 28, x: 0, y: 16)

                if isConnected {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 68, weight: .semibold))
                            .foregroundStyle(.green)
                        Text("WhatsApp connected")
                            .font(.system(size: 17, weight: .semibold))
                    }
                } else if let qrCode,
                          let img = QRRenderer.image(from: qrCode) {
                    VStack(spacing: 14) {
                        Image(nsImage: img)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 216, height: 216)
                        Text("Code is valid for a few seconds")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } else if let error {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(.orange)
                        Text("Could not generate")
                            .font(.system(size: 14, weight: .semibold))
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 22)
                    }
                } else {
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Generating QR Code")
                            .font(.system(size: 14, weight: .semibold))
                        Text("This can take a moment.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 300)

            HStack(spacing: 8) {
                Circle()
                    .fill(isConnected ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(isConnected ? "Device linked" : "Waiting for your phone to scan")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct InstructionRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))
            Text(text)
                .font(.system(size: 13.5))
            Spacer()
        }
        .padding(13)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Page 3: Agent setup

private enum AgentOption: String, CaseIterable {
    case claude
    case codex
    case other

    var title: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .other: return "Other agent"
        }
    }

    var icon: String {
        switch self {
        case .claude: return "sparkles"
        case .codex: return "terminal.fill"
        case .other: return "square.stack.3d.up.fill"
        }
    }

    var detail: String {
        switch self {
        case .claude:
            return "Configured automatically at the end of setup."
        case .codex:
            return "Use the MCP configuration below in your Codex environment."
        case .other:
            return "Copy the same details into any MCP client."
        }
    }
}

private struct AgentSetupPage: View {
    let advance: () -> Void
    let back: () -> Void
    @AppStorage("preferredAgent") private var selectedAgentRaw: String = AgentOption.claude.rawValue

    private var selectedAgent: AgentOption {
        get { AgentOption(rawValue: selectedAgentRaw) ?? .claude }
        nonmutating set { selectedAgentRaw = newValue.rawValue }
    }

    var body: some View {
        HStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose your agent")
                        .font(.system(size: 31, weight: .bold))
                    Text("WhatsApp Connector works with Claude Code, Codex, and other MCP-compatible clients.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }

                VStack(spacing: 10) {
                    ForEach(AgentOption.allCases, id: \.self) { option in
                        AgentOptionRow(option: option, isSelected: option == selectedAgent) {
                            selectedAgent = option
                        }
                    }
                }

                Spacer()

                HStack {
                    Button("Back", action: back)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Spacer()
                    Button(action: advance) {
                        HStack(spacing: 8) {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AgentConfigPreview(option: selectedAgent)
                .frame(width: 300)
        }
        .padding(44)
    }
}

private struct AgentOptionRow: View {
    let option: AgentOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: option.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 42, height: 42)
                    .background((isSelected ? Color.accentColor : Color.secondary).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(.system(size: 14.5, weight: .semibold))
                    Text(option.detail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.45))
            }
            .padding(13)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AgentConfigPreview: View {
    let option: AgentOption

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: option.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(option.title)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }

            Text(previewMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 8) {
                Text("MCP Configuration")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(configSnippet)
                    .font(.system(size: 11.5, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Spacer()
        }
        .padding(22)
        .frame(height: 390)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 28, x: 0, y: 16)
    }

    private var previewMessage: String {
        switch option {
        case .claude:
            return "The installer adds WhatsApp Connector to Claude Code automatically. Nothing to copy."
        case .codex:
            return "Use these details if you want to configure Codex manually."
        case .other:
            return "Any MCP client can use the command below as a local server."
        }
    }

    private var configSnippet: String {
        switch option {
        case .claude:
            return "claude mcp add whatsapp --scope user -- uv --directory ~/src/whatsapp-mcp/whatsapp-mcp-server run main.py"
        case .codex:
            return """
            [mcp_servers.whatsapp]
            command = "uv"
            args = ["--directory", "~/src/whatsapp-mcp/whatsapp-mcp-server", "run", "main.py"]
            """
        case .other:
            return """
            command: uv
            args:
              - --directory
              - ~/src/whatsapp-mcp/whatsapp-mcp-server
              - run
              - main.py
            """
        }
    }
}

// MARK: - Page 4: Success

private struct SuccessPage: View {
    @EnvironmentObject var state: AppState
    let close: () -> Void

    var body: some View {
        HStack(spacing: 34) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("All set")
                        .font(.system(size: 32, weight: .bold))
                    Text(successMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    SetupPreviewRow(icon: "phone.fill", title: "WhatsApp connected", detail: "This Mac was linked as a trusted device.")
                    SetupPreviewRow(icon: "bolt.fill", title: "Running in the background", detail: "WhatsApp Connector stays ready whenever you need it.")
                    SetupPreviewRow(icon: "bubble.left.and.bubble.right.fill", title: "Use the menu bar", detail: "Open the menu at the top of macOS to start, stop, or adjust the app.")
                }

                Spacer()

                Button(action: close) {
                    HStack(spacing: 8) {
                        Text("Done")
                        Image(systemName: "checkmark")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MenuBarSuccessPreview(isRunning: state.runStatus == .running)
                .frame(width: 310)
        }
        .padding(44)
        .onAppear {
            state.refresh()
        }
    }

    private var successMessage: String {
        if state.runStatus == .running {
            return "WhatsApp Connector is already running in the macOS menu bar. You can close this window and use the app from the icon at the top."
        }
        return "The connection is ready. If the indicator is not running yet, wait a few seconds or start it from the menu bar."
    }
}

private struct MenuBarSuccessPreview: View {
    let isRunning: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Circle().fill(.red.opacity(0.72)).frame(width: 10, height: 10)
                Circle().fill(.yellow.opacity(0.82)).frame(width: 10, height: 10)
                Circle().fill(.green.opacity(0.80)).frame(width: 10, height: 10)
                Spacer()
                Text("macOS")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor))

            VStack(spacing: 26) {
                MacMenuBarMock(isRunning: isRunning)

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((isRunning ? Color.green : Color.orange).opacity(0.12))
                            .frame(width: 110, height: 110)
                        Image(systemName: isRunning ? "checkmark.circle.fill" : "clock.fill")
                            .font(.system(size: 58, weight: .semibold))
                            .foregroundStyle(isRunning ? .green : .orange)
                    }

                    VStack(spacing: 6) {
                        Text(isRunning ? "Running in the menu bar" : "Almost ready")
                            .font(.system(size: 19, weight: .bold))
                        Text(isRunning ? "Use the WhatsApp Connector icon at the top of the screen." : "The icon appears at the top as soon as the service starts.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .frame(maxWidth: 230)
                    }
                }

                Spacer()
            }
            .padding(22)
        }
        .frame(height: 415)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 28, x: 0, y: 16)
    }
}

private struct MacMenuBarMock: View {
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("Finder")
                .font(.system(size: 11, weight: .semibold))
            Spacer()
            Image(systemName: "wifi")
            Image(systemName: "battery.100")
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Circle()
                    .fill(isRunning ? .green : .orange)
                    .frame(width: 6, height: 6)
                    .offset(x: 4, y: -3)
            }
            Text("20:16")
                .font(.system(size: 11, weight: .medium))
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}
