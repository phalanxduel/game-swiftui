import Foundation

public nonisolated enum Suit: String, Codable, Equatable, Sendable {
    case spades
    case hearts
    case diamonds
    case clubs

    public var symbol: String {
        switch self {
        case .spades: "♠"
        case .hearts: "♥"
        case .diamonds: "♦"
        case .clubs: "♣"
        }
    }

    public var isRed: Bool {
        self == .hearts || self == .diamonds
    }
}

public nonisolated enum CardType: String, Codable, Equatable, Sendable {
    case number
    case ace
    case jack
    case queen
    case king
    case joker
}

public nonisolated enum TurnPhase: String, Codable, Equatable, Sendable {
    case StartTurn
    case DeploymentPhase
    case AttackPhase
    case AttackResolution
    case CleanupPhase
    case ReinforcementPhase
    case DrawPhase
    case EndTurn
}

public nonisolated enum GamePhase: Codable, Equatable, Sendable {
    case turnPhase(TurnPhase)
    case gameOver
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if value == "gameOver" {
            self = .gameOver
        } else if let phase = TurnPhase(rawValue: value) {
            self = .turnPhase(phase)
        } else {
            self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case let .turnPhase(phase):
            phase.rawValue
        case .gameOver:
            "gameOver"
        case let .unknown(value):
            value
        }
    }

    public var displayName: String {
        switch self {
        case let .turnPhase(phase):
            phase.rawValue
        case .gameOver:
            "gameOver"
        case let .unknown(value):
            value
        }
    }
}

public nonisolated enum VictoryType: String, Codable, Equatable, Sendable {
    case lpDepletion
    case cardDepletion
    case forfeit
    case passLimit
}

public nonisolated enum EventType: String, Codable, Equatable, Sendable {
    case span_started
    case span_ended
    case functional_update
    case system_error
}

public nonisolated enum EventStatus: String, Codable, Equatable, Sendable {
    case ok
    case unrecoverable_error
}

public nonisolated enum DamageMode: String, Codable, Equatable, Sendable {
    case classic
    case cumulative
}

public nonisolated enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(Double(value))
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSONValue payload"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .boolean(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public var displayString: String {
        switch self {
        case let .string(value):
            value
        case let .number(value):
            if value.rounded() == value {
                String(Int(value))
            } else {
                String(value)
            }
        case let .boolean(value):
            value ? "true" : "false"
        case let .object(value):
            if let data = try? JSONSerialization.data(
                withJSONObject: value.mapValues(\.jsonObject),
                options: [.sortedKeys]
            ),
                let string = String(data: data, encoding: .utf8) {
                string
            } else {
                "{…}"
            }
        case let .array(value):
            if let data = try? JSONSerialization.data(withJSONObject: value.map(\.jsonObject)),
               let string = String(data: data, encoding: .utf8) {
                string
            } else {
                "[…]"
            }
        case .null:
            "null"
        }
    }

    fileprivate var jsonObject: Any {
        switch self {
        case let .string(value):
            value
        case let .number(value):
            value
        case let .boolean(value):
            value
        case let .object(value):
            value.mapValues(\.jsonObject)
        case let .array(value):
            value.map(\.jsonObject)
        case .null:
            NSNull()
        }
    }
}

public nonisolated struct Card: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let suit: Suit
    public let face: String
    public let value: Int
    public let type: CardType

    public var shortLabel: String {
        "\(face)\(suit.symbol)"
    }
}

public nonisolated struct PartialCard: Codable, Equatable, Sendable {
    public let suit: Suit
    public let face: String
    public let value: Int
    public let type: CardType

    public var shortLabel: String {
        "\(face)\(suit.symbol)"
    }
}

public nonisolated struct GridPosition: Codable, Equatable, Sendable {
    public let row: Int
    public let col: Int
}

public nonisolated struct BattlefieldCard: Codable, Equatable, Sendable {
    public let card: Card
    public let position: GridPosition
    public let currentHp: Int
    public let faceDown: Bool
}

public nonisolated struct PhalanxEvent: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let parentId: String?
    public let type: EventType
    public let name: String
    public let timestamp: Date
    public let payload: [String: JSONValue]
    public let status: EventStatus

    public var payloadSummary: String {
        payload
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value.displayString)" }
            .joined(separator: ", ")
    }
}

public extension Collection {
    nonisolated subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public nonisolated struct UserFacingError: Codable, Equatable, Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public static func from(_ error: Error) -> UserFacingError {
        UserFacingError(title: "Error", message: error.localizedDescription)
    }
}

public struct NoData: Codable, Equatable, Sendable {
    public init() {}
}

public nonisolated enum LoadState<T: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(UserFacingError)

    public var value: T? {
        if case let .loaded(val) = self {
            return val
        }
        return nil
    }

    public var error: UserFacingError? {
        if case let .failed(err) = self {
            return err
        }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}
