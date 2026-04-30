import Foundation

public nonisolated enum ActionType: String, Codable, Equatable, Sendable {
    case deploy
    case attack
    case pass
    case reinforce
    case forfeit
    case systemInit = "system:init"
}

public nonisolated struct Action: Codable, Equatable, Sendable {
    public let type: ActionType
    public let playerIndex: Int?
    public let timestamp: Date
    public let column: Int?
    public let cardId: String?
    public let attackingColumn: Int?
    public let defendingColumn: Int?

    public init(
        type: ActionType,
        playerIndex: Int? = nil,
        timestamp: Date = Date(),
        column: Int? = nil,
        cardId: String? = nil,
        attackingColumn: Int? = nil,
        defendingColumn: Int? = nil
    ) {
        self.type = type
        self.playerIndex = playerIndex
        self.timestamp = timestamp
        self.column = column
        self.cardId = cardId
        self.attackingColumn = attackingColumn
        self.defendingColumn = defendingColumn
    }

    public static func pass(playerIndex: Int, timestamp: Date = Date()) -> Action {
        Action(type: .pass, playerIndex: playerIndex, timestamp: timestamp)
    }
}

public nonisolated enum ClientMessage: Encodable, Sendable {
    case createMatch(
        playerName: String,
        gameOptions: GameOptions? = nil,
        rngSeed: Int? = nil,
        opponent: String? = nil,
        matchParams: CreateMatchParamsPartial? = nil
    )
    case joinMatch(matchId: String, playerName: String)
    case watchMatch(matchId: String)
    case action(matchId: String, action: Action)
    case authenticate(token: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case playerName
        case gameOptions
        case rngSeed
        case opponent
        case matchParams
        case matchId
        case action
        case token
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .createMatch(playerName, gameOptions, rngSeed, opponent, matchParams):
            try container.encode("createMatch", forKey: .type)
            try container.encode(playerName, forKey: .playerName)
            try container.encodeIfPresent(gameOptions, forKey: .gameOptions)
            try container.encodeIfPresent(rngSeed, forKey: .rngSeed)
            try container.encodeIfPresent(opponent, forKey: .opponent)
            try container.encodeIfPresent(matchParams, forKey: .matchParams)
        case let .joinMatch(matchId, playerName):
            try container.encode("joinMatch", forKey: .type)
            try container.encode(matchId, forKey: .matchId)
            try container.encode(playerName, forKey: .playerName)
        case let .watchMatch(matchId):
            try container.encode("watchMatch", forKey: .type)
            try container.encode(matchId, forKey: .matchId)
        case let .action(matchId, action):
            try container.encode("action", forKey: .type)
            try container.encode(matchId, forKey: .matchId)

            // Ensure action.type is used as the discriminant for the action object
            try container.encode(action, forKey: .action)
        case let .authenticate(token):
            try container.encode("authenticate", forKey: .type)
            try container.encode(token, forKey: .token)
        }
    }
}

public nonisolated struct AuthenticatedUser: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let gamertag: String?
    public let suffix: Int?
    public let elo: Int
}

public nonisolated enum ServerMessage: Decodable, Sendable {
    case matchCreated(matchId: String, playerId: String, playerIndex: Int)
    case gameState(matchId: String, result: PhalanxTurnResult, spectatorCount: Int?)
    case actionError(error: String, code: String)
    case matchError(error: String, code: String)
    case matchJoined(matchId: String, playerId: String, playerIndex: Int)
    case spectatorJoined(matchId: String, spectatorId: String)
    case opponentDisconnected(matchId: String)
    case opponentReconnected(matchId: String)
    case authenticated(user: AuthenticatedUser)
    case authError(error: String)
    case ping
    case unknown(type: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case matchId
        case playerId
        case playerIndex
        case result
        case spectatorCount
        case error
        case code
        case spectatorId
        case user
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "matchCreated":
            self = try .matchCreated(
                matchId: container.decode(String.self, forKey: .matchId),
                playerId: container.decode(String.self, forKey: .playerId),
                playerIndex: container.decode(Int.self, forKey: .playerIndex)
            )
        case "gameState":
            self = try .gameState(
                matchId: container.decode(String.self, forKey: .matchId),
                result: container.decode(PhalanxTurnResult.self, forKey: .result),
                spectatorCount: container.decodeIfPresent(Int.self, forKey: .spectatorCount)
            )
        case "actionError":
            self = try .actionError(
                error: container.decode(String.self, forKey: .error),
                code: container.decode(String.self, forKey: .code)
            )
        case "matchError":
            self = try .matchError(
                error: container.decode(String.self, forKey: .error),
                code: container.decode(String.self, forKey: .code)
            )
        case "matchJoined":
            self = try .matchJoined(
                matchId: container.decode(String.self, forKey: .matchId),
                playerId: container.decode(String.self, forKey: .playerId),
                playerIndex: container.decode(Int.self, forKey: .playerIndex)
            )
        case "spectatorJoined":
            self = try .spectatorJoined(
                matchId: container.decode(String.self, forKey: .matchId),
                spectatorId: container.decode(String.self, forKey: .spectatorId)
            )
        case "opponentDisconnected":
            self = try .opponentDisconnected(matchId: container.decode(String.self, forKey: .matchId))
        case "opponentReconnected":
            self = try .opponentReconnected(matchId: container.decode(String.self, forKey: .matchId))
        case "authenticated":
            self = try .authenticated(user: container.decode(AuthenticatedUser.self, forKey: .user))
        case "auth_error", "authError":
            self = try .authError(error: container.decode(String.self, forKey: .error))
        case "ping":
            self = .ping
        default:
            self = .unknown(type: type)
        }
    }

    public var messageType: String {
        switch self {
        case .matchCreated:
            "matchCreated"
        case .gameState:
            "gameState"
        case .actionError:
            "actionError"
        case .matchError:
            "matchError"
        case .matchJoined:
            "matchJoined"
        case .spectatorJoined:
            "spectatorJoined"
        case .opponentDisconnected:
            "opponentDisconnected"
        case .opponentReconnected:
            "opponentReconnected"
        case .authenticated:
            "authenticated"
        case .authError:
            "authError"
        case .ping:
            "ping"
        case let .unknown(type):
            type
        }
    }

    public var debugSummary: String {
        switch self {
        case let .matchCreated(matchId, _, playerIndex):
            "matchId=\(matchId), playerIndex=\(playerIndex)"
        case let .matchJoined(matchId, _, playerIndex):
            "matchId=\(matchId), playerIndex=\(playerIndex)"
        case let .spectatorJoined(matchId, spectatorId):
            "matchId=\(matchId), spectatorId=\(spectatorId)"
        case let .gameState(matchId, result, spectatorCount):
            "matchId=\(matchId), phase=\(result.postState.phase.displayName), turn=\(result.postState.turnNumber), spectatorCount=\(spectatorCount ?? 0)"
        case let .actionError(error, code),
             let .matchError(error, code):
            "[\(code)] \(error)"
        case let .opponentDisconnected(matchId):
            "matchId=\(matchId)"
        case let .opponentReconnected(matchId):
            "matchId=\(matchId)"
        case let .authenticated(user):
            "user=\(user.name), elo=\(user.elo)"
        case let .authError(error):
            error
        case .ping:
            "keep-alive"
        case let .unknown(type):
            "type=\(type)"
        }
    }
}
