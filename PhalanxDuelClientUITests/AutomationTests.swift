import Foundation
import XCTest

final class AutomationTests: XCTestCase {
    private struct ProofConfiguration: Decodable {
        let baseURL: String
        let webSocketURL: String
        let runDirectory: String
        let seed: Int
        let startingLifepoints: Int
        let timeoutSeconds: Int
        let botStrategy: String
        let headsUp: Bool
        let actionDelayMilliseconds: Int
        let finalHoldSeconds: Int
    }

    private struct PlayerEvidence: Codable {
        let index: Int
        let name: String
        let finalLifepoints: Int
    }

    private struct RunManifest: Codable {
        let tool: String
        let status: String
        let failureReason: String?
        let failureMessage: String?
        let startedAt: String
        let endedAt: String
        let durationMs: Int
        let baseURL: String
        let matchId: String?
        let seed: Int
        let startingLifepoints: Int
        let botStrategy: String
        let players: [PlayerEvidence]
        let winnerIndex: Int?
        let winnerName: String?
        let victoryType: String?
        let turnCount: Int
        let actionCount: Int
        let nativeActionCount: Int
        let performedDeployment: Bool
        let performedAttack: Bool
        let screenshots: [String]
        let debugLog: String
        let uiHierarchy: String?
    }

    private enum ProofError: LocalizedError {
        case missingElement(String)
        case noLegalAction(String)
        case stalled(String)
        case timedOut(Int)
        case invalidEvidence(String)

