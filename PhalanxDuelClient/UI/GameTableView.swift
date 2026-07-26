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
        ZStack {
            VStack(spacing: AppSpacing.small) {
                TurnStatusBarView(gameState: gameState, viewerIndex: viewerIndex)

                ForEach(Array(displayOrder.enumerated()), id: \.offset) { index, playerIndex in
                    if let playerState = gameState.players[safe: playerIndex] {
                        PlayerFieldView(
                            title: sectionTitle(for: playerIndex),
                            playerState: playerState,
                            playerIndex: playerIndex,
                            rows: gameState.rows,
                            columns: gameState.columns,
                            isActivePlayer: gameState.activePlayerIndex == playerIndex,
                            // The opponent's rows render back-to-front so both players'
                            // front line (row 0, used for attacking) meets at the shared
                            // boundary between the two fields, like a dueling table.
                            isOpponent: playerIndex != viewerIndex,
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

                        // Rendered once, at the shared boundary between the two
                        // fields — a compact "dueling table" stat strip, matching
                        // the browser reference's mid-board HP/drawpile/discard/
                        // hand readout for both combatants at a glance.
                        if index == 0 {
                            DuelStatStripView(gameState: gameState, displayOrder: displayOrder)
                        }
                    }
                }
            }

            CombatOverlayView(gameState: gameState)
        }
        .background(Color.gameBackground)
    }

    /// The board always renders from player-0's perspective when there is no
    /// local player (spectators), matching the browser reference client.
    private var viewerIndex: Int {
        localPlayerIndex ?? 0
    }

    private var displayOrder: [Int] {
        let opponentIndex = viewerIndex == 0 ? 1 : 0
        return [opponentIndex, viewerIndex]
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
    let isOpponent: Bool
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

    private struct GridCell: Hashable {
        let row: Int
        let col: Int
    }

    /// Row 0 (the front line, used for attacking) renders adjacent to the
    /// shared boundary between the two players' fields: last for the
    /// opponent (rendered above), first for the viewer (rendered below).
    /// LazyVGrid only flattens a `ForEach` that is its direct child, so the
    /// visual (row, col) order is precomputed into one flat sequence rather
    /// than nesting a `ForEach` inside another `ForEach`.
    private var cellOrder: [GridCell] {
        let rowsAscending = Array(0 ..< max(rows, 1))
        let visualRows = isOpponent ? rowsAscending.reversed() : Array(rowsAscending)
        return visualRows.flatMap { row in
            (0 ..< max(columns, 1)).map { col in GridCell(row: row, col: col) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                HStack {
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.gameTextMuted)
                    Text(playerState.player.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.gameTextPrimary)
                        .accessibilityIdentifier("game.field.player.\(playerIndex).name")
                    Spacer()
                    if isActivePlayer {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(Color.goldAccent)
                            .padding(.horizontal, AppSpacing.small)
                            .padding(.vertical, 3)
                            .background(Color.goldAccent.opacity(0.15))
                            .overlay(Capsule().strokeBorder(Color.goldAccent.opacity(0.4), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                }

                Text("LP \(playerState.lifepoints) · DRAW \(playerState.visibleDrawpileCount) · DISCARD \(playerState.discardPile.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.gameTextDim)
                    .accessibilityIdentifier("game.field.player.\(playerIndex).lifepoints-summary")
            }

            LazyVGrid(columns: gridColumns, spacing: AppSpacing.small) {
                ForEach(cellOrder, id: \.self) { cell in
                    let row = cell.row
                    let col = cell.col
                    let index = row * columns + col
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

            if revealHand {
                if playerState.hand.isEmpty {
                    Text("No visible cards in hand.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.gameTextDim)
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
                    .accessibilityIdentifier("game.hand-scroll.\(playerIndex)")
                }
            } else {
                // Face-down, count-visible — the same information a player
                // would have across a real table: how many cards their
                // opponent holds, never what they are.
                HiddenHandView(cardCount: playerState.visibleHandCount, playerIndex: playerIndex)
            }
        }
        .padding(AppSpacing.medium)
        .background(Color.gameSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isActivePlayer ? Color.goldAccent.opacity(0.35) : Color.gameBorder, lineWidth: isActivePlayer ? 1.5 : 1)
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
        RoundedRectangle(cornerRadius: 12)
            .fill(slot == nil ? Color.gameSurfaceElevated.opacity(0.5) : Color.clear)
            .overlay {
                if isValidTarget {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.goldAccent.opacity(0.08))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.goldAccent : (isValidTarget ? Color.goldBright : slotBorderColor),
                        lineWidth: (isSelected || isValidTarget) ? 2.5 : 1
                    )
            }
            .shadow(color: isSelected ? Color.goldAccent.opacity(0.5) : .clear, radius: isSelected ? 8 : 0)
            .frame(minHeight: 104)
            .overlay(alignment: .center) {
                if let slot {
                    PhxCardView(
                        card: slot.card,
                        isFaceUp: !slot.faceDown,
                        isSelected: isSelected,
                        isHighlighted: isValidTarget,
                        currentHp: slot.faceDown ? nil : slot.currentHp
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(slot.card.face) of \(slot.card.suit.rawValue)")
                    .accessibilityValue("\(slot.currentHp) health points")
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gameTextDim.opacity(0.5))
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
            return Color.gameBorder
        }
        return slot.card.suit.accentColor.opacity(0.5)
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

/// A face-down, count-visible hand — the same information available to a
/// player across a real table: how many cards an opponent holds, never
/// their identity. Card backs overlap slightly, matching a fanned deck.
private struct HiddenHandView: View {
    let cardCount: Int
    let playerIndex: Int

    var body: some View {
        HStack(spacing: -34) {
            ForEach(0 ..< cardCount, id: \.self) { _ in
                PhxCardView(card: nil, isFaceUp: false)
            }
        }
        .frame(height: 98, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("game.hand-hidden.\(playerIndex)")
        .accessibilityLabel("Opponent hand")
        .accessibilityValue("\(cardCount) card(s)")
    }
}

/// Compact "T{n} / YOUR_TURN" strip above the battlefield, matching the
/// browser reference's top bar. Renders in both the automation HUD path and
/// the normal player path since GameTableView is shared by both.
private struct TurnStatusBarView: View {
    let gameState: GameState
    let viewerIndex: Int

    var body: some View {
        HStack {
            Text("T\(gameState.turnNumber)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.gameTextMuted)

            Spacer()

            Text(phaseLabel)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.gameTextDim)

            Spacer()

            Text(turnLabel)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(isViewerTurn ? Color.goldAccent : Color.gameTextDim)
        }
        .padding(.horizontal, AppSpacing.small)
    }

    private var isViewerTurn: Bool {
        gameState.activePlayerIndex == viewerIndex
    }

    private var turnLabel: String {
        isViewerTurn ? "YOUR_TURN" : "OPPONENT_TURN"
    }

    private var phaseLabel: String {
        switch gameState.phase {
        case let .turnPhase(phase):
            switch phase {
            case .DeploymentPhase: "DEPLOYMENT"
            case .AttackPhase: "COMBAT"
            case .ReinforcementPhase: "REINFORCEMENT"
            default: phase.rawValue.uppercased()
            }
        case .gameOver: "TERMINATED"
        case let .unknown(value): value.uppercased()
        }
    }
}

/// Mid-table LP/drawpile/discard/hand readout for both combatants at the
/// shared boundary between the two fields — mirrors the browser reference's
/// duel-table stat strip.
private struct DuelStatStripView: View {
    let gameState: GameState
    let displayOrder: [Int]

    var body: some View {
        HStack {
            ForEach(displayOrder, id: \.self) { playerIndex in
                if let player = gameState.players[safe: playerIndex] {
                    HStack(spacing: 6) {
                        Text(player.player.name.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.gameTextDim)
                        Text("\(player.lifepoints) LP")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.gameTextPrimary)
                        Text("· \(player.visibleDrawpileCount) · \(player.discardPile.count) · \(player.visibleHandCount)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.gameTextDim)
                    }
                    if playerIndex != displayOrder.last {
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, 6)
        .background(Color.gameSurfaceElevated.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Transient center-screen callouts for phase changes and attacks, ported
/// from client/src/narration-overlay.ts's phase-announcement + attack-line
/// behavior. Both are derived from data already in `GameState` — no new
/// wire fields required.
private struct CombatOverlayView: View {
    let gameState: GameState

    @State private var phaseFlash: String?
    @State private var attackFlash: String?
    @State private var lastPhaseKey: String?
    @State private var lastAttackSequence: Int?

    var body: some View {
        VStack(spacing: 6) {
            if let phaseFlash {
                Text(phaseFlash)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goldBright)
                    .shadow(color: Color.goldAccent.opacity(0.6), radius: 12)
            }
            if let attackFlash {
                Text(attackFlash)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.gameTextPrimary)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.easeOut(duration: 0.2), value: phaseFlash)
        .animation(.easeOut(duration: 0.2), value: attackFlash)
        .onChange(of: gameState.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
        .onChange(of: gameState.transactionLog?.count) { _, _ in
            handleLatestAttack()
        }
        .onAppear {
            lastPhaseKey = gameState.phase.rawValue
            lastAttackSequence = gameState.transactionLog?.last(where: { $0.details.type == .attack })?.sequenceNumber
        }
    }

    private func handlePhaseChange(_ phase: GamePhase) {
        guard phase.rawValue != lastPhaseKey else { return }
        lastPhaseKey = phase.rawValue
        guard case let .turnPhase(turnPhase) = phase else { return }

        let label: String? = switch turnPhase {
        case .DeploymentPhase: "DEPLOYMENT"
        case .AttackPhase: "COMBAT"
        case .ReinforcementPhase: "REINFORCEMENT"
        default: nil
        }
        guard let label else { return }

        phaseFlash = label
        Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            if phaseFlash == label { phaseFlash = nil }
        }
    }

    private func handleLatestAttack() {
        guard let entry = gameState.transactionLog?.last(where: { $0.details.type == .attack }) else { return }
        guard entry.sequenceNumber != lastAttackSequence else { return }
        lastAttackSequence = entry.sequenceNumber
        guard let combat = entry.details.combat,
              let step = combat.steps.first(where: { $0.damage > 0 }) else { return }

        let targetLabel = step.card?.shortLabel ?? (step.target == .playerLp ? "core" : "card")
        let text = "\(combat.attackerCard.shortLabel) attacks \(targetLabel) for \(step.damage) damage"
        attackFlash = text
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            if attackFlash == text { attackFlash = nil }
        }
    }
}
