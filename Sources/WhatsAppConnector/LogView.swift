import SwiftUI

/// A simple tail -f -ish view of the bridge log files.
struct LogView: View {
    @EnvironmentObject var state: AppState
    @State private var content: String = ""
    @State private var task: Task<Void, Never>?
    @State private var showStderr: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker("", selection: $showStderr) {
                    Text("stdout").tag(false)
                    Text("stderr").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                Spacer()
                Button {
                    state.bridge.openLogs()
                } label: {
                    Label("Open in Console", systemImage: "macwindow")
                }
                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding(10)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(content.isEmpty ? "(no log yet)" : content)
                        .font(.system(size: 11.5, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(12)
                        .id("__top")
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: content) { _, _ in
                    proxy.scrollTo("__top", anchor: .bottom)
                }
            }
        }
        .onAppear { startPolling() }
        .onDisappear { task?.cancel() }
        .onChange(of: showStderr) { _, _ in refresh() }
    }

    private func currentURL() -> URL {
        showStderr ? state.bridge.errFile : state.bridge.logFile
    }

    private func refresh() {
        let url = currentURL()
        if let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            // Keep the last ~64 KB to avoid blowing up the view
            let max = 65536
            if text.count > max {
                content = String(text.suffix(max))
            } else {
                content = text
            }
        } else {
            content = "(log file not found yet — \(url.path))"
        }
    }

    private func startPolling() {
        task?.cancel()
        refresh()
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { refresh() }
            }
        }
    }
}
