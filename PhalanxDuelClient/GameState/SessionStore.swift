import Combine
import SwiftUI

@MainActor
public final class SessionStore: ObservableObject, WebSocketClientDelegate {
    public enum SessionRole: String, Equatable {
        case player
        case spectator
    }

    public struct ServerSnapshot: Codable, Equatable, Sendable {
        public var health: ServerHealthResponse?
        public var defaults: ServerDefaultsResponse?
        public var activeMatches: [ActiveMatchSummary] = []

        public init(
            health: ServerHealthResponse? = nil,
            defaults: ServerDefaultsResponse? = nil,
            activeMatches: [ActiveMatchSummary] = []
        ) {
            self.health = health
            self.defaults = defaults
            self.activeMatches = activeMatches
        }
    }

    private enum PendingConnectionAction: Equatable {
        case join(matchId: String, playerName: String)
        case watch(matchId: String)
    }

    @Published public var localPlayerName: String = "Native SwiftUI Player"
    @Published public var serverBaseURLText: String
    @Published public var documentationBaseURLText: String

    @Published public private(set) var environment: AppEnvironment
    @Published public private(set) var connectionState: WebSocketClient.ConnectionState = .disconnected
    @Published public private(set) var snapshot: ServerSnapshot = ServerSnapshot()
    @Published public private(set) var snapshotLoadState: LoadState<Void> = .idle

    @Published public private(set) var sessionRole: SessionRole?
    @Published public private(set) var currentState: GameState?
    @Published public private(set) var latestTurnResult: PhalanxTurnResult?
    @Published public private(set) var events: [PhalanxEvent] = []
    @Published public var localPlayerId: String?
    @Published public var localPlayerIndex: Int?
    @Published public var activeMatchId: String?
    @Published public private(set) var spectatorCount: Int = 0
    @Published public var recentError: UserFacingError?
    @Published public private(set) var debugLog: [DebugLogEntry] = []
    @Published public private(set) var lastSnapshotRefreshAt: Date?

    @Published public private(set) var bootState: LoadState<Void> = .idle
    @Published public private(set) var bootTasks: [BootTask] = [
        BootTask(id: "env", name: "Initializing Environment"),
        BootTask(id: "health", name: "Probing Server Health"),
        BootTask(id: "defaults", name: "Fetching Game Defaults"),
        BootTask(id: "matches", name: "Finding Active Matches")
    ]

    private var webSocketClient: WebSocketClient
    private var restClient: RestClient
    private var pendingConnectionAction: PendingConnectionAction?

    private let clock: any Clock
    private let uuidGenerator: any UUIDGenerator

    public init(
        environment: AppEnvironment? = nil,
        clock: any Clock = SystemClock(),
        uuidGenerator: any UUIDGenerator = SystemUUIDGenerator()
    ) {
        let environment = environment ?? .current
        self.environment = environment
        self.clock = clock
        self.uuidGenerator = uuidGenerator
        self.serverBaseURLText = environment.apiBaseURL.absoluteString
        self.documentationBaseURLText = environment.documentationBaseURL.absoluteString
        self.webSocketClient = WebSocketClient(environment: environment)
        self.restClient = RestClient(environment: environment)
        self.webSocketClient.delegate = self
        appendLog(
            category: .session,
            title: "Configured \(environment.name)",
            detail: "api=\(environment.apiBaseURL.absoluteString), ws=\(environment.webSocketURL.absoluteString), docs=\(environment.openAPIURL.absoluteString)"
        )
    }

    public var isBooting: Bool {
        bootState.isLoading
    }

    public var isRefreshingSnapshot: Bool {
        snapshotLoadState.isLoading
    }

    public var serverHealth: ServerHealthResponse? { snapshot.health }
    public var serverDefaults: ServerDefaultsResponse? { snapshot.defaults }
    public var activeMatches: [ActiveMatchSummary] { snapshot.activeMatches }

