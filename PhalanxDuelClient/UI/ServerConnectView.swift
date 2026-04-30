import SwiftUI

public struct ServerConnectView: View {
    @ObservedObject public var sessionStore: SessionStore
    @State private var joinMatchID: String = ""
    @State private var watchMatchID: String = ""

    public init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    public var body: some View {
        List {
            Section("Preset Targets") {
                ForEach(AppEnvironment.presets, id: \.name) { preset in
                    Button(preset.name) {
                        sessionStore.loadPreset(preset)
                    }
                }
            }

            Section("Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Base URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("API Base URL", text: $sessionStore.serverBaseURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Documentation Base URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Documentation Base URL", text: $sessionStore.documentationBaseURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Button("Apply Custom Configuration") {
                    sessionStore.applyCustomConfiguration()
                }

                VStack(alignment: .leading, spacing: 4) {
                    endpointRow(title: "WebSocket", value: sessionStore.environment.webSocketURL.absoluteString)
                    endpointRow(title: "OpenAPI", value: sessionStore.environment.openAPIURL.absoluteString)
                }
                .font(.caption2.monospaced())
            }

            Section("Discovery") {
                Button(sessionStore.isRefreshingSnapshot ? "Refreshing…" : "Probe Server") {
                    Task {
                        await sessionStore.refreshServerSnapshot()
                    }
                }
                .disabled(sessionStore.isRefreshingSnapshot)

                if let serverHealth = sessionStore.serverHealth {
                    LabeledContent("Health", value: "\(serverHealth.status) | v\(serverHealth.version)")
                    LabeledContent("Region", value: serverHealth.observability.region)
                }

                if let serverDefaults = sessionStore.serverDefaults {
                    LabeledContent("Battlefield", value: "\(serverDefaults.rows)x\(serverDefaults.columns)")
                    LabeledContent("Initial Draw", value: "\(serverDefaults.initialDraw)")
                    LabeledContent("Lifepoints", value: "\(serverDefaults.startingLifepoints)")
                }
            }

            Section("Session") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Player Name", text: $sessionStore.localPlayerName)
                        .textInputAutocapitalization(.words)
                }

                Button("Create Match via POST /matches") {
                    Task {
                        await sessionStore.connectAndCreateMatch()
                    }
                }
                .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Match ID to join", text: $joinMatchID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Join Match") {
                        Task {
                            await sessionStore.connectAndJoinMatch(matchId: joinMatchID)
                        }
                    }
                    .disabled(joinMatchID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Match ID to watch", text: $watchMatchID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Watch Match") {
                        Task {
                            await sessionStore.connectAndWatchMatch(matchId: watchMatchID)
                        }
                    }
                    .disabled(watchMatchID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if !sessionStore.activeMatches.isEmpty {
                Section("Active Matches") {
                    ForEach(sessionStore.activeMatches) { match in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(match.matchId)
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)

                            Text(matchSummary(match))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button("Join") {
                                    Task {
                                        await sessionStore.connectAndJoinMatch(matchId: match.matchId)
                                    }
                                }

                                Button("Watch") {
                                    Task {
                                        await sessionStore.connectAndWatchMatch(matchId: match.matchId)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
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

            Section("Recent Debug") {
                DebugLogView(
                    entries: Array(sessionStore.debugLog.suffix(6)),
                    events: Array(sessionStore.events.suffix(4)),
                    compact: true
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Server Connect")
    }

    private func endpointRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .fontWeight(.semibold)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private func matchSummary(_ match: ActiveMatchSummary) -> String {
        let players = match.players.map(\.name).joined(separator: " vs ")
        let phase = match.phaseName ?? "waiting"
        return "\(players.isEmpty ? "No players yet" : players) | phase \(phase) | spectators \(match.spectatorCount)"
    }
}
