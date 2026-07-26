import Foundation
import XCTest

/// Runs Apple's XCTest accessibility audit (the same engine Accessibility
/// Inspector's "Audit" tab uses) against a live, populated game screen.
/// macOS supports four audit categories: contrast, element detection, hit
/// region size, and sufficient element description (VoiceOver labels).
/// Dynamic Type / text-clipping / trait audits only exist on iOS-family
/// platforms — they are not something this API can check on macOS, so
/// Dynamic Type support has to be reviewed by hand instead.
final class AccessibilityAuditTests: XCTestCase {
    /// Mirrors AutomationTests.ProofConfiguration: the shared scheme only
    /// forwards `PHALANX_QA_CONFIG_PATH` into the test process (via the
    /// `$(PHALANX_QA_CONFIG_FILE)` build-setting macro), so parameters must
    /// travel through this JSON file rather than as ad hoc env vars.
    private struct AuditConfiguration: Decodable {
        let baseURL: String
        let webSocketURL: String
        let runDirectory: String
        let seed: Int
    }

    private struct AuditIssueRecord: Codable {
        let auditType: String
        let compactDescription: String
        let detailedDescription: String
        let elementDescription: String?
    }

    private struct AuditReport: Codable {
        let tool: String
        let startedAt: String
        let endedAt: String
        let matchId: String?
        let issueCount: Int
        let issues: [AuditIssueRecord]
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testGameplayAccessibilityAudit() throws {
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
        let runDirectory = URL(
            fileURLWithPath: configuration?.runDirectory
                ?? processEnvironment["PHALANX_QA_RUN_DIR"]
                ?? "\(NSTemporaryDirectory())phalanx-swiftui-accessibility-audit"
        )
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        let startedAt = Date()

        let app = XCUIApplication()
        app.launchEnvironment["PHALANX_CLIENT_BASE_URL"] = baseURL
        app.launchEnvironment["PHALANX_CLIENT_WS_URL"] = webSocketURL
        app.launchEnvironment["PHALANX_CLIENT_DOCS_BASE_URL"] = baseURL
        app.launchEnvironment["PHALANX_MATCH_RNG_SEED"] = String(seed)
        app.launchEnvironment["PHALANX_MATCH_STARTING_LIFEPOINTS"] = "20"
        app.launchEnvironment["PHALANX_MATCH_DAMAGE_MODE"] = "cumulative"
        app.launchEnvironment["PHALANX_AUTOMATION"] = "true"
        app.launchEnvironment["PHALANX_PLAYER_NAME"] = "Accessibility Audit"
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.activate()

        var matchId: String?

        // Reach a populated mid-match state: boot panel audited as-is, then
        // create a bot match and drive one deploy + one attack so cards,
        // the hidden opponent hand, HP bars, the narration ticker, and the
        // engagement log all have real content to audit (empty states would
        // hide most of the surface this exists to check).
        _ = app.descendants(matching: .any)["automation.launch-panel"]
            .waitForExistence(timeout: 20)
        let botButton = app.descendants(matching: .any)["session.create-bot-random"]
        if botButton.waitForExistence(timeout: 20), botButton.isHittable {
            botButton.tap()
        }
        _ = app.descendants(matching: .any)["automation.match-id"]
            .waitForExistence(timeout: 30)
        matchId = app.descendants(matching: .any)["automation.match-id"].value as? String

        driveOneDeployAndOneAttack(in: app)

        // Give the transient CombatOverlayView flash time to clear so the
        // audit reflects steady-state UI rather than a mid-animation frame.
        Thread.sleep(forTimeInterval: 2.5)

        var records: [AuditIssueRecord] = []
        try? app.performAccessibilityAudit { issue in
            records.append(
                AuditIssueRecord(
                    auditType: String(describing: issue.auditType),
                    compactDescription: issue.compactDescription,
                    detailedDescription: issue.detailedDescription,
                    elementDescription: issue.element?.debugDescription
                )
            )
            return true
        }

        let screenshot = app.windows.firstMatch.exists
            ? app.windows.firstMatch.screenshot()
            : XCUIScreen.main.screenshot()
        let screenshotAttachment = XCTAttachment(screenshot: screenshot)
        screenshotAttachment.name = "audited-screen"
        screenshotAttachment.lifetime = .keepAlways
        add(screenshotAttachment)
        try? screenshot.pngRepresentation.write(
            to: runDirectory.appendingPathComponent("audited-screen.png")
        )

        let report = AuditReport(
            tool: "swiftui-accessibility-audit",
            startedAt: isoTimestamp(startedAt),
            endedAt: isoTimestamp(Date()),
            matchId: matchId,
            issueCount: records.count,
            issues: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let reportAttachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        reportAttachment.name = "accessibility-audit.json"
        reportAttachment.lifetime = .keepAlways
        add(reportAttachment)
        try? data.write(to: runDirectory.appendingPathComponent("accessibility-audit.json"))
    }

    /// Minimal board driver, distinct from AutomationTests' full-match
    /// driver: this only needs one deploy and one attack to populate the
    /// screen, not a complete authoritative match.
    private func driveOneDeployAndOneAttack(in app: XCUIApplication) {
        guard let localIndexText = app.descendants(matching: .any)["automation.local-player-index"]
            .waitForExistence(timeout: 30)
            ? (app.descendants(matching: .any)["automation.local-player-index"].value as? String)
            : nil,
            let localPlayerIndex = Int(localIndexText) else {
            return
        }

        for _ in 0 ..< 12 {
            if element(app, "game.game-over").exists { return }
            let turnOwner = app.descendants(matching: .any)["automation.turn-owner"].value as? String
            guard turnOwner == "local" else {
                Thread.sleep(forTimeInterval: 0.2)
                continue
            }

            if let card = firstHittable(
                app,
                "identifier BEGINSWITH %@ AND value == %@",
                "game.hand-card.\(localPlayerIndex).", "deploy"
            ) {
                card.tap()
                Thread.sleep(forTimeInterval: 0.2)
                if let slot = firstHittable(
                    app,
                    "identifier BEGINSWITH %@ AND value == %@",
                    "game.slot.\(localPlayerIndex).", "deploy-target"
                ) {
                    slot.tap()
                    Thread.sleep(forTimeInterval: 0.3)
                    continue
                }
            }

            let opponentIndex = localPlayerIndex == 0 ? 1 : 0
            if let attacker = firstHittable(
                app,
                "identifier BEGINSWITH %@ AND value == %@",
                "game.slot.\(localPlayerIndex).", "attacker"
            ) {
                attacker.tap()
                Thread.sleep(forTimeInterval: 0.2)
                if let target = firstHittable(
                    app,
                    "identifier BEGINSWITH %@ AND value == %@",
                    "game.slot.\(opponentIndex).", "attack-target"
                ) {
                    target.tap()
                    Thread.sleep(forTimeInterval: 0.3)
                    return
                }
            }

            let passButton = app.descendants(matching: .any)["game.pass"]
            if passButton.exists, passButton.isHittable {
                passButton.tap()
                Thread.sleep(forTimeInterval: 0.3)
            } else {
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
    }

    private func loadConfiguration(
        from environment: [String: String]
    ) throws -> AuditConfiguration? {
        guard let path = environment["PHALANX_QA_CONFIG_PATH"],
              !path.isEmpty,
              !path.contains("$(") else {
            return nil
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(AuditConfiguration.self, from: data)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func firstHittable(
        _ app: XCUIApplication,
        _ format: String,
        _ arg1: String,
        _ arg2: String
    ) -> XCUIElement? {
        let predicate = NSPredicate(format: format, arg1, arg2)
        return app.descendants(matching: .any)
            .matching(predicate)
            .allElementsBoundByIndex
            .first { $0.exists && $0.isHittable && $0.isEnabled }
    }

    private func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
