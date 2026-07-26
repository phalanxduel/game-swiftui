import SwiftUI

public struct GameSessionView: View {
    @ObservedObject public var sessionStore: SessionStore

    public init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    public var body: some View {
        List {
            if let state = sessionStore.currentState,
               state.phase == .gameOver,
               let outcome = state.outcome {
                Section("Game Over") {
                    Text("Game Over")
                        .font(.title2.bold())
                        .accessibilityIdentifier("game.game-over")

                    LabeledContent("Winner") {
                        Text(outcome.winnerIndex.flatMap { state.players[safe: $0]?.player.name } ?? "Draw")
                            .accessibilityIdentifier("game.winner-name")
                    }
                    LabeledContent("Victory") {
                        Text(outcome.victoryType.rawValue)
                            .accessibilityIdentifier("game.victory-type")
                    }
                    LabeledContent("Final Turn") {
                        Text(String(outcome.turnNumber))
                            .accessibilityIdentifier("game.final-turn")
                    }
                    LabeledContent("Actions") {
                        Text(String(authoritativeActionCount(state)))
                            .accessibilityIdentifier("game.action-count")
                    }
                    ForEach(state.players.indices, id: \.self) { playerIndex in
                        let playerState = state.players[playerIndex]
                        LabeledContent("Player \(playerIndex + 1)") {
                            Text(playerState.player.name)
                                .accessibilityIdentifier("game.player.\(playerIndex).name")
                        }
                        LabeledContent("Player \(playerIndex + 1) LP") {
                            Text(String(playerState.lifepoints))
                                .accessibilityIdentifier("game.player.\(playerIndex).lifepoints")
                        }
                    }
                    if let turnHash = sessionStore.latestTurnResult?.turnHash {
                        LabeledContent("Turn Hash") {
                            Text(turnHash)
                                .accessibilityIdentifier("game.turn-hash")
                        }
                    }
                }
            }

            Section("Session Info") {
                LabeledContent("Target", value: sessionStore.environment.name)
                LabeledContent("API") {
                    Text(sessionStore.environment.apiBaseURL.absoluteString)
                        .accessibilityIdentifier("game.api-url")
                }
                LabeledContent("WebSocket") {
                    Text(sessionStore.connectionState.label)
                        .accessibilityIdentifier("game.websocket-state")
                }
                if let activeMatchId = sessionStore.activeMatchId {
                    LabeledContent("matchId") {
                        Text(activeMatchId)
                            .accessibilityIdentifier("game.match-id")
                    }
                }
                if let sessionRole = sessionStore.sessionRole {
                    LabeledContent("Role", value: sessionRole.rawValue)
                }
                if let localPlayerIndex = sessionStore.localPlayerIndex {
                    LabeledContent("playerIndex") {
                        Text(String(localPlayerIndex))
                            .accessibilityIdentifier("game.local-player-index")
                    }
                }
                LabeledContent("Spectators", value: String(sessionStore.spectatorCount))
            }

            if let serverHealth = sessionStore.serverHealth {
                Section("Server Snapshot") {
                    LabeledContent("Health", value: "\(serverHealth.status) | v\(serverHealth.version)")
                    if let serverDefaults = sessionStore.serverDefaults {
                        LabeledContent("Default Battlefield", value: "\(serverDefaults.rows)x\(serverDefaults.columns)")
                        LabeledContent("Default Starting LP", value: "\(serverDefaults.startingLifepoints)")
                    }
                }
            }

            if let recentError = sessionStore.recentError {
                Section("Last Error") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recentError.title)
                            .font(.headline)
                        Text(recentError.message)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.red)
                }
            }

            if sessionStore.latestTurnResult != nil {
                Section("Tactical Combat Resolution") {
                    CombatBannerView(
                        turnResult: sessionStore.latestTurnResult,
                        events: sessionStore.events
                    )
                }
            }

            if !automationEnabled, let state = sessionStore.currentState {
                Section("Narration") {
                    NarrationTickerView(state: state)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, AppSpacing.small)
                }
                .listRowBackground(Color.gameBackground)

                Section("Engagement Log") {
                    EngagementLogView(state: state)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, AppSpacing.small)
                }
                .listRowBackground(Color.gameBackground)
            }

            if let state = sessionStore.currentState {
                Section("Authoritative GameState") {
                    LabeledContent("phase") {
                        Text(state.phase.displayName)
                            .accessibilityIdentifier("game.phase")
                    }
                    LabeledContent("turnNumber") {
                        Text(String(state.turnNumber))
                            .accessibilityIdentifier("game.turn-number")
                    }
                    LabeledContent("activePlayer") {
                        Text(state.activePlayerName)
                            .accessibilityIdentifier("game.active-player")
                    }
                    LabeledContent("turnOwner") {
                        Text(state.activePlayerIndex == sessionStore.localPlayerIndex ? "local" : "opponent")
                            .accessibilityIdentifier("game.turn-owner")
                    }
                    LabeledContent("actionCount") {
                        Text(String(authoritativeActionCount(state)))
                            .accessibilityIdentifier("game.current-action-count")
                    }
                    LabeledContent("specVersion", value: state.specVersion)
                    if let latestTurnResult = sessionStore.latestTurnResult?.turnHash {
                        LabeledContent("turnHash", value: latestTurnResult)
                    }
                    if let outcome = state.outcome {
                        LabeledContent(
                            "Outcome",
                            value: "\(outcome.victoryType.rawValue) | winnerIndex \(outcome.winnerIndex.map(String.init) ?? "none")"
                        )
                    }
                }

                if sessionStore.sessionRole == .player {
                    Section {
                        Button("Send Pass") {
                            sessionStore.sendPassAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!sessionStore.validActions.contains { $0.type == .pass })
                        .accessibilityIdentifier("game.pass")
                    }
                }

                if !automationEnabled {
                    Section("Battlefield") {
                        GameTableView(
                            gameState: state,
                            localPlayerIndex: sessionStore.localPlayerIndex,
                            sessionRole: sessionStore.sessionRole,
                            validActions: sessionStore.validActions,
                            onAction: { action in
                                sessionStore.sendAction(action)
                            }
                        )
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, AppSpacing.medium)
                    }
                    .listRowBackground(Color.gameBackground)
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "Waiting for authoritative game state",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("The session is connected, but no `gameState` message has been received yet.")
                    )
                }
            }

            Section("Debug") {
                DebugLogView(entries: sessionStore.debugLog, events: sessionStore.events)
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
#else
        .listStyle(.sidebar)
#endif
        .navigationTitle("Game Session")
        .accessibilityIdentifier("game.session")
        .safeAreaInset(edge: .top, spacing: 0) {
            if automationEnabled,
               let state = sessionStore.currentState,
               state.phase != .gameOver {
                VStack(spacing: 0) {
                    automationHUD(for: state)
                    automationBoard(for: state)
                }
            }
        }
    }

    /// Pinned above the scrollable list, alongside the HUD, so the
    /// battlefield stays visible to a human watcher instead of scrolling
    /// out of view inside the List.
    @ViewBuilder
    private func automationBoard(for state: GameState) -> some View {
        GameTableView(
            gameState: state,
            localPlayerIndex: sessionStore.localPlayerIndex,
            sessionRole: sessionStore.sessionRole,
            validActions: sessionStore.validActions,
            onAction: { action in
                sessionStore.sendAction(action)
            }
        )
        .padding(.vertical, AppSpacing.medium)
        .background(Color.gameBackground)
        .overlay(alignment: .bottom) {
            Divider()
        }

        NarrationTickerView(state: state)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.small)
            .background(Color.gameBackground)

        EngagementLogView(state: state)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.small)
            .background(Color.gameBackground)
    }

    /// Pinned above the scrollable list so automation controls stay hittable
    /// regardless of list scroll position.
    @ViewBuilder
    private func automationHUD(for state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                "LIVE • SERVER-AUTHORITATIVE ACTIONS",
                systemImage: "eye.fill"
            )
            .font(.caption.monospaced().bold())
            .foregroundStyle(Color.goldAccent)
            .accessibilityIdentifier("automation.game-panel")

            HStack(spacing: AppSpacing.medium) {
                hudField("Phase", state.phase.displayName, id: "automation.phase")
                hudField("Turn", String(state.turnNumber), id: "automation.turn-number")
                hudField(
                    "Owner",
                    state.activePlayerIndex == sessionStore.localPlayerIndex
                        ? "local"
                        : "opponent",
                    id: "automation.turn-owner"
                )
                hudField(
                    "Actions",
                    String(authoritativeActionCount(state)),
                    id: "automation.action-count"
                )
                if let localPlayerIndex = sessionStore.localPlayerIndex {
                    hudField(
                        "Local",
                        String(localPlayerIndex),
                        id: "automation.local-player-index"
                    )
                }
                ForEach(state.players.indices, id: \.self) { playerIndex in
                    hudField(
                        state.players[playerIndex].player.name,
                        "\(state.players[playerIndex].lifepoints) LP",
                        id: "automation.player.\(playerIndex).lifepoints"
                    )
                }
            }

            hudField("Match", state.matchId, id: "automation.match-id")

            Text(lastActionDescription(for: state))
                .font(.caption.monospaced())
                .foregroundStyle(Color.gameTextMuted)
                .lineLimit(1)
                .accessibilityIdentifier("automation.last-action")
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gameSurfaceElevated)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private func hudField(_ label: String, _ value: String, id: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.gameTextDim)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(Color.gameTextPrimary)
                .lineLimit(1)
                .accessibilityIdentifier(id)
        }
    }

    private func authoritativeActionCount(_ state: GameState) -> Int {
        state.transactionLog?.filter { $0.action.type != .systemInit }.count ?? 0
    }

    private func lastActionDescription(for state: GameState) -> String {
        guard let entry = state.transactionLog?.last(where: { $0.action.type != .systemInit }) else {
            return "Waiting for the first action"
        }
        let action = entry.action
        let by = action.playerIndex.map { "P\($0 + 1)" } ?? "System"
        switch action.type {
        case .deploy:
            return "\(by) deployed \(action.cardId ?? "a card") to column \(action.column ?? -1)"
        case .attack:
            return "\(by) attacked \(action.attackingColumn ?? -1) → \(action.defendingColumn ?? -1)"
        case .reinforce:
            return "\(by) reinforced with \(action.cardId ?? "a card")"
        case .pass:
            return "\(by) passed"
        case .forfeit:
            return "\(by) forfeited"
        case .systemInit:
            return "system initialization"
        }
    }

    private var automationEnabled: Bool {
        ProcessInfo.processInfo.environment["PHALANX_AUTOMATION"] == "true"
    }
}
