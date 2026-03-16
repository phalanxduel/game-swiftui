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
        case .createMatch(let playerName, let gameOptions, let rngSeed, let opponent, let matchParams):
            try container.encode("createMatch", forKey: .type)
            try container.encode(playerName, forKey: .playerName)
            try container.encodeIfPresent(gameOptions, forKey: .gameOptions)
            try container.encodeIfPresent(rngSeed, forKey: .rngSeed)
            try container.encodeIfPresent(opponent, forKey: .opponent)
            try container.encodeIfPresent(matchParams, forKey: .matchParams)
        case .joinMatch(let matchId, let playerName):
            try container.encode("joinMatch", forKey: .type)
            try container.encode(matchId, forKey: .matchId)
            try container.encode(playerName, forKey: .playerName)
        case .watchMatch(let matchId):
            try container.encode("watchMatch", forKey: .type)
            try container.encode(matchId, forKey: .matchId)
        case .action(let matchId, let action):
            try container.encode("action", forKey: .type)
            try container.encode(matchId, forKey: .matchId)
            try container.encode(action, forKey: .action)
        case .authenticate(let token):
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
            self = .matchCreated(
                matchId: try container.decode(String.self, forKey: .matchId),
                playerId: try container.decode(String.self, forKey: .playerId),
                playerIndex: try container.decode(Int.self, forKey: .playerIndex)
            )
        case "gameState":
            self = .gameState(
                matchId: try container.decode(String.self, forKey: .matchId),
                result: try container.decode(PhalanxTurnResult.self, forKey: .result),
                spectatorCount: try container.decodeIfPresent(Int.self, forKey: .spectatorCount)
            )
        case "actionError":
            self = .actionError(
                error: try container.decode(String.self, forKey: .error),
                code: try container.decode(String.self, forKey: .code)
            )
        case "matchError":
            self = .matchError(
                error: try container.decode(String.self, forKey: .error),
                code: try container.decode(String.self, forKey: .code)
            )
        case "matchJoined":
            self = .matchJoined(
                matchId: try container.decode(String.self, forKey: .matchId),
                playerId: try container.decode(String.self, forKey: .playerId),
                playerIndex: try container.decode(Int.self, forKey: .playerIndex)
            )
        case "spectatorJoined":
            self = .spectatorJoined(
                matchId: try container.decode(String.self, forKey: .matchId),
                spectatorId: try container.decode(String.self, forKey: .spectatorId)
            )
        case "opponentDisconnected":
            self = .opponentDisconnected(matchId: try container.decode(String.self, forKey: .matchId))
        case "opponentReconnected":
            self = .opponentReconnected(matchId: try container.decode(String.self, forKey: .matchId))
        case "authenticated":
            self = .authenticated(user: try container.decode(AuthenticatedUser.self, forKey: .user))
        case "auth_error":
            self = .authError(error: try container.decode(String.self, forKey: .error))
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
            "auth_error"
        case .unknown(let type):
            type
        }
    }

    public var debugSummary: String {
        switch self {
        case .matchCreated(let matchId, _, let playerIndex):
            "matchId=\(matchId), playerIndex=\(playerIndex)"
        case .matchJoined(let matchId, _, let playerIndex):
            "matchId=\(matchId), playerIndex=\(playerIndex)"
        case .spectatorJoined(let matchId, let spectatorId):
            "matchId=\(matchId), spectatorId=\(spectatorId)"
        case .gameState(let matchId, let result, let spectatorCount):
            "matchId=\(matchId), phase=\(result.postState.phase.displayName), turn=\(result.postState.turnNumber), spectatorCount=\(spectatorCount ?? 0)"
        case .actionError(let error, let code),
             .matchError(let error, let code):
            "[\(code)] \(error)"
        case .opponentDisconnected(let matchId):
            "matchId=\(matchId)"
        case .opponentReconnected(let matchId):
            "matchId=\(matchId)"
        case .authenticated(let user):
            "user=\(user.name), elo=\(user.elo)"
        case .authError(let error):
            error
        case .unknown(let type):
            "type=\(type)"
        }
    }
}
