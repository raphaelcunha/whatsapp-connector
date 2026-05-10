import Foundation
import AppKit

/// Wraps the launchctl-managed whatsapp-bridge service.
/// All paths are derived from $HOME so the same code works for any user.
final class BridgeController {

    let port: Int32 = 8080
    let label: String = "com.\(NSUserName()).whatsapp-bridge"

    var home: URL { URL(fileURLWithPath: NSHomeDirectory()) }
    var srcDir: URL { home.appendingPathComponent("src/whatsapp-mcp") }
    var bridgeDir: URL { srcDir.appendingPathComponent("whatsapp-bridge") }
    var serverDir: URL { srcDir.appendingPathComponent("whatsapp-mcp-server") }
    var bridgeBinary: URL { bridgeDir.appendingPathComponent("whatsapp-client") }
    var sessionDB: URL { bridgeDir.appendingPathComponent("store/whatsapp.db") }
    var messagesDB: URL { bridgeDir.appendingPathComponent("store/messages.db") }
    var plistPath: URL { home.appendingPathComponent("Library/LaunchAgents/\(label).plist") }
    var logFile: URL { home.appendingPathComponent("Library/Logs/whatsapp-bridge.log") }
    var errFile: URL { home.appendingPathComponent("Library/Logs/whatsapp-bridge.err.log") }

    // MARK: - Status

    func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: bridgeBinary.path)
            && FileManager.default.fileExists(atPath: plistPath.path)
    }

    func hasSession() -> Bool {
        guard FileManager.default.fileExists(atPath: sessionDB.path) else { return false }
        let query = "SELECT COUNT(*) FROM whatsmeow_device WHERE jid IS NOT NULL AND jid != '';"
        let out = ShellRunner.runSync("/usr/bin/sqlite3", [sessionDB.path, query])
        return out.stdout.trimmingCharacters(in: .whitespacesAndNewlines) != "0"
    }

    @discardableResult
    func resetSessionForPairing() -> Bool {
        stop()
        let fm = FileManager.default
        let paths = [
            sessionDB.path,
            sessionDB.path + "-wal",
            sessionDB.path + "-shm"
        ]
        for path in paths where fm.fileExists(atPath: path) {
            try? fm.removeItem(atPath: path)
        }
        return true
    }

    func isLoaded() -> Bool {
        let out = ShellRunner.runSync("/bin/launchctl", ["list"])
        return out.stdout.contains(label)
    }

    func isListening() -> Bool {
        let out = ShellRunner.runSync("/usr/sbin/lsof", ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"])
        return !out.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func currentStatus() -> AppState.RunStatus {
        if isListening() { return .running }
        if isLoaded() { return .crashed }
        return .stopped
    }

    // MARK: - Control

    @discardableResult
    func start() -> Bool {
        let res = ShellRunner.runSync("/bin/launchctl", ["load", plistPath.path])
        return res.exitCode == 0
    }

    @discardableResult
    func stop() -> Bool {
        _ = ShellRunner.runSync("/bin/launchctl", ["unload", plistPath.path])
        _ = ShellRunner.runSync("/usr/bin/pkill", ["-f", bridgeBinary.path])
        return true
    }

    @discardableResult
    func restart() -> Bool {
        stop()
        usleep(800_000)
        return start()
    }

    func openLogs() {
        NSWorkspace.shared.open(logFile)
    }

    func openInFinder(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