    public var hasActiveSession: Bool {
        activeMatchId != nil || sessionRole != nil || connectionState == .connecting
    }

    public func loadPreset(_ environment: AppEnvironment) {
        applyEnvironment(environment)
    }

    public func applyCustomConfiguration() {
        do {
            let customEnvironment = try AppEnvironment(
                name: "Custom",
                apiBaseURLString: serverBaseURLText,
                documentationBaseURLString: documentationBaseURLText
            )
            applyEnvironment(customEnvironment)
        } catch {
            handle(error, context: "Unable to apply custom configuration")
        }
    }

    public func refreshServerSnapshot() async {
        snapshotLoadState = .loading
        recentError = nil
        appendLog(category: .rest, title: "Refreshing server snapshot", detail: environment.apiBaseURL.absoluteString)

        defer {
            snapshotLoadState = .loaded(())
            lastSnapshotRefreshAt = clock.now
        }

        do {
            snapshot.health = try await restClient.fetchHealth()
            if let health = snapshot.health {
                appendLog(
                    category: .rest,
                    title: "Fetched /health",
                    detail: "status=\(health.status), version=\(health.version), region=\(health.observability.region)"
                )
            }
        } catch {
            handle(error, context: "Failed to fetch /health")
        }

        do {
            snapshot.defaults = try await restClient.fetchDefaults()
            if let defaults = snapshot.defaults {
                appendLog(
                    category: .rest,
                    title: "Fetched /api/defaults",
                    detail: "rows=\(defaults.rows), columns=\(defaults.columns), hand=\(defaults.maxHandSize), LP=\(defaults.startingLifepoints)"
                )
            }
        } catch {
            handle(error, context: "Failed to fetch /api/defaults")
        }

        do {
            snapshot.activeMatches = try await restClient.fetchMatches()
            appendLog(
                category: .rest,
                title: "Fetched /matches",
                detail: "activeMatches=\(snapshot.activeMatches.count)"
            )
        } catch {
            handle(error, context: "Failed to fetch /matches")
        }
    }

    public func runBootSequence() async {
        bootState = .loading
        appendLog(category: .session, title: "Starting Boot Sequence")

        // 1. Initializing Environment (already done in init, but we'll mark it success)
        updateBootTask(id: "env", status: .loading)
        try? await Task.sleep(nanoseconds: 500_000_000) // Visual buffer
        updateBootTask(id: "env", status: .success)

        // 2. Health
        updateBootTask(id: "health", status: .loading)
        do {
            snapshot.health = try await restClient.fetchHealth()
            updateBootTask(id: "health", status: .success)
        } catch {
            updateBootTask(id: "health", status: .failure, error: "Server unreachable")
            handle(error, context: "Boot: /health failed")
        }

        // 3. Defaults
        updateBootTask(id: "defaults", status: .loading)
        do {
            snapshot.defaults = try await restClient.fetchDefaults()
            updateBootTask(id: "defaults", status: .success)
        } catch {
            updateBootTask(id: "defaults", status: .failure, error: "Failed to get config")
            handle(error, context: "Boot: /defaults failed")
        }

        // 4. Matches
        updateBootTask(id: "matches", status: .loading)
        do {
            snapshot.activeMatches = try await restClient.fetchMatches()
            updateBootTask(id: "matches", status: .success)
        } catch {
            updateBootTask(id: "matches", status: .failure, error: "Discovery failed")
            handle(error, context: "Boot: /matches failed")
        }

        try? await Task.sleep(nanoseconds: 800_000_000) // Let user see the completion
        bootState = .loaded(())
        appendLog(category: .session, title: "Boot Sequence Complete")
    }

    private func updateBootTask(id: String, status: BootTaskStatus, error: String? = nil) {
        if let index = bootTasks.firstIndex(where: { $0.id == id }) {
            bootTasks[index].status = status
            bootTasks[index].errorMessage = error
        }
    }

