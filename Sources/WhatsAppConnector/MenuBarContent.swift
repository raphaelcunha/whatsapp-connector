import SwiftUI
import AppKit

struct MenuBarContent: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            statusHeader
            Divider()

            if state.installStatus == .notInstalled {
                Button("Install WhatsApp Connector...") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "installer")
                }
            } else {
                Button("Scan QR Code...") {
                    NSApp.activate(ignoringOtherApps: true)
                    state.openOnboarding(page: 1)
                }

                Divider()

                if state.runStatus == .running {
                    Button("Stop") { state.bridge.stop(); state.refresh() }
                    Button("Restart") { state.bridge.restart(); state.refresh() }
                } else {
                    Button("Start") { state.bridge.start(); state.refresh() }
                }

                Divider()
                Button("History...") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "history")
                }
                Button("Settings...") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
            }

            Divider()
            Button("About WhatsApp Connector") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }.keyboardShortcut("q")
        }
    }

    @ViewBuilder
    private var statusHeader: some View {
        switch (state.installStatus, state.runStatus) {
        case (.notInstalled, _):
            Text("Not installed")
        case (_, .running):
            Text("● Running")
        case (_, .crashed):
            Text("✗ Service error")
        case (_, .stopped):
            Text("○ Stopped")
        case (_, .loading):
            Text("↻ Starting...")
        }
    }
}
