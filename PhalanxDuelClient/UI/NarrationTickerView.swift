import SwiftUI

public nonisolated struct NarrationLine: Identifiable, Equatable, Sendable {
    public let id: Int
    public let text: String
    public let suit: Suit?
    public let style: NarrationLineStyle
}

public nonisolated enum NarrationLineStyle: Equatable, Sendable {
    case normal
    case destroyed
    case lpDamage
    case bonus
    case combo
    case terminal
}

/// Ports the browser client's narration-bus/narration-producer formatting
/// (client/src/narration-bus.ts, narration-producer.ts) against the data the
/// SwiftUI client already decodes. Combat step narration (destroyed/overflow/
/// lp-damage/bonuses/combo) requires `TransactionLogEntry.details`, added
/// alongside this view. Phase-change and calculation-provenance lines are
/// intentionally not ported yet — they aren't reconstructible from the log
/// without additional server fields.
public enum NarrationFormatter {
    private static let columnLabels = ["1st", "2nd", "3rd", "4th", "5th", "6th"]

    public static func lines(for state: GameState) -> [NarrationLine] {
        var lines: [NarrationLine] = []
        var nextId = 0
        func emit(_ text: String, suit: Suit? = nil, style: NarrationLineStyle = .normal) {
            lines.append(NarrationLine(id: nextId, text: text, suit: suit, style: style))
            nextId += 1
        }

        let columns = state.columns
        for entry in state.transactionLog ?? [] {
            guard entry.action.type != .systemInit else { continue }

            switch entry.details.type {
            case .deploy:
                guard let gridIndex = entry.details.gridIndex,
                      let playerIndex = entry.action.playerIndex else { continue }
                let playerName = state.players[safe: playerIndex]?.player.name ?? "Player"
                let column = gridIndex % max(columns, 1)
                let card = state.players[safe: playerIndex]?.battlefield[safe: gridIndex]?.flatMap { $0 }?.card
                let label = card?.shortLabel ?? "a card"
                let col = columnLabels[safe: column] ?? "\(column + 1)th"
                emit("\(playerName) deploys \(label) (\(col))", suit: card?.suit)

            case .attack:
                guard let combat = entry.details.combat else { continue }
                let defenderIndex = combat.attackerPlayerIndex == 0 ? 1 : 0
                let defenderName = state.players[safe: defenderIndex]?.player.name ?? "Opponent"
                let attackerLabel = combat.attackerCard.shortLabel
                let attackerSuit = combat.attackerCard.suit

                for step in combat.steps {
                    let bonuses = (step.bonuses ?? []).filter { $0 != .faceCardIneligible }
                    if step.damage == 0, bonuses.isEmpty { continue }

                    if step.damage == 0 {
                        for bonus in bonuses {
                            if let message = bonusMessage(bonus, card: step.card?.shortLabel ?? attackerLabel) {
                                emit(message, suit: step.card?.suit ?? attackerSuit, style: .bonus)
                            }
                        }
                        continue
                    }

                    switch step.target {
                    case .frontCard, .backCard:
                        let targetLabel = step.card?.shortLabel ?? "card"
                        if step.target == .backCard {
                            emit("↪ \(targetLabel) (\(step.damage))", suit: step.card?.suit)
                        } else {
                            emit("\(attackerLabel) → \(targetLabel) (\(step.damage))", suit: attackerSuit)
                        }
                        if step.destroyed == true {
                            emit("DESTROYED", suit: step.card?.suit, style: .destroyed)
                        }
                        for bonus in bonuses {
                            if let message = bonusMessage(bonus, card: targetLabel) {
                                emit(message, suit: step.card?.suit, style: .bonus)
                            }
                        }
                    case .playerLp:
                        emit("\(step.damage) dmg → \(defenderName)", suit: attackerSuit, style: .lpDamage)
                        for bonus in bonuses {
                            if let message = bonusMessage(bonus, card: attackerLabel) {
                                emit(message, suit: attackerSuit, style: .bonus)
                            }
                        }
                    }
                }

                if let comboCount = combat.comboCount, comboCount > 1 {
                    emit("\(comboCount)-HIT COMBO!", suit: attackerSuit, style: .combo)
                }

            case .pass, .reinforce, .forfeit, .systemInit:
                continue
            }
        }

        if let outcome = state.outcome {
            emit("── MATCH COMPLETE · TURN \(outcome.turnNumber) ──", style: .terminal)
        }

        return lines
    }

    private static func bonusMessage(_ bonus: CombatBonusType, card: String) -> String? {
        switch bonus {
        case .aceInvulnerable: return "\(card) is invulnerable"
        case .aceVsAce: return "\(card) breaks through invulnerability"
        case .diamondDoubleDefense: return "...absorbed by Diamond Defense"
        case .clubDoubleOverflow: return "...doubled by Club Overflow"
        case .spadeDoubleLp: return "...doubled by Spade direct strike"
        case .heartDeathShield: return "\(card) survives — Heart Shield"
        case .diamondDeathShield: return "\(card) survives — Diamond Shield"
        case .faceCardIneligible: return nil
        }
    }
}

public struct NarrationTickerView: View {
    private static let maxLines = 30

    public let state: GameState
    @State private var isOpen = true

    public init(state: GameState) {
        self.state = state
    }

    public var body: some View {
        let lines = NarrationFormatter.lines(for: state).suffix(Self.maxLines)

        VStack(alignment: .leading, spacing: 0) {
            Button {
                isOpen.toggle()
            } label: {
                HStack {
                    Text("NARRATION")
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
            .accessibilityIdentifier("game.narration-toggle")

            if isOpen {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(lines), id: \.id) { line in
                                Text(line.text)
                                    .font(.system(size: 11, design: .monospaced))
                                    .fontWeight(line.style == .destroyed || line.style == .terminal ? .bold : .regular)
                                    .foregroundStyle(color(for: line))
                                    .id(line.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                    .onChange(of: lines.last?.id) { _, lastId in
                        guard let lastId else { return }
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .accessibilityIdentifier("game.narration-ticker")
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

    private func color(for line: NarrationLine) -> Color {
        switch line.style {
        case .destroyed: return .neonDefense
        case .lpDamage: return .warningStatus
        case .bonus: return .goldAccent
        case .combo: return .goldBright
        case .terminal: return .gameTextPrimary
        case .normal:
            guard let suit = line.suit else { return .gameTextMuted }
            return suit.accentColor
        }
    }
}
