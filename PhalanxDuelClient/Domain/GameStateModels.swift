import Foundation

public nonisolated enum ClassicModeType: String, Codable, Equatable, Sendable {
    case strict
    case hybrid
}

public nonisolated struct BattlefieldConfiguration: Codable, Equatable, Sendable {
    public let rows: Int
    public let columns: Int
}

public nonisolated struct HandConfiguration: Codable, Equatable, Sendable {
    public let maxHandSize: Int
}

public nonisolated struct StartConfiguration: Codable, Equatable, Sendable {
    public let initialDraw: Int
}

public nonisolated struct ClassicModes: Codable, Equatable, Sendable {
    public let classicAces: Bool
    public let classicFaceCards: Bool
    public let damagePersistence: DamageMode
}

public nonisolated struct Initiative: Codable, Equatable, Sendable {
    public let deployFirst: String
    public let attackFirst: String
}

public nonisolated struct PassRules: Codable, Equatable, Sendable {
    public let maxConsecutivePasses: Int
    public let maxTotalPassesPerPlayer: Int
}

public nonisolated struct MatchConfigClassic: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let mode: ClassicModeType
    public let battlefield: BattlefieldConfiguration
    public let hand: HandConfiguration
    public let start: StartConfiguration
    public let modes: ClassicModes
    public let initiative: Initiative
    public let passRules: PassRules
}

public nonisolated struct SpecialStartMode: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let noAttackCountsAsPassUntil: String?
}

public nonisolated struct CreateMatchParamsPartial: Codable, Equatable, Sendable {
    public let rows: Int?
    public let columns: Int?
    public let maxHandSize: Int?
    public let initialDraw: Int?
}

public nonisolated struct MatchParameters: Codable, Equatable, Sendable {
    public let specVersion: String
    public let classic: MatchConfigClassic
    public let rows: Int
    public let columns: Int
    public let maxHandSize: Int
    public let initialDraw: Int
    public let modeClassicAces: Bool
    public let modeClassicFaceCards: Bool
    public let modeDamagePersistence: DamageMode
    public let modeClassicDeployment: Bool
    public let modeSpecialStart: SpecialStartMode
    public let initiative: Initiative
    public let modePassRules: PassRules
}

public nonisolated struct GameOptions: Codable, Equatable, Sendable {
    public let damageMode: DamageMode
    public let startingLifepoints: Int
}

public nonisolated struct Player: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
}

public nonisolated struct PlayerState: Codable, Equatable, Sendable {
    public let player: Player
    public let hand: [Card]
    public let battlefield: [BattlefieldCard?]
    public let drawpile: [PartialCard]
    public let discardPile: [Card]
    public let lifepoints: Int
    public let deckSeed: Int
    public let handCount: Int?
    public let drawpileCount: Int?

    public var visibleHandCount: Int {
        hand.isEmpty ? (handCount ?? 0) : hand.count
    }

    public var visibleDrawpileCount: Int {
        drawpile.isEmpty ? (drawpileCount ?? 0) : drawpile.count
    }
}

public nonisolated struct ReinforcementContext: Codable, Equatable, Sendable {
    public let column: Int
    public let attackerIndex: Int
}

public nonisolated struct PassState: Codable, Equatable, Sendable {
    public let consecutivePasses: [Int]
    public let totalPasses: [Int]
}

public nonisolated struct TransactionLogEntry: Codable, Equatable, Sendable {
    public let sequenceNumber: Int
    public let action: Action
    public let stateHashBefore: String
    public let stateHashAfter: String
    public let timestamp: Date
    public let turnHash: String?
}

public nonisolated struct MatchOutcome: Codable, Equatable, Sendable {
    public let winnerIndex: Int
    public let victoryType: VictoryType
    public let turnNumber: Int
}

public nonisolated struct GameState: Codable, Equatable, Sendable {
    public let matchId: String
    public let specVersion: String
    public let params: MatchParameters
    public let players: [PlayerState]
    public let activePlayerIndex: Int
    public let phase: GamePhase
    public let turnNumber: Int
    public let gameOptions: GameOptions?
    public let reinforcement: ReinforcementContext?
    public let passState: PassState?
    public let transactionLog: [TransactionLogEntry]?
    public let outcome: MatchOutcome?

    public var rows: Int {
        params.rows
    }

    public var columns: Int {
        params.columns
    }

    public var activePlayerName: String {
        players[safe: activePlayerIndex]?.player.name ?? "Player \(activePlayerIndex + 1)"
    }

    public func battlefieldCard(playerIndex: Int, row: Int, column: Int) -> BattlefieldCard? {
        guard let playerState = players[safe: playerIndex] else {
            return nil
        }

        let index = row * columns + column
        return playerState.battlefield[safe: index] ?? nil
    }
}

public nonisolated struct PhalanxTurnResult: Codable, Equatable, Sendable {
    public let matchId: String
    public let playerId: String
    public let preState: GameState
    public let postState: GameState
    public let action: Action
    public let events: [PhalanxEvent]?
    public let turnHash: String?
}

public nonisolated enum BootTaskStatus: String, Codable, Equatable, Sendable {
    case pending
    case loading
    case success
    case failure
}

public nonisolated struct BootTask: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public var status: BootTaskStatus
    public var errorMessage: String?

    public init(id: String, name: String, status: BootTaskStatus = .pending, errorMessage: String? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.errorMessage = errorMessage
    }
}
