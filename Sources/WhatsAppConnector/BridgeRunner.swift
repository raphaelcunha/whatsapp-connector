import Foundation

/// Runs the bridge in foreground and exposes its stdout via callbacks.
/// Used by the QR onboarding screen to capture the raw QR code line and the
/// "QR_DONE" success marker produced by the patched bridge.
@MainActor
final class BridgeRunner: ObservableObject {

    @Published var qrCode: String? = nil
    @Published var connected: Bool = false
    @Published var isRunning: Bool = false
    @Published var lastError: String? = nil

    private var process: Process? = nil

    func start(binary: URL, workdir: URL) {
        guard !isRunning else { return }
        qrCode = nil
        connected = false
        lastError = nil

        let p = Process()
        p.executableURL = binary
        p.currentDirectoryURL = workdir

        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            guard let s = String(data: data, encoding: .utf8) else { return }
            for raw in s.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = String(raw)
                if line.hasPrefix("QR_CODE:") {
                    let code = String(line.dropFirst("QR_CODE:".count))
                    Task { @MainActor in self?.qrCode = code }
                } else if line.contains("QR_DONE") || line.contains("Successfully connected and authenticated") {
                    Task { @MainActor in self?.connected = true }
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let s = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.lastError = s }
        }

        p.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.isRunning = false }
        }

        do {
            try p.run()
            process = p
            isRunning = true
        } catch {
            lastError = "Failed to launch bridge: \(error)"
        }
    }

    func stop() {
        guard let p = process else { return }
        if p.isRunning { p.terminate() }
        process = nil
        isRunning = false
    }
}
