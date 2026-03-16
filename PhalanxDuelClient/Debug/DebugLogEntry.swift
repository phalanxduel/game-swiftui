import Foundation

public struct DebugLogEntry: Identifiable, Equatable, Sendable {
    public enum Category: String, Equatable, Sendable {
        case rest
        case websocket
        case session
        case serverMessage
        case event
        case error
    }

    public let id: UUID
    public let timestamp: Date
    public let category: Category
    public let title: String
    public let detail: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: Category,
        title: String,
        detail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.title = title
        self.detail = detail
    }
}