    public func connectAndCreateMatch() async {
        let trimmedName = localPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            recentError = UserFacingError(title: "Required", message: "Player name is required before creating a match.")
            return
        }

        do {
            let matchId = try await restClient.createMatch()
            activeMatchId = matchId
            appendLog(category: .rest, title: "Created pending match", detail: matchId)
            connectForPendingAction(.join(matchId: matchId, playerName: trimmedName))
        } catch {
            handle(error, context: "Create match failed")
        }
    }

    public func connectAndJoinMatch(matchId: String) async {
        let trimmedMatchID = matchId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = localPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedMatchID.isEmpty else {
            recentError = UserFacingError(title: "Required", message: "A match ID is required to join.")
            return
        }

        guard !trimmedName.isEmpty else {
            recentError = UserFacingError(title: "Required", message: "Player name is required before joining a match.")
            return
        }

        connectForPendingAction(.join(matchId: trimmedMatchID, playerName: trimmedName))
    }

    public func connectAndWatchMatch(matchId: String) async {
        let trimmedMatchID = matchId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMatchID.isEmpty else {
            recentError = UserFacingError(title: "Required", message: "A match ID is required to watch.")
            return
        }

        connectForPendingAction(.watch(matchId: trimmedMatchID))
    }

    public func sendPassAction() {
        guard let localPlayerIndex else {
            recentError = UserFacingError(title: "Unavailable", message: "Pass is unavailable until the server assigns a player index.")
            return
        }

        sendAction(.pass(playerIndex: localPlayerIndex))
    }

    public func sendAction(_ action: Action) {
        guard let activeMatchId else {
            recentError = UserFacingError(title: "No Session", message: "No active match is connected.")
            return
        }

        webSocketClient.send(message: .action(matchId: activeMatchId, action: action))
        appendLog(
            category: .websocket,
            title: "Sent action",
            detail: "type=\(action.type.rawValue), matchId=\(activeMatchId)"
        )
    }

    public func disconnect() {
        appendLog(category: .session, title: "Disconnecting session", detail: activeMatchId)
        pendingConnectionAction = nil
        webSocketClient.disconnect()
        resetSessionState(clearMatchID: true)
        recentError = nil
    }

    private func applyEnvironment(_ environment: AppEnvironment) {
        if connectionState != .disconnected {
            webSocketClient.disconnect()
        }

        self.environment = environment
        self.serverBaseURLText = environment.apiBaseURL.absoluteString
        self.documentationBaseURLText = environment.documentationBaseURL.absoluteString
        self.restClient = RestClient(environment: environment)
        self.webSocketClient = WebSocketClient(environment: environment)
        self.webSocketClient.delegate = self
        self.recentError = nil
        resetSessionState(clearMatchID: true)

        appendLog(
            category: .session,
            title: "Applied \(environment.name) configuration",
            detail: "api=\(environment.apiBaseURL.absoluteString), ws=\(environment.webSocketURL.absoluteString), docs=\(environment.openAPIURL.absoluteString)"
        )
    }

    private func connectForPendingAction(_ action: PendingConnectionAction) {
        pendingConnectionAction = action
        resetSessionState(clearMatchID: true)

        switch action {
        case .join(let matchId, _), .watch(let matchId):
            activeMatchId = matchId
        }

        if connectionState != .disconnected {
            webSocketClient.disconnect()
        }

        appendLog(category: .websocket, title: "Opening WebSocket", detail: environment.webSocketURL.absoluteString)
        webSocketClient.connect()
    }

    private func flushPendingActionIfNeeded() {
        guard case .connected = connectionState, let pendingConnectionAction else {
            return
        }

        switch pendingConnectionAction {
        case .join(let matchId, let playerName):
            sessionRole = .player
            activeMatchId = matchId
            webSocketClient.send(message: .joinMatch(matchId: matchId, playerName: playerName))
            appendLog(category: .websocket, title: "Sent joinMatch", detail: "matchId=\(matchId), playerName=\(playerName)")
        case .watch(let matchId):
            sessionRole = .spectator
            activeMatchId = matchId
            webSocketClient.send(message: .watchMatch(matchId: matchId))
            appendLog(category: .websocket, title: "Sent watchMatch", detail: "matchId=\(matchId)")
        }

        self.pendingConnectionAction = nil
    }

    private func resetSessionState(clearMatchID: Bool) {
        currentState = nil
        latestTurnResult = nil
        events.removeAll()
        localPlayerId = nil
        localPlayerIndex = nil
        spectatorCount = 0
        sessionRole = nil
        if clearMatchID {
            activeMatchId = nil
        }
    }

    private func appendLog(category: DebugLogEntry.Category, title: String, detail: String? = nil) {
        debugLog.append(DebugLogEntry(category: category, title: title, detail: detail))
        if debugLog.count > 200 {
            debugLog.removeFirst(debugLog.count - 200)
        }
    }

    private func appendEvents(_ newEvents: [PhalanxEvent]) {
        guard !newEvents.isEmpty else {
            return
        }

        events.append(contentsOf: newEvents)
        if events.count > 300 {
            events.removeFirst(events.count - 300)
        }

        appendLog(
            category: .event,
            title: "Received \(newEvents.count) event(s)",
            detail: newEvents.map(\.name).joined(separator: ", ")
        )
    }

    private func handle(_ error: Error, context: String) {
        recentError = UserFacingError(title: context, message: error.localizedDescription)
        appendLog(category: .error, title: context, detail: error.localizedDescription)
    }

    private func handleServerMessage(_ message: ServerMessage) {
        appendLog(category: .serverMessage, title: "Received \(message.messageType)", detail: message.debugSummary)

        switch message {
        case .matchCreated(let matchId, let playerId, let playerIndex):
            activeMatchId = matchId
            localPlayerId = playerId
            localPlayerIndex = playerIndex
            sessionRole = .player
            recentError = nil

        case .matchJoined(let matchId, let playerId, let playerIndex):
            activeMatchId = matchId
            localPlayerId = playerId
            localPlayerIndex = playerIndex
            sessionRole = .player
            recentError = nil

        case .spectatorJoined(let matchId, _):
            activeMatchId = matchId
            sessionRole = .spectator
            localPlayerId = nil
            localPlayerIndex = nil
            recentError = nil

        case .gameState(let matchId, let result, let spectatorCount):
            activeMatchId = matchId
            latestTurnResult = result
            currentState = result.postState
            self.spectatorCount = spectatorCount ?? 0
            appendEvents(result.events ?? [])
            recentError = nil

        case .actionError(let error, let code), .matchError(let error, let code):
            recentError = UserFacingError(title: "Server Error [\(code)]", message: error)

        case .opponentDisconnected:
            recentError = UserFacingError(title: "Disconnected", message: "Opponent disconnected.")

        case .opponentReconnected:
            recentError = nil

        case .authenticated:
            recentError = nil

        case .authError(let error):
            recentError = UserFacingError(title: "Authentication Error", message: error)

        case .unknown(let type):
            recentError = UserFacingError(title: "Protocol Error", message: "Unknown server message type: \(type)")
        }
    }

    nonisolated public func webSocketClient(_ client: WebSocketClient, didUpdateState state: WebSocketClient.ConnectionState) {
        Task { @MainActor in
            self.connectionState = state
            self.appendLog(category: .websocket, title: "WebSocket state changed", detail: state.label)

            if case .connected = state {
                self.flushPendingActionIfNeeded()
            }
        }
    }

    nonisolated public func webSocketClient(_ client: WebSocketClient, didReceiveMessage message: ServerMessage) {
        Task { @MainActor in
            self.handleServerMessage(message)
        }
    }

    nonisolated public func webSocketClient(_ client: WebSocketClient, didEncounterError error: Error) {
        Task { @MainActor in
            self.handle(error, context: "WebSocket error")
        }
    }
}
