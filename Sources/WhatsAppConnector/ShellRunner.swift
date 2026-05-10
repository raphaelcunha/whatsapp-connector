import Foundation

/// Helpers to run shell processes — both blocking and streaming.
enum ShellRunner {

    struct Result {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    /// Run a command, wait for it to finish, return captured output.
    @discardableResult
    static func runSync(_ executable: String, _ args: [String], cwd: URL? = nil, env: [String: String]? = nil) -> Result {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = args
        if let cwd { p.currentDirectoryURL = cwd }
        if let env { p.environment = env }
        let outPipe = Pipe(); let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        do { try p.run() } catch {
            return Result(exitCode: -1, stdout: "", stderr: "failed to launch: \(error)")
        }

        var stdoutData = Data()
        var stderrData = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stdoutData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        p.waitUntilExit()
        group.wait()

        let so = String(data: stdoutData, encoding: .utf8) ?? ""
        let se = String(data: stderrData, encoding: .utf8) ?? ""
        return Result(exitCode: p.terminationStatus, stdout: so, stderr: se)
    }

    /// Run a command, stream stdout/stderr line-by-line via the callback. Returns exit code.
    static func runStream(_ executable: String, _ args: [String], cwd: URL? = nil, env: [String: String]? = nil, onLine: @escaping (_ line: String, _ isError: Bool) -> Void) async -> Int32 {
        await withCheckedContinuation { (cont: CheckedContinuation<Int32, Never>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: executable)
            p.arguments = args
            if let cwd { p.currentDirectoryURL = cwd }
            // Inherit current environment plus brew paths
            var fullEnv = ProcessInfo.processInfo.environment
            fullEnv["PATH"] = ["/opt/homebrew/bin", "/usr/local/bin", fullEnv["PATH"] ?? "", "/usr/bin", "/bin", "/usr/sbin", "/sbin"].filter { !$0.isEmpty }.joined(separator: ":")
            if let env { for (k, v) in env { fullEnv[k] = v } }
            p.environment = fullEnv

            let outPipe = Pipe(); let errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                if let s = String(data: data, encoding: .utf8) {
                    for line in s.split(separator: "\n", omittingEmptySubsequences: false) {
                        let l = String(line)
                        if !l.isEmpty {
                            DispatchQueue.main.async { onLine(l, false) }
                        }
                    }
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                if let s = String(data: data, encoding: .utf8) {
                    for line in s.split(separator: "\n", omittingEmptySubsequences: false) {
                        let l = String(line)
                        if !l.isEmpty {
                            DispatchQueue.main.async { onLine(l, true) }
                        }
                    }
                }
            }

            p.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                cont.resume(returning: proc.terminationStatus)
            }

            do { try p.run() } catch {
                cont.resume(returning: -1)
            }
        }
    }

    /// Run a shell snippet as `/bin/bash -lc "..."` with full env (PATH includes brew).
    static func runShellStream(_ snippet: String, cwd: URL? = nil, onLine: @escaping (_ line: String, _ isError: Bool) -> Void) async -> Int32 {
        await runStream("/bin/bash", ["-lc", snippet], cwd: cwd, onLine: onLine)
    }

    /// Run a privileged AppleScript "do shell script ... with administrator privileges".
    /// Returns the captured output (stdout+stderr combined). Throws on failure.
    @discardableResult
    static func runPrivileged(_ shell: String, prompt: String) throws -> String {
        let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\")
                           .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with prompt \"\(prompt)\" with administrator privileges"
        var error: NSDictionary?
        let apple = NSAppleScript(source: script)
        let descriptor = apple?.executeAndReturnError(&error)
        if let e = error {
            throw NSError(domain: "WhatsAppConnector.Privileged", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(e)"])
        }
        return descriptor?.stringValue ?? ""
    }
}
