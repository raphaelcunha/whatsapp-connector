import Foundation
import AppKit

/// Drives the install steps end-to-end. Updates `AppState` as it goes.
final class Installer {

    @MainActor
    func runAll(_ state: AppState) async {
        guard !state.isInstalling else { return }
        state.isInstalling = true
        defer { state.isInstalling = false }

        // reset state
        for i in state.steps.indices { state.steps[i].status = .pending }
        state.installerLog.removeAll()
        state.appendLog("Starting installation…", stream: .info)

        let order = state.steps.map(\.id)
        for (idx, id) in order.enumerated() {
            state.currentStepIndex = idx
            state.steps[idx].status = .running
            let ok = await runStep(id: id, state: state)
            state.steps[idx].status = ok ? .done : .failed
            if !ok {
                state.appendLog("✗ Step '\(id)' failed. Aborting.", stream: .failure)
                return
            }
        }

        state.currentStepIndex = -1
        state.appendLog("✓ All done!", stream: .success)
        state.refresh()
    }

    @MainActor
    private func runStep(id: String, state: AppState) async -> Bool {
        switch id {
        case "xcode":      return await checkXcodeCLT(state)
        case "brew":       return await checkBrew(state)
        case "brew-pkgs":  return await brewInstallPackages(state)
        case "clone":      return await cloneRepo(state)
        case "build":      return await buildBridge(state)
        case "uv-sync":    return await uvSync(state)
        case "plist":      return await writeLaunchAgent(state)
        case "qr":         return await scanQRCode(state)
        case "launch":     return await loadLaunchAgent(state)
        case "claude-mcp": return await registerMCP(state)
        default: return false
        }
    }

    // MARK: - Steps

    @MainActor
    private func checkXcodeCLT(_ state: AppState) async -> Bool {
        state.appendLog("Checking Xcode Command Line Tools…", stream: .info)
        let res = ShellRunner.runSync("/usr/bin/xcode-select", ["-p"])
        if res.exitCode == 0 {
            state.appendLog("✓ Already installed at \(res.stdout.trimmingCharacters(in: .whitespacesAndNewlines))", stream: .success)
            return true
        }
        state.appendLog("Triggering Xcode CLT installer (system dialog will appear)…", stream: .info)
        _ = ShellRunner.runSync("/usr/bin/xcode-select", ["--install"])
        // Poll until installed (up to 5 minutes)
        for _ in 0..<60 {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if ShellRunner.runSync("/usr/bin/xcode-select", ["-p"]).exitCode == 0 {
                state.appendLog("✓ Xcode CLT installed", stream: .success)
                return true
            }
            state.appendLog("…still waiting for CLT install (click Install in the dialog)", stream: .info)
        }
        state.appendLog("Timed out waiting for Xcode CLT", stream: .failure)
        return false
    }

    @MainActor
    private func checkBrew(_ state: AppState) async -> Bool {
        state.appendLog("Checking Homebrew…", stream: .info)
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
            || FileManager.default.fileExists(atPath: "/usr/local/bin/brew") {
            state.appendLog("✓ Homebrew already present", stream: .success)
            return true
        }
        state.appendLog("Installing Homebrew (you'll be prompted for your password)…", stream: .info)
        let snippet = #"NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#
        let code = await ShellRunner.runShellStream(snippet) { line, isErr in
            Task { @MainActor in state.appendLog(line, stream: isErr ? .stderr : .stdout) }
        }
        if code == 0 {
            state.appendLog("✓ Homebrew installed", stream: .success)
            return true
        }
        state.appendLog("Homebrew install failed (exit \(code))", stream: .failure)
        return false
    }

    @MainActor
    private func brewInstallPackages(_ state: AppState) async -> Bool {
        state.appendLog("Installing go and uv via brew…", stream: .info)
        let code = await ShellRunner.runShellStream("brew install go uv") { line, isErr in
            Task { @MainActor in state.appendLog(line, stream: isErr ? .stderr : .stdout) }
        }
        if code == 0 {
            state.appendLog("✓ Packages ready", stream: .success)
            return true
        }
        return false
    }

