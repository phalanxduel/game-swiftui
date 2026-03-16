import SwiftUI

public struct GameTableView: View {
    public let gameState: GameState
    public let localPlayerIndex: Int?
    public let sessionRole: SessionStore.SessionRole?

    public init(gameState: GameState, localPlayerIndex: Int?, sessionRole: SessionStore.SessionRole?) {
        self.gameState = gameState
        self.localPlayerIndex = localPlayerIndex
        self.sessionRole = sessionRole
    }

    public var body: some View {
        VStack(spacing: 16) {
            ForEach(displayOrder, id: \.self) { playerIndex in
                if let playerState = gameState.players[safe: playerIndex] {
                    PlayerFieldView(
                        title: sectionTitle(for: playerIndex),
                        playerState: playerState,
                        rows: gameState.rows,
                        columns: gameState.columns,
                        isActivePlayer: gameState.activePlayerIndex == playerIndex,
                        revealHand: shouldRevealHand(for: playerIndex)
                    )
                }
            }
        }
    }

    private var displayOrder: [Int] {
        guard let localPlayerIndex else {
            return Array(gameState.players.indices)
        }

        let opponentIndex = localPlayerIndex == 0 ? 1 : 0
        return [opponentIndex, localPlayerIndex]
    }

    private func sectionTitle(for playerIndex: Int) -> String {
        if localPlayerIndex == playerIndex {
            return "You"
        }

        if sessionRole == .spectator {
            return "Player \(playerIndex + 1)"
        }

        return "Opponent"
    }

    private func shouldRevealHand(for playerIndex: Int) -> Bool {
        guard sessionRole == .player else {
            return false
        }

        return localPlayerIndex == playerIndex
    }
}

private struct PlayerFieldView: View {
    let title: String
    let playerState: PlayerState
    let rows: Int
    let columns: Int
    let isActivePlayer: Bool
    let revealHand: Bool

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: max(columns, 1))
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(title): \(playerState.player.name)")
                            .font(.headline)
                        Spacer()
                        if isActivePlayer {
                            Text("Active")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text("Lifepoints \(playerState.lifepoints) | drawpile \(playerState.visibleDrawpileCount) | discardPile \(playerState.discardPile.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Battlefield")
                        .font(.subheadline.weight(.semibold))

                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        ForEach(0..<(rows * columns), id: \.self) { index in
                            BattlefieldSlotView(slot: playerState.battlefield[safe: index] ?? nil)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hand")
                        .font(.subheadline.weight(.semibold))

                    if revealHand {
                        if playerState.hand.isEmpty {
                            Text("No visible cards in hand.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(playerState.hand) { card in
                                        VisibleHandCardView(card: card)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } else {
                        Text("Hidden hand: \(playerState.visibleHandCount) card(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Text(title)
        }
    }
}

private struct BattlefieldSlotView: View {
    let slot: BattlefieldCard?

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(slot == nil ? Color.gray.opacity(0.08) : Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(slotBorderColor, lineWidth: 1.5)
            }
            .frame(minHeight: 96)
            .overlay(alignment: .center) {
                if let slot {
                    VStack(spacing: 4) {
                        Text(slot.faceDown ? "Face Down" : slot.card.shortLabel)
                            .font(.headline)
                            .foregroundStyle(slot.card.suit.isRed ? Color.red : Color.primary)

                        Text("HP \(slot.currentHp)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("r\(slot.position.row) c\(slot.position.col)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(6)
                } else {
                    Text("Empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }

    private var slotBorderColor: Color {
        guard let slot else {
            return Color.gray.opacity(0.35)
        }

        return slot.card.suit.isRed ? .red : .primary
    }
}

private struct VisibleHandCardView: View {
    let card: Card

    var body: some View {
        VStack(spacing: 4) {
            Text(card.face)
                .font(.headline)
            Text(card.suit.symbol)
                .foregroundStyle(card.suit.isRed ? Color.red : Color.primary)
            Text(card.type.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 64, height: 92)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.gray.opacity(0.35), lineWidth: 1)
        }
    }
}
