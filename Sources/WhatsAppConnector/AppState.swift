import SwiftUI
import Combine

extension Notification.Name {
    static let openOnboarding = Notification.Name("WhatsAppConnector.openOnboarding")
}

@MainActor
final class AppState: ObservableObject {

    enum InstallStatus { case unknown, notInstalled, installed }
    enum RunStatus { case stopped, loading, running, crashed }

    @Published var installStatus: InstallStatus = .unknown
    @Published var runStatus: RunStatus = .stopped

    @Published var installerLog: [InstallerLine] = []
    @Published var isInstalling: Bool = false
    @Published var steps: [InstallerStep] = InstallerStep.defaults
    @Published var currentStepIndex: Int = -1
    @Published var awaitingQRScan: Bool = false
    @Published var requestedOnboardingPage: Int = 0

    let bridge = BridgeController()
    let installer = Installer()

    private var pollTask: Task<Void, Never>?

    init() {
        refresh()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self?.refresh()
            }
        }
    }

    deinit {
        pollTask?.cancel()
    }

    func refresh() {
        installStatus = bridge.isInstalled() ? .installed : .notInstalled
        runStatus = bridge.currentStatus()
    }

    var appBundleURL: URL {
        Bundle.main.bundleURL.standardizedFileURL
    }

    var isRunningFromApplications: Bool {
        appBundleURL.path.hasPrefix("/Applications/")
    }

    func openOnboarding(page: Int) {
        requestedOnboardingPage = min(max(page, 0), 3)
        NotificationCenter.default.post(name: .openOnboarding, object: nil)
    }

    var initialOnboardingSignature: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "WhatsAppConnector"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let modificationDate = (try? FileManager.default.attributesOfItem(atPath: appBundleURL.path)[.modificationDate] as? Date)
        let modifiedAt = Int(modificationDate?.timeIntervalSince1970 ?? 0)
        return "\(bundleID)|\(version)|\(build)|\(modifiedAt)"
    }

    func shouldShowInitialOnboarding() -> Bool {
        UserDefaults.standard.string(forKey: "completedInitialOnboardingSignature") != initialOnboardingSignature
    }

    func markInitialOnboardingCompleted() {
        UserDefaults.standard.set(initialOnboardingSignature, forKey: "completedInitialOnboardingSignature")
    }

    var menuBarIcon: String {
        if installStatus == .notInstalled { return "phone.badge.plus" }
        switch runStatus {
        case .running: return "phone.fill"
        case .crashed: return "phone.badge.waveform"
        case .stopped: return "phone.down.fill"
        case .loading: return "phone.connection.fill"
        }
    }

    func appendLog(_ text: String, stream: InstallerLine.Stream = .info) {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            installerLog.append(InstallerLine(stream: stream, text: String(line)))
        }
        if installerLog.count > 2000 {
            installerLog.removeFirst(installerLog.count - 2000)
        }
    }
}

struct InstallerLine: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let stream: Stream
    let text: String
    enum Stream { case stdout, stderr, info, success, failure }
}

struct InstallerStep: Identifiable, Equatable {
    let id: String
    let title: String
    var status: Status = .pending
    enum Status: Equatable { case pending, running, done, failed, skipped }

    static let defaults: [InstallerStep] = [
        .init(id: "xcode",        title: "Xcode Command Line Tools"),
        .init(id: "brew",         title: "Homebrew"),
        .init(id: "brew-pkgs",    title: "Install go and uv"),
        .init(id: "clone",        title: "Clone whatsapp-mcp repository"),
        .init(id: "build",        title: "Build the bridge binary"),
        .init(id: "uv-sync",      title: "Install Python dependencies"),
        .init(id: "plist",        title: "Create LaunchAgent service"),
        .init(id: "qr",           title: "Scan WhatsApp QR code"),
        .init(id: "launch",       title: "Start the background service"),
        .init(id: "claude-mcp",   title: "Configure selected agent"),
    ]
}
