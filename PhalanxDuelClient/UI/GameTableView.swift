import SwiftUI

public struct GameTableView: View {
    public let gameState: GameState
    public let localPlayerIndex: Int?
    public let sessionRole: SessionStore.SessionRole?
    public let onAction: (Action) -> Void

    @State private var selectedCardId: String?
    @State private var selectedAttackerColumn: Int?

    public init(
        gameState: GameState,
        localPlayerIndex: Int?,
        sessionRole: SessionStore.SessionRole?,
        onAction: @escaping (Action) -> Void
    ) {
        self.gameState = gameState
        self.localPlayerIndex = localPlayerIndex
        self.sessionRole = sessionRole
        self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: AppSpacing.medium) {
            ForEach(displayOrder, id: \.self) { playerIndex in
                if let playerState = gameState.players[safe: playerIndex] {
                    PlayerFieldView(
                        title: sectionTitle(for: playerIndex),
                        playerState: playerState,
                        rows: gameState.rows,
                        columns: gameState.columns,
                        isActivePlayer: gameState.activePlayerIndex == playerIndex,
                        revealHand: shouldRevealHand(for: playerIndex),
                        selectedCardId: selectedCardId,
                        selectedAttackerColumn: selectedAttackerColumn,
                        validDeployColumns: validDeployColumns(for: playerIndex),
                        validAttackColumns: validAttackColumns(for: playerIndex),
                        onCardSelected: { cardId in
                            HapticAndAudioEngine.shared.playCardSelectedHaptic()
                            if selectedCardId == cardId {
                                selectedCardId = nil
                            } else {
                                selectedCardId = cardId
                                selectedAttackerColumn = nil
                            }
                        },
                        onSlotSelected: { row, col in
                            handleSlotSelection(playerIndex: playerIndex, row: row, col: col)
                        }
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

    private func validDeployColumns(for playerIndex: Int) -> Set<Int> {
        guard let localPlayerIndex, playerIndex == localPlayerIndex, selectedCardId != nil else { return [] }
        var valid = Set<Int>()
        for col in 0 ..< gameState.columns {
            if gameState.isValidDeployment(playerIndex: localPlayerIndex, column: col) {
                valid.insert(col)
            }
        }
        return valid
    }

    private func validAttackColumns(for playerIndex: Int) -> Set<Int> {
        guard let localPlayerIndex, let attackerCol = selectedAttackerColumn else { return [] }
        if playerIndex != localPlayerIndex {
            var valid = Set<Int>()
            for col in 0 ..< gameState.columns {
                if gameState.isValidAttackTarget(attackerColumn: attackerCol, defenderPlayerIndex: playerIndex, targetColumn: col) {
                    valid.insert(col)
                }
            }
            return valid
        }
        return []
    }

    private func handleSlotSelection(playerIndex: Int, row: Int, col: Int) {
        guard let localPlayerIndex else { return }

        // 1. Deployment (to local board)
        if let selectedCardId, playerIndex == localPlayerIndex {
            if gameState.isValidDeployment(playerIndex: localPlayerIndex, column: col) {
                HapticAndAudioEngine.shared.playDeployHaptic()
                let action = Action(
                    type: .deploy,
                    playerIndex: localPlayerIndex,
                    column: col,
                    cardId: selectedCardId
                )
                onAction(action)
                self.selectedCardId = nil
                return
            }
        }

        // 2. Attack Selection (from local board rank 0)
        if playerIndex == localPlayerIndex, row == 0 {
            if case .turnPhase(.AttackPhase) = gameState.phase {
                if let _ = gameState.battlefieldCard(playerIndex: localPlayerIndex, row: 0, column: col) {
                    HapticAndAudioEngine.shared.playCardSelectedHaptic()
                    if selectedAttackerColumn == col {
                        selectedAttackerColumn = nil
                    } else {
                        selectedAttackerColumn = col
                        selectedCardId = nil
                    }
                    return
                }
            }
        }

        // 3. Attack Execution (to opponent board)
        if let attackerCol = selectedAttackerColumn, playerIndex != localPlayerIndex {
            if gameState.isValidAttackTarget(attackerColumn: attackerCol, defenderPlayerIndex: playerIndex, targetColumn: col) {
                HapticAndAudioEngine.shared.playAttackHaptic()
                let action = Action(
                    type: .attack,
                    playerIndex: localPlayerIndex,
                    attackingColumn: attackerCol,
                    defendingColumn: col
                )
                onAction(action)
                selectedAttackerColumn = nil
                return
            }
        }
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
        guard sessionRole == .player else { return false }
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
    let selectedCardId: String?
    let selectedAttackerColumn: Int?
    let validDeployColumns: Set<Int>
    let validAttackColumns: Set<Int>
    let onCardSelected: (String) -> Void
    let onSlotSelected: (Int, Int) -> Void

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: AppSpacing.small), count: max(columns, 1))
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                    HStack {
                        Text("\(title): \(playerState.player.name)")
                            .font(.headline)
                        Spacer()
                        if isActivePlayer {
                            Text("Active")
                                .font(.caption)
                                .padding(.horizontal, AppSpacing.small)
                                .padding(.vertical, AppSpacing.tiny)
                                .background(Color.successStatus.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text("Lifepoints \(playerState.lifepoints) | drawpile \(playerState.visibleDrawpileCount) | discardPile \(playerState.discardPile.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("Battlefield")
                        .font(.subheadline.weight(.semibold))

                    LazyVGrid(columns: gridColumns, spacing: AppSpacing.small) {
                        ForEach(0 ..< (rows * columns), id: \.self) { index in
                            let row = index / columns
                            let col = index % columns
                            let isAttacker = row == 0 && selectedAttackerColumn == col && isActivePlayer

                            let isValidDeploy = validDeployColumns.contains(col)
                            let isValidAttack = validAttackColumns.contains(col)

                            BattlefieldSlotView(
                                slot: playerState.battlefield[safe: index] ?? nil,
                                isSelected: isAttacker,
                                isValidTarget: isValidDeploy || isValidAttack
                            )
                            .onTapGesture {
                                onSlotSelected(row, col)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("Hand")
                        .font(.subheadline.weight(.semibold))

                    if revealHand {
                        if playerState.hand.isEmpty {
                            Text("No visible cards in hand.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.small) {
                                    ForEach(playerState.hand) { card in
                                        VisibleHandCardView(
                                            card: card,
                                            isSelected: selectedCardId == card.id
                                        )
                                        .onTapGesture {
                                            onCardSelected(card.id)
                                        }
                                    }
                                }
                                .padding(.vertical, AppSpacing.tiny / 2)
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
    let isSelected: Bool
    let isValidTarget: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(slot == nil ? Color.slotBackground : Color.white)
            .overlay {
                if isValidTarget {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.successStatus.opacity(0.1))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? Color.primaryAction : (isValidTarget ? Color.successStatus : slotBorderColor),
                        lineWidth: (isSelected || isValidTarget) ? 3 : 1.5
                    )
            }
            .frame(minHeight: 104)
            .overlay(alignment: .center) {
                if let slot {
                    ZStack(alignment: .topTrailing) {
                        PhxCardView(
                            card: slot.card,
                            isFaceUp: !slot.faceDown,
                            isSelected: isSelected,
                            isHighlighted: isValidTarget
                        )

                        // Health badge overlay
                        Text("\(slot.currentHp)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -4)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(slot.card.face) of \(slot.card.suit.rawValue)")
                    .accessibilityValue("\(slot.currentHp) health points")
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.square.dashed")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("EMPTY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityLabel("Empty slot")
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(slot == nil ? "Tap to deploy selected card here" : "Tap to select as attacker")
    }

    private var slotBorderColor: Color {
        guard let slot else {
            return Color.cardBorder
        }
        return slot.card.suit.isRed ? Color.suitRed : Color.suitBlack
    }
}

private struct VisibleHandCardView: View {
    let card: Card
    let isSelected: Bool

    var body: some View {
        PhxCardView(
            card: card,
            isFaceUp: true,
            isSelected: isSelected
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.face) of \(card.suit.rawValue)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to select this card for deployment")
    }
}