    @MainActor
    private func cloneRepo(_ state: AppState) async -> Bool {
        let bridge = state.bridge
        let dir = bridge.srcDir
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git").path) {
            state.appendLog("Repository present — pulling latest…", stream: .info)
            let code = await ShellRunner.runShellStream("git -C '\(dir.path)' pull --ff-only || true") { line, isErr in
                Task { @MainActor in state.appendLog(line, stream: isErr ? .stderr : .stdout) }
            }
            return code == 0
        }
        state.appendLog("Cloning lharries/whatsapp-mcp into \(dir.path)…", stream: .info)
        let parent = dir.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let code = await ShellRunner.runShellStream("git clone https://github.com/lharries/whatsapp-mcp.git '\(dir.path)'") { line, isErr in
            Task { @MainActor in state.appendLog(line, stream: isErr ? .stderr : .stdout) }
        }
        return code == 0
    }

    @MainActor
    private func buildBridge(_ state: AppState) async -> Bool {
        let dir = state.bridge.bridgeDir
        guard await prepareBridgeSource(state) else { return false }
        state.appendLog("Building Go bridge in \(dir.path)…", stream: .info)
        let code = await ShellRunner.runShellStream("cd '\(dir.path)' && go build -o whatsapp-client .") { line, isErr in
            Task { @MainActor in state.appendLog(line, stream: isErr ? .stderr : .stdout) }
        }
        if code == 0 && FileManager.default.fileExists(atPath: state.bridge.bridgeBinary.path) {
            state.appendLog("✓ Built whatsapp-client", stream: .success)
            return true
        }
        return false
    }

    @MainActor
    private func prepareBridgeSource(_ state: AppState) async -> Bool {
        let dir = state.bridge.bridgeDir
        let mainFile = dir.appendingPathComponent("main.go")
        state.appendLog("Preparing WhatsApp connection support…", stream: .info)

        let updateCode = await ShellRunner.runShellStream("cd '\(dir.path)' && go get go.mau.fi/whatsmeow@latest && go mod tidy") { line, isErr in
            Task { @MainActor in state.appendLog(line, stream: isErr ? .stderr : .stdout) }
        }
        guard updateCode == 0 else { return false }

        do {
            var source = try String(contentsOf: mainFile, encoding: .utf8)
            source = source.replacingOccurrences(of: "client.Download(downloader)", with: "client.Download(context.Background(), downloader)")
            source = source.replacingOccurrences(of: #"sqlstore.New("sqlite3","#, with: #"sqlstore.New(context.Background(), "sqlite3","#)
            source = source.replacingOccurrences(of: "container.GetFirstDevice()", with: "container.GetFirstDevice(context.Background())")
            source = source.replacingOccurrences(of: "client.GetGroupInfo(jid)", with: "client.GetGroupInfo(context.Background(), jid)")
            source = source.replacingOccurrences(of: "client.Store.Contacts.GetContact(jid)", with: "client.Store.Contacts.GetContact(context.Background(), jid)")

            if !source.contains("QR_CODE:") {
                source = source.replacingOccurrences(
                    of: #"fmt.Println("\nScan this QR code with your WhatsApp app:")"#,
                    with: #"fmt.Println("QR_CODE:" + evt.Code)"# + "\n\t\t\t\t\t" + #"fmt.Println("\nScan this QR code with your WhatsApp app:")"#
                )
            }
            if !source.contains("QR_DONE") {
                source = source.replacingOccurrences(
                    of: #"fmt.Println("\nSuccessfully connected and authenticated!")"#,
                    with: #"fmt.Println("QR_DONE")"# + "\n\t\t\t" + #"fmt.Println("\nSuccessfully connected and authenticated!")"#
                )
            }

            try source.write(to: mainFile, atomically: true, encoding: .utf8)
            state.appendLog("✓ WhatsApp bridge ready", stream: .success)
            return true
        } catch {
            state.appendLog("Failed to prepare bridge source: \(error)", stream: .failure)
            return false
        }
    }

    @MainActor
    private func uvSync(_ state: AppState) async -> Bool {
        let dir = state.bridge.serverDir
        state.appendLog("Installing Python deps via uv sync…", stream: .info)
        let code = await ShellRunner.runShellStream("cd '\(dir.path)' && uv sync") { line, isErr in
            Task { @MainActor in state.appendLog(line, stream: isErr ? .stderr : .stdout) }
        }
        return code == 0
    }

    @MainActor
    private func writeLaunchAgent(_ state: AppState) async -> Bool {
        let bridge = state.bridge
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(bridge.label)</string>
            <key>ProgramArguments</key><array><string>\(bridge.bridgeBinary.path)</string></array>
            <key>WorkingDirectory</key><string>\(bridge.bridgeDir.path)</string>
            <key>RunAtLoad</key><true/>
            <key>KeepAlive</key><dict>
                <key>SuccessfulExit</key><false/>
                <key>Crashed</key><true/>
            </dict>
            <key>ThrottleInterval</key><integer>10</integer>
            <key>StandardOutPath</key><string>\(bridge.logFile.path)</string>
            <key>StandardErrorPath</key><string>\(bridge.errFile.path)</string>
            <key>EnvironmentVariables</key><dict>
                <key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
            </dict>
            <key>ProcessType</key><string>Background</string>
        </dict>
        </plist>
        """
        do {
            try FileManager.default.createDirectory(at: bridge.plistPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try plist.write(to: bridge.plistPath, atomically: true, encoding: .utf8)
            state.appendLog("✓ Wrote LaunchAgent: \(bridge.plistPath.path)", stream: .success)
            return true
        } catch {
            state.appendLog("Failed to write plist: \(error)", stream: .failure)
            return false
        }
    }

    @MainActor
    private func scanQRCode(_ state: AppState) async -> Bool {
        let bridge = state.bridge
        state.appendLog("Opening the onboarding window so you can scan the QR code…", stream: .info)
        state.awaitingQRScan = true
        defer { state.awaitingQRScan = false }

        // Bring up the onboarding window so the user sees the full post-install flow.
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            state.openOnboarding(page: 1)
        }

        // Poll for session DB up to 5 minutes
        for _ in 0..<60 {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if bridge.hasSession() {
                state.appendLog("✓ Session linked", stream: .success)
                return true
            }
        }
        state.appendLog("Timed out waiting for QR scan", stream: .failure)
        return false
    }

    @MainActor
    private func loadLaunchAgent(_ state: AppState) async -> Bool {
        let bridge = state.bridge
        // Unload first (idempotent)
        _ = ShellRunner.runSync("/bin/launchctl", ["unload", bridge.plistPath.path])
        let res = ShellRunner.runSync("/bin/launchctl", ["load", bridge.plistPath.path])
        if res.exitCode != 0 {
            state.appendLog("launchctl load failed: \(res.stderr)", stream: .failure)
            return false
        }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if bridge.isListening() {
            state.appendLog("✓ Bridge running on :\(bridge.port)", stream: .success)
            return true
        }
        state.appendLog("Service loaded but not listening yet — check logs", stream: .stderr)
        return true // still consider success; service may take a moment
    }

    @MainActor
    private func registerMCP(_ state: AppState) async -> Bool {
        let bridge = state.bridge
        let configURL = bridge.home.appendingPathComponent(".claude.json")
        let uvPath = "/opt/homebrew/bin/uv" // brew already installed it
        let serverPath = bridge.serverDir.path
        let preferredAgent = UserDefaults.standard.string(forKey: "preferredAgent") ?? "claude"

        if preferredAgent == "codex" {
            return registerCodexMCP(state: state, uvPath: uvPath, serverPath: serverPath)
        }

        if preferredAgent == "other" {
            state.appendLog("✓ Manual MCP configuration selected — skipping automatic agent setup", stream: .success)
            return true
        }

        // Try the official CLI first
        let cliCheck = ShellRunner.runSync("/bin/bash", ["-lc", "command -v claude"])
        if cliCheck.exitCode == 0 {
            state.appendLog("Registering via 'claude mcp add'…", stream: .info)
            let cmd = "claude mcp add whatsapp --scope user -- '\(uvPath)' --directory '\(serverPath)' run main.py"
            let code = await ShellRunner.runShellStream(cmd) { line, isErr in
                Task { @MainActor in state.appendLog(line, stream: isErr ? .stderr : .stdout) }
            }
            if code == 0 {
                state.appendLog("✓ Registered with Claude Code", stream: .success)
                return true
            }
            state.appendLog("'claude mcp add' returned \(code) — falling back to direct edit", stream: .stderr)
        }

        // Fallback: edit ~/.claude.json directly
        state.appendLog("Editing \(configURL.path) directly…", stream: .info)
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = obj
        }
        var servers = (json["mcpServers"] as? [String: Any]) ?? [:]
        servers["whatsapp"] = [
            "type": "stdio",
            "command": uvPath,
            "args": ["--directory", serverPath, "run", "main.py"],
            "env": [String: String]()
        ]
        json["mcpServers"] = servers
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: configURL, options: .atomic)
            state.appendLog("✓ Wrote MCP entry to \(configURL.path)", stream: .success)
            return true
        } catch {
            state.appendLog("Failed to write claude config: \(error)", stream: .failure)
            return false
        }
    }

    @MainActor
    private func registerCodexMCP(state: AppState, uvPath: String, serverPath: String) -> Bool {
        let configURL = state.bridge.home.appendingPathComponent(".codex/config.toml")
        let block = """

        [mcp_servers.whatsapp]
        command = "\(uvPath)"
        args = ["--directory", "\(serverPath)", "run", "main.py"]
        """

        do {
            try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let existing = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
            let updated = replacingTOMLBlock(named: "mcp_servers.whatsapp", in: existing, with: block)
            try updated.write(to: configURL, atomically: true, encoding: .utf8)
            state.appendLog("✓ Registered with Codex", stream: .success)
            return true
        } catch {
            state.appendLog("Failed to write Codex config: \(error)", stream: .failure)
            return false
        }
    }

    private func replacingTOMLBlock(named name: String, in content: String, with replacement: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let header = "[\(name)]"

        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == header }) else {
            let separator = content.hasSuffix("\n") || content.isEmpty ? "" : "\n"
            return content + separator + replacement.trimmingCharacters(in: .newlines) + "\n"
        }

        var end = start + 1
        while end < lines.count {
            let trimmed = lines[end].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                break
            }
            end += 1
        }

        var updated = Array(lines[..<start])
        updated.append(contentsOf: replacement.trimmingCharacters(in: .newlines).split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        updated.append(contentsOf: lines[end...])
        return updated.joined(separator: "\n") + "\n"
    }
}
