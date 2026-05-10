import SwiftUI
import AppKit

struct HistoryView: View {
    @EnvironmentObject var state: AppState
    @State private var rooms: [ConversationRoom] = []
    @State private var selectedRoomJID: String?
    @State private var messages: [ConversationMessage] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var loadingMessagesForJID: String?

    private var selectedRoom: ConversationRoom? {
        guard let selectedRoomJID else { return nil }
        return rooms.first { $0.jid == selectedRoomJID }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 300)

            Divider()

            conversationPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { refreshRooms() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("History")
                        .font(.system(size: 22, weight: .bold))
                    Text("\(rooms.count) conversations")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    refreshRooms()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(18)

            Divider()

            if isLoading && rooms.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, rooms.isEmpty {
                EmptyHistoryState(title: "History unavailable", message: errorMessage, icon: "clock.badge.exclamationmark")
                    .padding(20)
            } else if rooms.isEmpty {
                EmptyHistoryState(title: "No conversations yet", message: "Connect WhatsApp and wait for the initial sync.", icon: "bubble.left.and.bubble.right")
                    .padding(20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rooms) { room in
                            Button {
                                select(room)
                            } label: {
                                ConversationRoomRow(room: room, isSelected: room.jid == selectedRoomJID)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var conversationPane: some View {
        if let selectedRoom {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedRoom.name)
                            .font(.system(size: 20, weight: .bold))
                            .lineLimit(1)
                        Text("\(selectedRoom.messageCount) saved messages")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        export(room: selectedRoom)
                    } label: {
                        Label("Export conversation", systemImage: "square.and.arrow.down")
                    }
                    .disabled(messages.isEmpty)
                }
                .padding(18)

                Divider()

                if loadingMessagesForJID == selectedRoom.jid {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if messages.isEmpty {
                    EmptyHistoryState(title: "No messages in this conversation", message: "History can take a few minutes to appear after connecting.", icon: "message")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { message in
                                ConversationMessageBubble(message: message)
                            }
                        }
                        .padding(18)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
            }
        } else {
            EmptyHistoryState(title: "Select a conversation", message: "Choose a room on the left to view messages and export the history.", icon: "text.bubble")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func refreshRooms() {
        isLoading = true
        errorMessage = nil
        let databaseURL = state.bridge.messagesDB
        Task {
            do {
                let loadedRooms = try await Task.detached(priority: .userInitiated) {
                    try HistoryStore.loadRooms(from: databaseURL)
                }.value
                await MainActor.run {
                    rooms = loadedRooms
                    if let current = selectedRoomJID,
                       loadedRooms.contains(where: { $0.jid == current }) {
                        if let room = selectedRoom {
                            loadMessages(for: room)
                        } else {
                            isLoading = false
                        }
                    } else if let firstRoom = loadedRooms.first {
                        select(firstRoom)
                    } else {
                        selectedRoomJID = nil
                        messages = []
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    rooms = []
                    messages = []
                    selectedRoomJID = nil
                    isLoading = false
                    loadingMessagesForJID = nil
                }
            }
        }
    }

    private func select(_ room: ConversationRoom) {
        selectedRoomJID = room.jid
        loadMessages(for: room)
    }

    private func loadMessages(for room: ConversationRoom) {
        let requestedJID = room.jid
        loadingMessagesForJID = requestedJID
        errorMessage = nil
        let databaseURL = state.bridge.messagesDB
        Task {
            do {
                let loadedMessages = try await Task.detached(priority: .userInitiated) {
                    try HistoryStore.loadMessages(from: databaseURL, chatJID: requestedJID)
                }.value
                await MainActor.run {
                    guard selectedRoomJID == requestedJID else { return }
                    messages = loadedMessages
                    isLoading = false
                    loadingMessagesForJID = nil
                }
            } catch {
                await MainActor.run {
                    guard selectedRoomJID == requestedJID else { return }
                    messages = []
                    errorMessage = error.localizedDescription
                    isLoading = false
                    loadingMessagesForJID = nil
                }
            }
        }
    }

    private func export(room: ConversationRoom) {
        let text = HistoryStore.exportText(room: room, messages: messages)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = safeFilename(for: room.name) + ".txt"
        panel.title = "Export conversation"
        panel.message = "Choose where to save this conversation history."

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                errorMessage = "Could not export the conversation."
            }
        }
    }

    private func safeFilename(for name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "whatsapp-conversation" : cleaned
    }
}

private struct ConversationRoomRow: View {
    let room: ConversationRoom
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(room.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(room.messageCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(room.lastMessage.isEmpty ? "No preview" : room.lastMessage)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

private struct ConversationMessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            if message.isFromMe == 1 { Spacer(minLength: 80) }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(message.author)
                        .font(.system(size: 11.5, weight: .semibold))
                    Spacer()
                    Text(message.timestamp)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Text(message.displayText)
                    .font(.system(size: 13.5))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(message.isFromMe == 1 ? Color.accentColor.opacity(0.11) : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if message.isFromMe == 0 { Spacer(minLength: 80) }
        }
    }
}

private struct EmptyHistoryState: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 17, weight: .bold))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 320)
        }
    }
}
