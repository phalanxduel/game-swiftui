import Foundation

/// Ports the fields of shared/src/types.ts's CalculationStep/CalculationProvenance that
/// client/src/combat-explanation.ts actually reads when rendering the ENGAGEMENT_LOG "WHY"
/// equations. Fields the browser formatter never touches (target, visibility, input source)
/// are intentionally not decoded, matching this file's existing flattened-struct convention.
public nonisolated enum CalculationOperator: String, Codable, Equatable, Sendable {
    case assign
    case min
    case subtract
    case multiply
    case clamp
}

public nonisolated enum CalculationQuantity: String, Codable, Equatable, Sendable {
    case baseDamage
    case absorbedDamage
    case candidateHp
    case remainingHp
    case carryover
    case shieldAbsorbed
    case appliedDamage
    case candidateLp
    case remainingLp
}

public nonisolated struct CalculationInput: Codable, Equatable, Sendable {
    public let name: String
    public let value: Int
}

public nonisolated struct CalculationResult: Codable, Equatable, Sendable {
    public let name: String
    public let value: Int
}

public nonisolated struct CalculationStep: Codable, Equatable, Sendable {
    public let sequence: Int
    public let ruleId: String
    public let `operator`: CalculationOperator
    public let inputs: [CalculationInput]
    public let result: CalculationResult
    public let quantity: CalculationQuantity
}

public nonisolated struct CalculationProvenance: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let steps: [CalculationStep]
}
