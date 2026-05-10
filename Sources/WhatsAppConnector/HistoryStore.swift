import Foundation

struct ConversationRoom: Identifiable, Decodable, Hashable {
    let jid: String
    let name: String
    let lastMessageTime: String
    let messageCount: Int
    let lastMessage: String

    var id: String { jid }

    enum CodingKeys: String, CodingKey {
        case jid
        case name
        case lastMessageTime = "last_message_time"
        case messageCount = "message_count"
        case lastMessage = "last_message"
    }
}

struct ConversationMessage: Identifiable, Decodable, Hashable {
    let id: String
    let sender: String
    let content: String
    let timestamp: String
    let isFromMe: Int
    let mediaType: String
    let filename: String

    var author: String {
        isFromMe == 1 ? "You" : displaySender
    }

    var displaySender: String {
        sender.isEmpty ? "Contato" : sender
    }

    var displayText: String {
        if !content.isEmpty { return content }
        if !mediaType.isEmpty {
            return filename.isEmpty ? "[\(mediaType)]" : "[\(mediaType): \(filename)]"
        }
        return "[message without text]"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sender
        case content
        case timestamp
        case isFromMe = "is_from_me"
        case mediaType = "media_type"
        case filename
    }
}

enum HistoryStore {
    enum HistoryError: LocalizedError {
        case databaseMissing
        case sqliteUnavailable
        case queryFailed(String)
        case decodeFailed

        var errorDescription: String? {
            switch self {
            case .databaseMissing:
                return "No history found yet. Connect WhatsApp and wait for the initial sync."
            case .sqliteUnavailable:
                return "Could not open the macOS history reader."
            case .queryFailed(let message):
                return message.isEmpty ? "Could not load history." : message
            case .decodeFailed:
                return "History was found, but it could not be read."
            }
        }
    }

    static func loadRooms(from databaseURL: URL) throws -> [ConversationRoom] {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw HistoryError.databaseMissing
        }

        let query = """
        SELECT
            c.jid AS jid,
            COALESCE(NULLIF(c.name, ''), c.jid) AS name,
            COALESCE(CAST(c.last_message_time AS TEXT), '') AS last_message_time,
            COUNT(m.id) AS message_count,
            COALESCE((
                SELECT CASE
                    WHEN NULLIF(mm.content, '') IS NOT NULL THEN mm.content
                    WHEN NULLIF(mm.media_type, '') IS NOT NULL THEN '[' || mm.media_type || ']'
                    ELSE ''
                END
                FROM messages mm
                WHERE mm.chat_jid = c.jid
                ORDER BY mm.timestamp DESC
                LIMIT 1
            ), '') AS last_message
        FROM chats c
        LEFT JOIN messages m ON m.chat_jid = c.jid
        GROUP BY c.jid, c.name, c.last_message_time
        ORDER BY c.last_message_time DESC;
        """

        let data = try runJSONQuery(databaseURL: databaseURL, query: query)
        return try JSONDecoder().decode([ConversationRoom].self, from: data)
    }

    static func loadMessages(from databaseURL: URL, chatJID: String, limit: Int = 500) throws -> [ConversationMessage] {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw HistoryError.databaseMissing
        }

        let jid = sqlString(chatJID)
        let query = """
        SELECT
            id,
            COALESCE(sender, '') AS sender,
            COALESCE(content, '') AS content,
            COALESCE(CAST(timestamp AS TEXT), '') AS timestamp,
            CASE WHEN is_from_me THEN 1 ELSE 0 END AS is_from_me,
            COALESCE(media_type, '') AS media_type,
            COALESCE(filename, '') AS filename
        FROM messages
        WHERE chat_jid = \(jid)
        ORDER BY timestamp DESC
        LIMIT \(max(1, limit));
        """

        let data = try runJSONQuery(databaseURL: databaseURL, query: query)
        let messages = try JSONDecoder().decode([ConversationMessage].self, from: data)
        return messages.reversed()
    }

    static func exportText(room: ConversationRoom, messages: [ConversationMessage]) -> String {
        var lines: [String] = [
            "WhatsApp Connector",
            "Conversation: \(room.name)",
            "Messages: \(messages.count)",
            ""
        ]

        for message in messages {
            lines.append("[\(message.timestamp)] \(message.author): \(message.displayText)")
        }

        return lines.joined(separator: "\n")
    }

    private static func runJSONQuery(databaseURL: URL, query: String) throws -> Data {
        let sqlitePath = "/usr/bin/sqlite3"
        guard FileManager.default.fileExists(atPath: sqlitePath) else {
            throw HistoryError.sqliteUnavailable
        }

        let result = ShellRunner.runSync(sqlitePath, ["-readonly", "-json", databaseURL.path, query])
        guard result.exitCode == 0 else {
            throw HistoryError.queryFailed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let data = result.stdout.data(using: .utf8) else {
            throw HistoryError.decodeFailed
        }
        return data
    }

    private static func sqlString(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }
}
