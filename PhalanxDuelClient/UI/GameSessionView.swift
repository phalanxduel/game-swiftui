import SwiftUI

public struct GameSessionView: View {
    @ObservedObject public var sessionStore: SessionStore

    public init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Session") {
                    VStack(alignment: .leading, spacing: 8) {
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
                }

                if let serverHealth = sessionStore.serverHealth {
                    GroupBox("Server Snapshot") {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Health", value: "\(serverHealth.status) | v\(serverHealth.version)")
                            if let serverDefaults = sessionStore.serverDefaults {
                                LabeledContent("Default Battlefield", value: "\(serverDefaults.rows)x\(serverDefaults.columns)")
                                LabeledContent("Default Starting LP", value: "\(serverDefaults.startingLifepoints)")
                            }
                        }
                    }
                }
                if let recentError = sessionStore.recentError {
                    Text(recentError)
                        .foregroundStyle(.red)
                }

                if let state = sessionStore.currentState {
                    GroupBox("Authoritative GameState") {
                        VStack(alignment: .leading, spacing: 8) {
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
                    }

                    if sessionStore.sessionRole == .player {
                        Button("Send Pass") {
                            sessionStore.sendPassAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.phase == .gameOver)
                    }

                    GameTableView(
                        gameState: state,
                        localPlayerIndex: sessionStore.localPlayerIndex,
                        sessionRole: sessionStore.sessionRole
                    )
                } else {
                    ContentUnavailableView(
                        "Waiting for authoritative game state",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("The session is connected, but no `gameState` message has been received yet.")
                    )
                }

                GroupBox("Debug") {
                    DebugLogView(entries: sessionStore.debugLog, events: sessionStore.events)
                }
            }
            .padding()
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}