        var errorDescription: String? {
            switch self {
            case let .missingElement(identifier):
                "Required UI element did not appear: \(identifier)"
            case let .noLegalAction(phase):
                "No user-visible legal action was available during \(phase)"
            case let .stalled(detail):
                "Native gameplay stalled: \(detail)"
            case let .timedOut(seconds):
                "Native gameplay did not reach game over within \(seconds) seconds"
            case let .invalidEvidence(detail):
                "Terminal evidence is incomplete: \(detail)"
            }
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCompleteBotMatch() throws {
        let processEnvironment = ProcessInfo.processInfo.environment
        let configuration = try loadConfiguration(from: processEnvironment)
        let baseURL = configuration?.baseURL
            ?? processEnvironment["PHALANX_CLIENT_BASE_URL"]
            ?? "http://127.0.0.1:3101"
        let webSocketURL = configuration?.webSocketURL
            ?? processEnvironment["PHALANX_CLIENT_WS_URL"]
            ?? "ws://127.0.0.1:3101/ws"
        let seed = configuration?.seed
            ?? Int(processEnvironment["PHALANX_MATCH_RNG_SEED"] ?? "")
            ?? 2_026_072_401
        let startingLifepoints = configuration?.startingLifepoints
            ?? Int(processEnvironment["PHALANX_MATCH_STARTING_LIFEPOINTS"] ?? "")
            ?? 20
        let timeoutSeconds = configuration?.timeoutSeconds
            ?? Int(processEnvironment["PHALANX_QA_TIMEOUT_SECONDS"] ?? "")
            ?? 300
        let botStrategy = configuration?.botStrategy
            ?? processEnvironment["PHALANX_BOT_STRATEGY"]
            ?? "bot-random"
        let headsUp = configuration?.headsUp
            ?? (processEnvironment["PHALANX_QA_HEADS_UP"] == "true")
        let actionDelayMilliseconds = Int(
            processEnvironment["PHALANX_QA_ACTION_DELAY_MS"] ?? ""
        ) ?? configuration?.actionDelayMilliseconds ?? (headsUp ? 650 : 0)
        let finalHoldSeconds = Int(
            processEnvironment["PHALANX_QA_FINAL_HOLD_SECONDS"] ?? ""
        ) ?? configuration?.finalHoldSeconds ?? (headsUp ? 5 : 0)
        let runDirectory = URL(
            fileURLWithPath: configuration?.runDirectory
                ?? processEnvironment["PHALANX_QA_RUN_DIR"]
                ?? "\(NSTemporaryDirectory())phalanx-swiftui-proof"
        )
        let debugLogPath = runDirectory.appendingPathComponent("native-debug.log").path
        let hierarchyPath = runDirectory.appendingPathComponent("ui-hierarchy.txt").path
        let startedAt = Date()

        try FileManager.default.createDirectory(
            at: runDirectory,
            withIntermediateDirectories: true
        )

        let app = XCUIApplication()
        app.launchEnvironment["PHALANX_CLIENT_BASE_URL"] = baseURL
        app.launchEnvironment["PHALANX_CLIENT_WS_URL"] = webSocketURL
        app.launchEnvironment["PHALANX_CLIENT_DOCS_BASE_URL"] = baseURL
        app.launchEnvironment["PHALANX_MATCH_RNG_SEED"] = String(seed)
        app.launchEnvironment["PHALANX_MATCH_STARTING_LIFEPOINTS"] = String(startingLifepoints)
        app.launchEnvironment["PHALANX_MATCH_DAMAGE_MODE"] = "cumulative"
        app.launchEnvironment["PHALANX_AUTOMATION"] = "true"
        app.launchEnvironment["PHALANX_PLAYER_NAME"] = "SwiftUI Thomas"
        app.launchEnvironment["PHALANX_DEBUG_LOG_PATH"] = debugLogPath
        app.launchEnvironment["PHALANX_VERBOSE_LOGGING"] = "true"
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-NSQuitAlwaysKeepsWindows", "NO",
        ]
        app.launch()
        app.activate()

        var screenshotPaths: [String] = []
        var matchId: String?
        var nativeActionCount = 0
        var performedDeployment = false
        var performedAttack = false

        do {
            try ensureApplicationWindow(in: app)
            _ = try requireElement(
                in: app,
                identifier: "automation.launch-panel",
                timeout: 20
            )
            let nameField = try waitForHittableElement(
                in: app,
                predicate: NSPredicate(
                    format: "identifier == %@",
                    "session.player-name"
                ),
                timeout: 20
            )
            guard (nameField.value as? String) == "SwiftUI Thomas" else {
                throw ProofError.invalidEvidence(
                    "automation player-name hook did not initialize the visible field"
                )
            }
            watchPause(milliseconds: actionDelayMilliseconds)

            let botButton = try waitForHittableElement(
                in: app,
                predicate: NSPredicate(
                    format: "identifier == %@",
                    botStrategy == "bot-heuristic"
                        ? "session.create-bot-heuristic"
                        : "session.create-bot-random"
                ),
                timeout: 20
            )
            botButton.tap()
            watchPause(milliseconds: actionDelayMilliseconds)

            _ = try requireElement(in: app, identifier: "automation.phase", timeout: 30)
            _ = try requireElement(
                in: app,
                identifier: "automation.local-player-index",
                timeout: 30
            )
            matchId = try textValue(
                in: app,
                identifier: "automation.match-id",
                timeout: 30
            )

            try captureScreenshot(
                name: "01-start",
                app: app,
                runDirectory: runDirectory,
                paths: &screenshotPaths
            )

            let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
            var lastProgress = stateSignature(in: app)
            var lastProgressAt = Date()

            while Date() < deadline {
                if element(in: app, identifier: "game.game-over").exists {
                    break
                }

                let phase = try textValue(
                    in: app,
                    identifier: "automation.phase",
                    timeout: 10
                )
                let turnOwner = try textValue(
                    in: app,
                    identifier: "automation.turn-owner",
                    timeout: 10
                )

                if turnOwner != "local" {
                    Thread.sleep(forTimeInterval: 0.15)
                    let signature = stateSignature(in: app)
                    if signature != lastProgress {
                        lastProgress = signature
                        lastProgressAt = Date()
                    } else if Date().timeIntervalSince(lastProgressAt) > 20 {
                        throw ProofError.stalled("opponent turn, state \(signature)")
                    }
                    continue
                }

                let beforeAction = stateSignature(in: app)
                let actionButton = try waitForHittableElement(
                    in: app,
                    predicate: NSPredicate(
                        format: "identifier == %@",
                        "automation.perform-next-action"
                    ),
                    timeout: 20
                )
                let actionType = (actionButton.value as? String) ?? ""
                guard ["deploy", "attack", "pass", "reinforce"].contains(actionType) else {
                    throw ProofError.invalidEvidence(
                        "automation hook exposed an unknown action '\(actionType)' during \(phase)"
                    )
                }
                actionButton.tap()
                nativeActionCount += 1
                performedDeployment = performedDeployment || actionType == "deploy"
                performedAttack = performedAttack || actionType == "attack"

                try waitForProgress(in: app, previous: beforeAction, timeout: 15)
                watchPause(milliseconds: actionDelayMilliseconds)
                if actionType == "deploy",
                   !screenshotPaths.contains("screenshots/02-first-deployment.png") {
                    try captureScreenshot(
                        name: "02-first-deployment",
                        app: app,
                        runDirectory: runDirectory,
                        paths: &screenshotPaths
                    )
                }
                if actionType == "attack",
                   !screenshotPaths.contains("screenshots/03-first-attack.png") {
                    try captureScreenshot(
                        name: "03-first-attack",
                        app: app,
                        runDirectory: runDirectory,
                        paths: &screenshotPaths
                    )
                }
                lastProgress = stateSignature(in: app)
                lastProgressAt = Date()
            }

            guard element(in: app, identifier: "game.game-over").waitForExistence(timeout: 5) else {
                throw ProofError.timedOut(timeoutSeconds)
            }

            scrollToTop(in: app)
            try captureScreenshot(
                name: "04-game-over",
                app: app,
                runDirectory: runDirectory,
                paths: &screenshotPaths
            )

            let player0 = try playerEvidence(in: app, index: 0)
            let player1 = try playerEvidence(in: app, index: 1)
            let winnerName = try textValue(in: app, identifier: "game.winner-name", timeout: 10)
            let victoryType = try textValue(in: app, identifier: "game.victory-type", timeout: 10)
            let turnCount = try integerValue(in: app, identifier: "game.final-turn")
            let actionCount = try integerValue(in: app, identifier: "game.action-count")
            let winnerIndex = [player0, player1].first(where: { $0.name == winnerName })?.index
            if finalHoldSeconds > 0 {
                Thread.sleep(forTimeInterval: TimeInterval(finalHoldSeconds))
            }

            guard performedDeployment else {
                throw ProofError.invalidEvidence("no deployment action was driven through the native UI")
            }
            guard performedAttack else {
                throw ProofError.invalidEvidence("no attack action was driven through the native UI")
            }
            guard let winnerIndex else {
                throw ProofError.invalidEvidence("winner \(winnerName) does not match either rendered player")
            }
            guard actionCount >= nativeActionCount, turnCount > 0 else {
                throw ProofError.invalidEvidence(
                    "turn/action counts are inconsistent (turns=\(turnCount), authoritativeActions=\(actionCount), nativeActions=\(nativeActionCount))"
                )
            }

            let manifest = RunManifest(
                tool: "swiftui-xcuitest-bot-playthrough",
                status: "success",
                failureReason: nil,
                failureMessage: nil,
                startedAt: isoTimestamp(startedAt),
                endedAt: isoTimestamp(Date()),
                durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
                baseURL: baseURL,
                matchId: matchId,
                seed: seed,
                startingLifepoints: startingLifepoints,
                botStrategy: botStrategy,
                players: [player0, player1],
                winnerIndex: winnerIndex,
                winnerName: winnerName,
                victoryType: victoryType,
                turnCount: turnCount,
                actionCount: actionCount,
                nativeActionCount: nativeActionCount,
                performedDeployment: performedDeployment,
                performedAttack: performedAttack,
                screenshots: screenshotPaths,
                debugLog: "native-debug.log",
                uiHierarchy: nil
            )
            try writeManifest(manifest, to: runDirectory)
        } catch {
            try? captureScreenshot(
                name: "failure-final",
                app: app,
                runDirectory: runDirectory,
                paths: &screenshotPaths
            )
            let hierarchy = app.debugDescription
            let hierarchyAttachment = XCTAttachment(string: hierarchy)
            hierarchyAttachment.name = "ui-hierarchy.txt"
            hierarchyAttachment.lifetime = .keepAlways
            add(hierarchyAttachment)
            try? hierarchy.write(
                toFile: hierarchyPath,
                atomically: true,
                encoding: .utf8
            )

            let manifest = RunManifest(
                tool: "swiftui-xcuitest-bot-playthrough",
                status: "failure",
                failureReason: String(describing: type(of: error)),
                failureMessage: error.localizedDescription,
                startedAt: isoTimestamp(startedAt),
                endedAt: isoTimestamp(Date()),
                durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
                baseURL: baseURL,
                matchId: matchId,
                seed: seed,
                startingLifepoints: startingLifepoints,
                botStrategy: botStrategy,
                players: [],
                winnerIndex: nil,
                winnerName: nil,
                victoryType: nil,
                turnCount: 0,
                actionCount: 0,
                nativeActionCount: nativeActionCount,
                performedDeployment: performedDeployment,
                performedAttack: performedAttack,
                screenshots: screenshotPaths,
                debugLog: "native-debug.log",
                uiHierarchy: "ui-hierarchy.txt"
            )
            try? writeManifest(manifest, to: runDirectory)
            XCTFail(error.localizedDescription)
        }
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func loadConfiguration(
        from environment: [String: String]
    ) throws -> ProofConfiguration? {
        guard let path = environment["PHALANX_QA_CONFIG_PATH"],
              !path.isEmpty,
              !path.contains("$(") else {
            return nil
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(ProofConfiguration.self, from: data)
    }

    private func ensureApplicationWindow(in app: XCUIApplication) throws {
        if app.windows.firstMatch.waitForExistence(timeout: 5) {
            return
        }

        app.activate()
        app.typeKey("n", modifierFlags: .command)
        guard app.windows.firstMatch.waitForExistence(timeout: 10) else {
            throw ProofError.missingElement("application window (File > New Window)")
        }
    }

    private func requireElement(
        in app: XCUIApplication,
        identifier: String,
        timeout: TimeInterval
    ) throws -> XCUIElement {
        let candidate = element(in: app, identifier: identifier)
        guard candidate.waitForExistence(timeout: timeout) else {
            throw ProofError.missingElement(identifier)
        }
        return candidate
    }

    private func requireHittableElement(
        in app: XCUIApplication,
        identifier: String
    ) throws -> XCUIElement {
        try findHittableElement(
            in: app,
            predicate: NSPredicate(format: "identifier == %@", identifier)
        )
    }

    private func waitForHittableElement(
        in app: XCUIApplication,
        predicate: NSPredicate,
        timeout: TimeInterval
    ) throws -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let matches = app.descendants(matching: .any)
                .matching(predicate)
                .allElementsBoundByIndex
            if let match = matches.first(where: { $0.exists && $0.isHittable && $0.isEnabled }) {
                return match
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        throw ProofError.missingElement("hittable element matching \(predicate.predicateFormat)")
    }

    private func findHittableElement(
        in app: XCUIApplication,
        predicate: NSPredicate,
        swipeLimit: Int = 14
    ) throws -> XCUIElement {
        let initialMatch = app.descendants(matching: .any)
            .matching(predicate)
            .firstMatch
        _ = initialMatch.waitForExistence(timeout: 10)

        for _ in 0 ... swipeLimit {
            let matches = app.descendants(matching: .any)
                .matching(predicate)
                .allElementsBoundByIndex
            if let match = matches.first(where: { $0.exists && $0.isHittable && $0.isEnabled }) {
                return match
            }
            try scroll(in: app, direction: .up)
            Thread.sleep(forTimeInterval: 0.08)
        }

        for _ in 0 ... swipeLimit {
            let matches = app.descendants(matching: .any)
                .matching(predicate)
                .allElementsBoundByIndex
            if let match = matches.first(where: { $0.exists && $0.isHittable && $0.isEnabled }) {
                return match
            }
            try scroll(in: app, direction: .down)
            Thread.sleep(forTimeInterval: 0.08)
        }

        throw ProofError.noLegalAction(predicate.predicateFormat)
    }

    private func replaceText(in field: XCUIElement, with value: String) {
        field.tap()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(value)
    }

    private func textValue(
        in app: XCUIApplication,
        identifier: String,
        timeout: TimeInterval
    ) throws -> String {
        let candidate = try requireElement(in: app, identifier: identifier, timeout: timeout)
        if let value = candidate.value as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let label = candidate.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            throw ProofError.invalidEvidence("\(identifier) has no readable value")
        }
        return label
    }

    private func integerValue(in app: XCUIApplication, identifier: String) throws -> Int {
        let value = try textValue(in: app, identifier: identifier, timeout: 10)
        guard let integer = Int(value) else {
            throw ProofError.invalidEvidence("\(identifier) is not an integer: \(value)")
        }
        return integer
    }

    private func playerEvidence(in app: XCUIApplication, index: Int) throws -> PlayerEvidence {
        PlayerEvidence(
            index: index,
            name: try textValue(in: app, identifier: "game.player.\(index).name", timeout: 10),
            finalLifepoints: try integerValue(
                in: app,
                identifier: "game.player.\(index).lifepoints"
            )
        )
    }

    private func stateSignature(in app: XCUIApplication) -> String {
        if element(in: app, identifier: "game.game-over").exists {
            return "gameOver"
        }
        let phase = try? textValue(in: app, identifier: "automation.phase", timeout: 0.2)
        let turn = try? textValue(
            in: app,
            identifier: "automation.turn-number",
            timeout: 0.2
        )
        let actions = try? textValue(
            in: app,
            identifier: "automation.action-count",
            timeout: 0.2
        )
        let owner = try? textValue(
            in: app,
            identifier: "automation.turn-owner",
            timeout: 0.2
        )
        return "\(phase ?? "?")|\(turn ?? "?")|\(actions ?? "?")|\(owner ?? "?")"
    }

    private func waitForProgress(
        in app: XCUIApplication,
        previous: String,
        timeout: TimeInterval
    ) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element(in: app, identifier: "game.game-over").exists {
                return
            }
            if stateSignature(in: app) != previous {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw ProofError.stalled("state remained \(previous) after a submitted action")
    }

    private func scrollToTop(in app: XCUIApplication) {
        for _ in 0 ..< 16 {
            try? scroll(in: app, direction: .down)
        }
    }

    private enum ScrollDirection {
        case up
        case down
    }

    private func scroll(in app: XCUIApplication, direction: ScrollDirection) throws {
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.exists, scrollView.isHittable else {
            throw ProofError.missingElement("hittable gameplay scroll view")
        }

        switch direction {
        case .up:
            scrollView.swipeUp()
        case .down:
            scrollView.swipeDown()
        }
    }

    private func captureScreenshot(
        name: String,
        app: XCUIApplication,
        runDirectory: URL,
        paths: inout [String]
    ) throws {
        let screenshotsDirectory = runDirectory.appendingPathComponent("screenshots")
        try? FileManager.default.createDirectory(
            at: screenshotsDirectory,
            withIntermediateDirectories: true
        )
        let screenshot = app.windows.firstMatch.exists
            ? app.windows.firstMatch.screenshot()
            : XCUIScreen.main.screenshot()
        let relativePath = "screenshots/\(name).png"
        paths.append(relativePath)

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        try? screenshot.pngRepresentation.write(
            to: runDirectory.appendingPathComponent(relativePath)
        )
    }

    private func writeManifest(_ manifest: RunManifest, to runDirectory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "manifest.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        try? data.write(to: runDirectory.appendingPathComponent("manifest.json"))
    }

    private func watchPause(milliseconds: Int) {
        guard milliseconds > 0 else { return }
        Thread.sleep(forTimeInterval: Double(milliseconds) / 1_000)
    }

    private func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
