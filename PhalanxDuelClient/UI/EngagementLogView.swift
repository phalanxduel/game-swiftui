import SwiftUI

/// Ports client/src/combat-explanation.ts's arithmetic formatter against
/// CalculationProvenance decoded from CombatLogEntry.calculationProvenance.
/// Unlike the browser, this does not re-run verifyCalculationProvenance():
/// the SwiftUI client only ever displays server-authoritative GameState, so
/// there is no untrusted input to defend against here.
public nonisolated enum CombatExplanationMode: String, CaseIterable, Sendable {
    case tactical
    case cinematic
    case analyst

    var label: String {
        switch self {
        case .tactical: return "TACTICAL"
        case .cinematic: return "CINEMATIC"
        case .analyst: return "ANALYST"
        }
    }
}

public nonisolated struct CombatEquationLine: Identifiable, Equatable, Sendable {
    public let sequence: Int
    public let ruleId: String
    public let expression: String
    public var id: Int { sequence }
}

public nonisolated struct CombatExplanation: Equatable, Sendable {
    public let lines: [CombatEquationLine]
    public let tacticalSequences: [Int]
    public let cinematicSequence: Int
}

public enum CombatExplanationFormatter {
    public static func build(_ provenance: CalculationProvenance?) -> CombatExplanation? {
        guard let provenance, let firstStep = provenance.steps.first, let lastStep = provenance.steps.last else {
            return nil
        }

        let lines = provenance.steps.map(formatStep)
        let modifierSequences = provenance.steps.filter(isTacticalModifier).map(\.sequence)

        var tacticalSequences: [Int] = []
        for sequence in [firstStep.sequence] + modifierSequences.suffix(1) + [lastStep.sequence]
        where !tacticalSequences.contains(sequence) {
            tacticalSequences.append(sequence)
        }

        return CombatExplanation(
            lines: lines,
            tacticalSequences: tacticalSequences,
            cinematicSequence: modifierSequences.last ?? lastStep.sequence
        )
    }

    public static func lines(for explanation: CombatExplanation, mode: CombatExplanationMode) -> [CombatEquationLine] {
        switch mode {
        case .analyst: return explanation.lines
        case .cinematic: return explanation.lines.filter { $0.sequence == explanation.cinematicSequence }
        case .tactical: return explanation.lines.filter { explanation.tacticalSequences.contains($0.sequence) }
        }
    }

    private static func formatStep(_ step: CalculationStep) -> CombatEquationLine {
        CombatEquationLine(
            sequence: step.sequence,
            ruleId: step.ruleId,
            expression: "\(humanize(step.result.name)) = \(symbolicOperands(step)) = \(step.result.value)"
        )
    }

    private static func isTacticalModifier(_ step: CalculationStep) -> Bool {
        step.operator == .multiply
            || step.quantity == .shieldAbsorbed
            || step.inputs.contains { input in
                input.name.range(of: "multiplier|shield", options: [.regularExpression, .caseInsensitive]) != nil
            }
    }

    private static func humanize(_ name: String) -> String {
        let leaf = name.split(separator: ".").last.map(String.init) ?? name
        var spaced = ""
        for (index, character) in leaf.enumerated() {
            if index > 0, character.isUppercase {
                spaced.append(" ")
            }
            spaced.append(character)
        }
        guard let first = spaced.first else { return spaced }
        return first.uppercased() + spaced.dropFirst()
    }

    private static func symbolicOperands(_ step: CalculationStep) -> String {
        let values = step.inputs.map { String($0.value) }
        switch step.operator {
        case .assign: return values[safe: 0] ?? "0"
        case .min: return "min(\(values.joined(separator: ", ")))"
        case .subtract: return "\(values[safe: 0] ?? "") \u{2212} \(values[safe: 1] ?? "")"
        case .multiply: return "\(values[safe: 0] ?? "") \u{00D7} \(values[safe: 1] ?? "")"
        case .clamp: return "clamp(\(values.joined(separator: ", ")))"
        }
    }
}

/// Ports client/src/components/EngagementLog.tsx (non-spectator branch): the
/// last 20 attack entries, most recent first, each with an expandable "WHY"
/// arithmetic breakdown ported from client/src/components/CombatMath.tsx.
/// The spectator PLAY_BY_PLAY variant (client/src/game.tsx's describePlayByPlay)
/// is not ported — the SwiftUI client has no spectator UI yet.
public struct EngagementLogView: View {
    private static let maxEntries = 20

    public let state: GameState
    @State private var isOpen = true

    public init(state: GameState) {
        self.state = state
    }

    public var body: some View {
        let entries = attackEntries

        VStack(alignment: .leading, spacing: 0) {
            Button {
                isOpen.toggle()
            } label: {
                HStack {
                    Text("ENGAGEMENT_LOG")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                    Spacer()
                    Image(systemName: isOpen ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                }
                .foregroundStyle(Color.gameTextMuted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("game.engagement-log-toggle")

            if isOpen {
                if entries.isEmpty {
                    Text("No combat data recorded...")
                        .font(.system(size: 11, design: .monospaced))
                        .italic()
                        .foregroundStyle(Color.gameTextDim)
                        .padding(.top, AppSpacing.small)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AppSpacing.small) {
                            ForEach(entries, id: \.turnNumber) { entry in
                                EngagementLogEntryView(entry: entry)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                    .accessibilityIdentifier("game.engagement-log")
                }
            }
        }
        .padding(AppSpacing.small)
        .background(Color.gameSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.gameBorder, lineWidth: 1)
        }
    }

    private var attackEntries: [CombatLogEntry] {
        let combats = (state.transactionLog ?? []).compactMap { entry -> CombatLogEntry? in
            guard entry.details.type == .attack else { return nil }
            return entry.details.combat
        }
        return Array(combats.suffix(Self.maxEntries).reversed())
    }
}

private struct EngagementLogEntryView: View {
    let entry: CombatLogEntry
    @State private var mode: CombatExplanationMode = .tactical

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            (
                Text("T\(entry.turnNumber)")
                    .foregroundStyle(Color.goldAccent)
                    + Text(": \(entry.attackerCard.shortLabel) ATK COL \(entry.targetColumn + 1)")
                    .foregroundStyle(Color.gameTextPrimary)
            )
            .font(.system(size: 11, design: .monospaced))

            if let explanation = CombatExplanationFormatter.build(entry.calculationProvenance) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("WHY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.gameTextDim)
                        Spacer()
                        ForEach(CombatExplanationMode.allCases, id: \.self) { candidate in
                            Button(candidate.label) { mode = candidate }
                                .buttonStyle(.plain)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(candidate == mode ? Color.goldBright : Color.gameTextDim)
                        }
                    }
                    ForEach(CombatExplanationFormatter.lines(for: explanation, mode: mode)) { line in
                        Text(line.expression)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.gameTextMuted)
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.3)
        }
    }
}
