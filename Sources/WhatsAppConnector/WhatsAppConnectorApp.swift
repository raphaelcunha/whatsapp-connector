import SwiftUI
import AppKit

@main
struct WhatsAppConnectorApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(state)
                .onReceive(NotificationCenter.default.publisher(for: .openOnboarding)) { _ in
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "onboarding")
                }
        } label: {
            ModernMenuBarIcon()
                .background(
                    FirstLaunchOnboardingPresenter()
                        .environmentObject(state)
                )
        }
        .menuBarExtraStyle(.menu)

        Window("WhatsApp Connector Setup", id: "installer") {
            InstallerView()
                .environmentObject(state)
                .frame(minWidth: 680, minHeight: 540)
        }
        .windowResizability(.contentSize)

        Window("Welcome to WhatsApp Connector", id: "onboarding") {
            OnboardingView()
                .environmentObject(state)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 820, height: 620)

        Window("WhatsApp History", id: "history") {
            HistoryView()
                .environmentObject(state)
                .frame(minWidth: 900, minHeight: 560)
        }

        Window("WhatsApp Connector Settings", id: "settings") {
            SettingsView()
                .environmentObject(state)
                .frame(minWidth: 620, minHeight: 430)
        }
        .windowResizability(.contentSize)

        Window("WhatsApp Connector Logs", id: "logs") {
            LogView()
                .environmentObject(state)
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}

private struct FirstLaunchOnboardingPresenter: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var didCheck = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                guard !didCheck else { return }
                didCheck = true

                try? await Task.sleep(nanoseconds: 700_000_000)
                await MainActor.run {
                    state.refresh()
                    guard state.shouldShowInitialOnboarding() else { return }
                    state.requestedOnboardingPage = 0
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "onboarding")
                }
            }
    }
}
