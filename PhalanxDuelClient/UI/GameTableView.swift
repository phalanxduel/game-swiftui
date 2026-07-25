import SwiftUI

public struct GameTableView: View {
    public let gameState: GameState
    public let localPlayerIndex: Int?
    public let sessionRole: SessionStore.SessionRole?
    public let validActions: [Action]
    public let onAction: (Action) -> Void

    @State private var selectedCardId: String?
    @State private var selectedAttackerColumn: Int?

    public init(
        gameState: GameState,
        localPlayerIndex: Int?,
        sessionRole: SessionStore.SessionRole?,
        validActions: [Action],
        onAction: @escaping (Action) -> Void
    ) {
        self.gameState = gameState
        self.localPlayerIndex = localPlayerIndex
        self.sessionRole = sessionRole
        self.validActions = validActions
        self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: AppSpacing.medium) {
            ForEach(displayOrder, id: \.self) { playerIndex in
                if let playerState = gameState.players[safe: playerIndex] {
                    PlayerFieldView(
                        title: sectionTitle(for: playerIndex),
                        playerState: playerState,
                        playerIndex: playerIndex,
                        rows: gameState.rows,
                        columns: gameState.columns,
                        isActivePlayer: gameState.activePlayerIndex == playerIndex,
                        revealHand: shouldRevealHand(for: playerIndex),
                        selectedCardId: selectedCardId,
                        selectedAttackerColumn: selectedAttackerColumn,
                        validDeployColumns: validDeployColumns(for: playerIndex),
                        validAttackColumns: validAttackColumns(for: playerIndex),
                        validActions: playerIndex == localPlayerIndex ? validActions : [],
                        onCardSelected: { cardId in
                            if let localPlayerIndex,
                               playerIndex == localPlayerIndex,
                               validActions.contains(where: {
                                   $0.type == .reinforce &&
                                       $0.playerIndex == localPlayerIndex &&
                                       $0.cardId == cardId
                               }) {
                                HapticAndAudioEngine.shared.playDeployHaptic()
                                onAction(
                                    Action(
                                        type: .reinforce,
                                        playerIndex: localPlayerIndex,
                                        cardId: cardId
                                    )
                                )
                                selectedCardId = nil
                                selectedAttackerColumn = nil
                                return
                            }

                            guard validActions.contains(where: {
                                $0.type == .deploy &&
                                    $0.playerIndex == localPlayerIndex &&
                                    $0.cardId == cardId
                            }) else {
                                return
                            }

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
        guard let localPlayerIndex,
              playerIndex == localPlayerIndex,
              let selectedCardId
        else {
            return []
        }

        return Set(
            validActions.compactMap { action in
                guard action.type == .deploy,
                      action.playerIndex == localPlayerIndex,
                      action.cardId == selectedCardId
                else {
                    return nil
                }
                return action.column
            }
        )
    }

    private func validAttackColumns(for playerIndex: Int) -> Set<Int> {
        guard let localPlayerIndex, let attackerCol = selectedAttackerColumn else { return [] }
        guard playerIndex != localPlayerIndex else { return [] }

        return Set(
            validActions.compactMap { action in
                guard action.type == .attack,
                      action.playerIndex == localPlayerIndex,
                      action.attackingColumn == attackerCol
                else {
                    return nil
                }
                return action.defendingColumn
            }
        )
    }

    private func handleSlotSelection(playerIndex: Int, row: Int, col: Int) {
        guard let localPlayerIndex else { return }

        // 1. Deployment (to local board)
        if let selectedCardId, playerIndex == localPlayerIndex {
            if validActions.contains(where: {
                $0.type == .deploy &&
                    $0.playerIndex == localPlayerIndex &&
                    $0.column == col &&
                    $0.cardId == selectedCardId
            }) {
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
            if validActions.contains(where: {
                $0.type == .attack &&
                    $0.playerIndex == localPlayerIndex &&
                    $0.attackingColumn == col
            }) {
                if gameState.battlefieldCard(playerIndex: localPlayerIndex, row: 0, column: col) != nil {
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
            if validActions.contains(where: {
                $0.type == .attack &&
                    $0.playerIndex == localPlayerIndex &&
                    $0.attackingColumn == attackerCol &&
                    $0.defendingColumn == col
            }) {
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
    let playerIndex: Int
    let rows: Int
    let columns: Int
    let isActivePlayer: Bool
    let revealHand: Bool
    let selectedCardId: String?
    let selectedAttackerColumn: Int?
    let validDeployColumns: Set<Int>
    let validAttackColumns: Set<Int>
    let validActions: [Action]
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
                            .accessibilityIdentifier("game.field.player.\(playerIndex).name")
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
                        .accessibilityIdentifier("game.field.player.\(playerIndex).lifepoints-summary")
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
                                isValidTarget: isValidDeploy || isValidAttack,
                                accessibilityIdentifier: "game.slot.\(playerIndex).\(row).\(col)",
                                accessibilityState: slotAccessibilityState(
                                    row: row,
                                    column: col,
                                    isValidDeploy: isValidDeploy,
                                    isValidAttack: isValidAttack
                                )
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
                                            isSelected: selectedCardId == card.id,
                                            accessibilityIdentifier: "game.hand-card.\(playerIndex).\(card.id)",
                                            accessibilityState: handCardAccessibilityState(card.id)
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

    private func slotAccessibilityState(
        row: Int,
        column: Int,
        isValidDeploy: Bool,
        isValidAttack: Bool
    ) -> String {
        if isValidDeploy {
            return "deploy-target"
        }
        if isValidAttack {
            return "attack-target"
        }
        if row == 0,
           validActions.contains(where: {
               $0.type == .attack &&
                   $0.playerIndex == playerIndex &&
                   $0.attackingColumn == column
           }) {
            return "attacker"
        }
        let slot = playerState.battlefield[safe: row * columns + column] ?? nil
        return slot == nil ? "empty" : "occupied"
    }

    private func handCardAccessibilityState(_ cardId: String) -> String {
        if validActions.contains(where: {
            $0.type == .reinforce &&
                $0.playerIndex == playerIndex &&
                $0.cardId == cardId
        }) {
            return "reinforce"
        }
        if validActions.contains(where: {
            $0.type == .deploy &&
                $0.playerIndex == playerIndex &&
                $0.cardId == cardId
        }) {
            return "deploy"
        }
        return "unavailable"
    }
}

private struct BattlefieldSlotView: View {
    let slot: BattlefieldCard?
    let isSelected: Bool
    let isValidTarget: Bool
    let accessibilityIdentifier: String
    let accessibilityState: String

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
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(accessibilityIdentifier)
            .accessibilityLabel(slot.map { "\($0.card.face) of \($0.card.suit.rawValue)" } ?? "Empty slot")
            .accessibilityValue(accessibilityState)
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
    let accessibilityIdentifier: String
    let accessibilityState: String

    var body: some View {
        PhxCardView(
            card: card,
            isFaceUp: true,
            isSelected: isSelected
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel("\(card.face) of \(card.suit.rawValue)")
        .accessibilityValue(accessibilityState)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to select this card for deployment")
    }
}
