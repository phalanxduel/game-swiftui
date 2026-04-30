import SwiftUI

public struct GameSessionView: View {
    @ObservedObject public var sessionStore: SessionStore

    public init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    public var body: some View {
        List {
            Section("Session Info") {
                LabeledContent("Target", value: sessionStore.environment.name)
                LabeledContent("API", value: sessionStore.environment.apiBaseURL.absoluteString)
                LabeledContent("WebSocket", value: sessionStore.connectionState.label)
                if let activeMatchId = sessionStore.activeMatchId {
                    LabeledContent("matchId", value: activeMatchId)
                }
                if let sessionRole = sessionStore.sessionRole {
                    LabeledContent("Role", value: sessionRole.rawValue)
                }
                if let localPlayerIndex = sessionStore.localPlayerIndex {
                    LabeledContent("playerIndex", value: String(localPlayerIndex))
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

            if let state = sessionStore.currentState {
                Section("Authoritative GameState") {
                    LabeledContent("phase", value: state.phase.displayName)
                    LabeledContent("turnNumber", value: String(state.turnNumber))
                    LabeledContent("activePlayer", value: state.activePlayerName)
                    LabeledContent("specVersion", value: state.specVersion)
                    if let latestTurnResult = sessionStore.latestTurnResult?.turnHash {
                        LabeledContent("turnHash", value: latestTurnResult)
                    }
                    if let outcome = state.outcome {
                        LabeledContent("Outcome", value: "\(outcome.victoryType.rawValue) | winnerIndex \(outcome.winnerIndex)")
                    }
                }

                if sessionStore.sessionRole == .player {
                    Section {
                        Button("Send Pass") {
                            sessionStore.sendPassAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.phase == .gameOver)
                    }
                }

                Section("Battlefield") {
                    GameTableView(
                        gameState: state,
                        localPlayerIndex: sessionStore.localPlayerIndex,
                        sessionRole: sessionStore.sessionRole,
                        onAction: { action in
                            sessionStore.sendAction(action)
                        }
                    )
                    .listRowInsets(EdgeInsets()) // Allow the grid to take full width
                    .padding(.vertical, AppSpacing.medium)
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
        .listStyle(.insetGrouped)
        .navigationTitle("Game Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}
