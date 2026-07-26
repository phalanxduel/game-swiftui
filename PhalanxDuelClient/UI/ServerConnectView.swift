import SwiftUI

public struct ServerConnectView: View {
    @ObservedObject public var sessionStore: SessionStore
    @State private var joinMatchID: String = ""
    @State private var watchMatchID: String = ""
    @State private var showStoreSheet: Bool = false
    @State private var showLadderSheet: Bool = false
    @State private var showProfileSheet: Bool = false
    @State private var showMatchmakingSheet: Bool = false
    @State private var showReplaySheet: Bool = false
    @State private var showSocialSheet: Bool = false
    @State private var loginEmail: String = ""
    @State private var loginPassword: String = ""

    public init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    public var body: some View {
        List {
            Section("Account") {
                accountSection
            }

            if automationEnabled {
                Section("Automation Proof") {
                    Label(
                        "HEADS-UP UI AUTOMATION",
                        systemImage: "eye.fill"
                    )
                    .font(.headline.monospaced())
                    .foregroundStyle(.blue)
                    .accessibilityIdentifier("automation.launch-panel")

                    Text("Every action remains visible and uses the live WebSocket session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    sessionControls
                }
            }

            Section("Matchmaking & Play") {
                Button("Find Ranked 1v1 Match") {
                    showMatchmakingSheet = true
                }
                .buttonStyle(.borderedProminent)
                .sheet(isPresented: $showMatchmakingSheet) {
                    MatchmakingQueueView(sessionStore: sessionStore)
                }

                Button("Launch Match Replay Viewer") {
                    showReplaySheet = true
                }
                .sheet(isPresented: $showReplaySheet) {
                    ReplayViewer()
                }

                Button("Open Community Activity Feed") {
                    showSocialSheet = true
                }
                .sheet(isPresented: $showSocialSheet) {
                    SocialFeedView()
                }
            }

            Section("Store & Career Hub") {
                Button("Open In-App Cosmetic Store") {
                    showStoreSheet = true
                }
                .sheet(isPresented: $showStoreSheet) {
                    StoreView()
                }

                Button("Open Global Ladder") {
                    showLadderSheet = true
                }
                .sheet(isPresented: $showLadderSheet) {
                    LeaderboardView()
                }

                Button("Open Player Profile") {
                    showProfileSheet = true
                }
                .sheet(isPresented: $showProfileSheet) {
                    ProfileView(gamertag: sessionStore.localPlayerName)
                }
            }
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
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
#endif
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Documentation Base URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Documentation Base URL", text: $sessionStore.documentationBaseURLText)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
#endif
                        .autocorrectionDisabled()
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
                .accessibilityIdentifier("session.probe-server")

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

            if !automationEnabled {
                Section("Session") {
                    sessionControls
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
#if os(iOS)
        .listStyle(.insetGrouped)
#else
        .listStyle(.sidebar)
#endif
        .navigationTitle("Server Connect")
        .accessibilityIdentifier("server-connect")
    }

    private func endpointRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .fontWeight(.semibold)
            Text(value)
                .textSelection(.enabled)
        }
    }

    /// Real account state: signed in (via native login or a web-session
    /// handoff) vs. guest. Registration itself is web-only — see
    /// client/src/components/AuthPanel.tsx and TASK-366's notes — this app
    /// only ever logs in an existing account or receives one via handoff.
    @ViewBuilder
    private var accountSection: some View {
        if let account = sessionStore.account {
            VStack(alignment: .leading, spacing: 4) {
                Label(account.displayName, systemImage: "person.crop.circle.fill")
                    .font(.headline)
                    .accessibilityIdentifier("account.display-name")
                Text("ELO \(account.elo) · \(account.email)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Log Out", role: .destructive) {
                sessionStore.logout()
            }
            .accessibilityIdentifier("account.logout")
        } else {
            Text("Signed out — playing as guest. Sign in with an existing account, or sign in on the web and use \"Open in Desktop App\".")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let authError = sessionStore.authError {
                Text(authError.message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            TextField("Email", text: $loginEmail)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
#endif
                .autocorrectionDisabled()
                .accessibilityIdentifier("account.login-email")

            SecureField("Password", text: $loginPassword)
                .accessibilityIdentifier("account.login-password")

            Button(sessionStore.isAuthenticating ? "Signing In…" : "Log In") {
                Task {
                    await sessionStore.login(email: loginEmail, password: loginPassword)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(sessionStore.isAuthenticating || loginEmail.isEmpty || loginPassword.isEmpty)
            .accessibilityIdentifier("account.login-submit")
        }
    }

    @ViewBuilder
    private var sessionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Name")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Player Name", text: $sessionStore.localPlayerName)
#if os(iOS)
                .textInputAutocapitalization(.words)
#endif
                .accessibilityIdentifier("session.player-name")
        }

        Button("Play Bot (Random)") {
            sessionStore.connectAndCreateBotMatch(opponent: "bot-random")
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("session.create-bot-random")

        Button("Play Bot (Heuristic)") {
            sessionStore.connectAndCreateBotMatch(opponent: "bot-heuristic")
        }
        .accessibilityIdentifier("session.create-bot-heuristic")

        Button("Create Match via POST /matches") {
            Task {
                await sessionStore.connectAndCreateMatch()
            }
        }
        .buttonStyle(.borderedProminent)

        VStack(alignment: .leading, spacing: 8) {
            TextField("Match ID to join", text: $joinMatchID)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
                .autocorrectionDisabled()
                .accessibilityIdentifier("session.join-match-id")

            Button("Join Match") {
                Task {
                    await sessionStore.connectAndJoinMatch(matchId: joinMatchID)
                }
            }
            .disabled(joinMatchID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("session.join-match")
        }

        VStack(alignment: .leading, spacing: 8) {
            TextField("Match ID to watch", text: $watchMatchID)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
                .autocorrectionDisabled()

            Button("Watch Match") {
                Task {
                    await sessionStore.connectAndWatchMatch(matchId: watchMatchID)
                }
            }
            .disabled(watchMatchID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var automationEnabled: Bool {
        ProcessInfo.processInfo.environment["PHALANX_AUTOMATION"] == "true"
    }

    private func matchSummary(_ match: ActiveMatchSummary) -> String {
        let players = match.players.map(\.name).joined(separator: " vs ")
        let phase = match.phaseName ?? "waiting"
        return "\(players.isEmpty ? "No players yet" : players) | phase \(phase) | spectators \(match.spectatorCount)"
    }
}
