import Foundation

struct MCPConfigurationResult {
    let success: Bool
    let message: String
    let detail: String?
}

enum MCPConfigurator {

    static func installClaude(bridge: BridgeController) async -> MCPConfigurationResult {
        let homePath = bridge.home.path
        let serverPath = bridge.serverDir.path
        let uvPath = resolvedUVPath()

        return await runOffMain {
            let cliCheck = ShellRunner.runSync("/bin/bash", ["-lc", "command -v claude"])
            if cliCheck.exitCode == 0 {
                let command = "claude mcp add whatsapp --scope user -- \(shellQuoted(uvPath)) --directory \(shellQuoted(serverPath)) run main.py"
                let result = ShellRunner.runSync("/bin/bash", ["-lc", command])
                if result.exitCode == 0 {
                    return MCPConfigurationResult(
                        success: true,
                        message: "Registered WhatsApp MCP in Claude Code.",
                        detail: nil
                    )
                }

                let fallback = writeClaudeConfig(homePath: homePath, uvPath: uvPath, serverPath: serverPath)
                if fallback.success {
                    return MCPConfigurationResult(
                        success: true,
                        message: "Registered WhatsApp MCP in Claude Code config.",
                        detail: "Claude CLI failed, so the app updated ~/.claude.json directly."
                    )
                }

                return MCPConfigurationResult(
                    success: false,
                    message: "Could not register WhatsApp MCP in Claude Code.",
                    detail: fallback.detail ?? result.stderr
                )
            }

            return writeClaudeConfig(homePath: homePath, uvPath: uvPath, serverPath: serverPath)
        }
    }

    static func installCodex(bridge: BridgeController) async -> MCPConfigurationResult {
        let configPath = bridge.home.appendingPathComponent(".codex/config.toml").path
        let serverPath = bridge.serverDir.path
        let uvPath = resolvedUVPath()

        return await runOffMain {
            do {
                let configURL = URL(fileURLWithPath: configPath)
                try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                let existing = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
                let updated = replacingTOMLBlock(
                    named: "mcp_servers.whatsapp",
                    in: existing,
                    with: codexTomlSnippet(uvPath: uvPath, serverPath: serverPath)
                )
                try updated.write(to: configURL, atomically: true, encoding: .utf8)

                return MCPConfigurationResult(
                    success: true,
                    message: "Registered WhatsApp MCP in Codex.",
                    detail: nil
                )
            } catch {
                return MCPConfigurationResult(
                    success: false,
                    message: "Could not register WhatsApp MCP in Codex.",
                    detail: "\(error)"
                )
            }
        }
    }

    static func claudeManualSetup(bridge: BridgeController) -> String {
        let uvPath = resolvedUVPath()
        let serverPath = bridge.serverDir.path
        return """
        Run this command in Terminal:

        claude mcp add whatsapp --scope user -- \(shellQuoted(uvPath)) --directory \(shellQuoted(serverPath)) run main.py
        """
    }

    static func codexManualSetup(bridge: BridgeController) -> String {
        codexTomlSnippet(uvPath: resolvedUVPath(), serverPath: bridge.serverDir.path)
    }

    static func otherManualSetup(bridge: BridgeController) -> String {
        """
        Configure an MCP server named "whatsapp" with these values:

        command: \(resolvedUVPath())
        args:
          - --directory
          - \(bridge.serverDir.path)
          - run
          - main.py
        """
    }

    private static func writeClaudeConfig(homePath: String, uvPath: String, serverPath: String) -> MCPConfigurationResult {
        let configURL = URL(fileURLWithPath: homePath).appendingPathComponent(".claude.json")

        do {
            var json: [String: Any] = [:]
            if let data = try? Data(contentsOf: configURL),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                json = object
            }

            var servers = (json["mcpServers"] as? [String: Any]) ?? [:]
            servers["whatsapp"] = [
                "type": "stdio",
                "command": uvPath,
                "args": ["--directory", serverPath, "run", "main.py"],
                "env": [String: String]()
            ]
            json["mcpServers"] = servers

            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: configURL, options: .atomic)

            return MCPConfigurationResult(
                success: true,
                message: "Registered WhatsApp MCP in Claude Code config.",
                detail: nil
            )
        } catch {
            return MCPConfigurationResult(
                success: false,
                message: "Could not update Claude Code config.",
                detail: "\(error)"
            )
        }
    }

    private static func resolvedUVPath() -> String {
        let candidates = [
            "/opt/homebrew/bin/uv",
            "/usr/local/bin/uv"
        ]

        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }

        let lookup = ShellRunner.runSync("/bin/bash", ["-lc", "command -v uv"])
        let path = lookup.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? "uv" : path
    }

    private static func codexTomlSnippet(uvPath: String, serverPath: String) -> String {
        """
        [mcp_servers.whatsapp]
        command = "\(tomlEscaped(uvPath))"
        args = ["--directory", "\(tomlEscaped(serverPath))", "run", "main.py"]
        """
    }

    private static func replacingTOMLBlock(named name: String, in content: String, with replacement: String) -> String {
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

    private static func runOffMain(_ work: @escaping () -> MCPConfigurationResult) async -> MCPConfigurationResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: work())
            }
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func tomlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
