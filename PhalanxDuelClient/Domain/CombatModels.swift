import Foundation

public nonisolated enum CombatBonusType: String, Codable, Equatable, Sendable {
    case aceInvulnerable
    case aceVsAce
    case diamondDoubleDefense
    case diamondDeathShield
    case clubDoubleOverflow
    case spadeDoubleLp
    case heartDeathShield
    case faceCardIneligible
}

public nonisolated enum CombatStepTarget: String, Codable, Equatable, Sendable {
    case frontCard
    case backCard
    case playerLp
}

public nonisolated struct CombatLogStep: Codable, Equatable, Sendable {
    public let target: CombatStepTarget
    public let card: Card?
    public let damage: Int
    public let destroyed: Bool?
    public let bonuses: [CombatBonusType]?
}

public nonisolated struct CombatLogEntry: Codable, Equatable, Sendable {
    public let turnNumber: Int
    public let attackerPlayerIndex: Int
    public let attackerCard: Card
    public let targetColumn: Int
    public let baseDamage: Int
    public let totalLpDamage: Int
    public let steps: [CombatLogStep]
    public let comboCount: Int?
}

/// Mirrors the server's discriminated `TransactionDetailSchema` (shared/src/schema.ts) as a
/// flattened all-optional struct, matching the existing `Action` decoding convention.
public nonisolated struct TransactionDetail: Codable, Equatable, Sendable {
    public let type: ActionType
    public let gridIndex: Int?
    public let combat: CombatLogEntry?
    public let reinforcementTriggered: Bool?
    public let victoryTriggered: Bool?
    public let column: Int?
    public let cardsDrawn: Int?
    public let reinforcementComplete: Bool?
    public let winnerIndex: Int?
}
