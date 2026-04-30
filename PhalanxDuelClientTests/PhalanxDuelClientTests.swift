import Foundation
@testable import PhalanxDuelClient
import Testing

@Suite("Phalanx Duel Client Contract Tests")
struct PhalanxDuelClientTests {
    @Test("Local proxy preset reflects the live 5173 + 3001 split")
    func localProxyPreset() {
        let environment = AppEnvironment.localProxy

        #expect(environment.apiBaseURL.absoluteString == "http://localhost:5173")
        #expect(environment.webSocketURL.absoluteString == "ws://localhost:5173/ws")
        #expect(environment.openAPIURL.absoluteString == "http://localhost:3001/docs/json")
    }

    @Test("Custom environment derives WebSocket and docs endpoints from API base")
    func customEnvironmentDerivation() throws {
        let environment = try AppEnvironment(
            name: "Custom",
            apiBaseURLString: "http://localhost:4123"
        )

        #expect(environment.apiBaseURL.absoluteString == "http://localhost:4123")
        #expect(environment.webSocketURL.absoluteString == "ws://localhost:4123/ws")
        #expect(environment.openAPIURL.absoluteString == "http://localhost:4123/docs/json")
    }

    @Test("joinMatch encodes the canonical discriminant and payload fields")
    func joinMatchEncoding() throws {
        let payload = ClientMessage.joinMatch(
            matchId: "00000000-0000-0000-0000-000000000001",
            playerName: "Swift Tester",
            msgId: "test-msg-id-123"
        )

        let data = try ContractCoding.makeEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["type"] as? String == "joinMatch")
        #expect(object["matchId"] as? String == "00000000-0000-0000-0000-000000000001")
        #expect(object["playerName"] as? String == "Swift Tester")
        #expect(object["msgId"] as? String == "test-msg-id-123")
    }

    @Test("gameState decodes row-major battlefield state and redacted opponent counts")
    func gameStateDecoding() throws {
        let json = """
        {
          "type": "gameState",
          "matchId": "00000000-0000-0000-0000-000000000010",
          "result": {
            "matchId": "00000000-0000-0000-0000-000000000010",
            "playerId": "00000000-0000-0000-0000-000000000111",
            "preState": {
              "matchId": "00000000-0000-0000-0000-000000000010",
              "specVersion": "1.0",
              "params": {
                "specVersion": "1.0",
                "classic": {
                  "enabled": true,
                  "mode": "strict",
                  "battlefield": { "rows": 2, "columns": 4 },
                  "hand": { "maxHandSize": 4 },
                  "start": { "initialDraw": 12 },
                  "modes": {
                    "classicAces": true,
                    "classicFaceCards": true,
                    "damagePersistence": "classic"
                  },
                  "initiative": { "deployFirst": "P2", "attackFirst": "P1" },
                  "passRules": { "maxConsecutivePasses": 3, "maxTotalPassesPerPlayer": 5 }
                },
                "rows": 2,
                "columns": 4,
                "maxHandSize": 4,
                "initialDraw": 12,
                "modeClassicAces": true,
                "modeClassicFaceCards": true,
                "modeDamagePersistence": "classic",
                "modeClassicDeployment": true,
                "modeSpecialStart": { "enabled": false },
                "initiative": { "deployFirst": "P2", "attackFirst": "P1" },
                "modePassRules": { "maxConsecutivePasses": 3, "maxTotalPassesPerPlayer": 5 }
              },
              "players": [
                {
                  "player": { "id": "00000000-0000-0000-0000-000000000111", "name": "Alice" },
                  "hand": [
                    { "id": "card-1", "suit": "spades", "face": "A", "value": 1, "type": "ace" }
                  ],
                  "battlefield": [
                    null,
                    null,
                    null,
                    null,
                    {
                      "card": { "id": "card-2", "suit": "clubs", "face": "7", "value": 7, "type": "number" },
                      "position": { "row": 1, "col": 0 },
                      "currentHp": 7,
                      "faceDown": false
                    },
                    null,
                    null,
                    null
                  ],
                  "drawpile": [],
                  "discardPile": [],
                  "lifepoints": 20,
                  "deckSeed": 42
                },
                {
                  "player": { "id": "00000000-0000-0000-0000-000000000222", "name": "Bob" },
                  "hand": [],
                  "battlefield": [null, null, null, null, null, null, null, null],
                  "drawpile": [],
                  "discardPile": [],
                  "lifepoints": 20,
                  "deckSeed": 99,
                  "handCount": 12,
                  "drawpileCount": 28
                }
              ],
              "activePlayerIndex": 0,
              "phase": "DeploymentPhase",
              "turnNumber": 0,
              "transactionLog": []
            },
            "postState": {
              "matchId": "00000000-0000-0000-0000-000000000010",
              "specVersion": "1.0",
              "params": {
                "specVersion": "1.0",
                "classic": {
                  "enabled": true,
                  "mode": "strict",
                  "battlefield": { "rows": 2, "columns": 4 },
                  "hand": { "maxHandSize": 4 },
                  "start": { "initialDraw": 12 },
                  "modes": {
                    "classicAces": true,
                    "classicFaceCards": true,
                    "damagePersistence": "classic"
                  },
                  "initiative": { "deployFirst": "P2", "attackFirst": "P1" },
                  "passRules": { "maxConsecutivePasses": 3, "maxTotalPassesPerPlayer": 5 }
                },
                "rows": 2,
                "columns": 4,
                "maxHandSize": 4,
                "initialDraw": 12,
                "modeClassicAces": true,
                "modeClassicFaceCards": true,
                "modeDamagePersistence": "classic",
                "modeClassicDeployment": true,
                "modeSpecialStart": { "enabled": false },
                "initiative": { "deployFirst": "P2", "attackFirst": "P1" },
                "modePassRules": { "maxConsecutivePasses": 3, "maxTotalPassesPerPlayer": 5 }
              },
              "players": [
                {
                  "player": { "id": "00000000-0000-0000-0000-000000000111", "name": "Alice" },
                  "hand": [
                    { "id": "card-1", "suit": "spades", "face": "A", "value": 1, "type": "ace" }
                  ],
                  "battlefield": [
                    null,
                    {
                      "card": { "id": "card-3", "suit": "hearts", "face": "5", "value": 5, "type": "number" },
                      "position": { "row": 0, "col": 1 },
                      "currentHp": 5,
                      "faceDown": false
                    },
                    null,
                    null,
                    {
                      "card": { "id": "card-2", "suit": "clubs", "face": "7", "value": 7, "type": "number" },
                      "position": { "row": 1, "col": 0 },
                      "currentHp": 7,
                      "faceDown": false
                    },
                    null,
                    null,
                    null
                  ],
                  "drawpile": [],
                  "discardPile": [],
                  "lifepoints": 20,
                  "deckSeed": 42
                },
                {
                  "player": { "id": "00000000-0000-0000-0000-000000000222", "name": "Bob" },
                  "hand": [],
                  "battlefield": [null, null, null, null, null, null, null, null],
                  "drawpile": [],
                  "discardPile": [],
                  "lifepoints": 20,
                  "deckSeed": 99,
                  "handCount": 11,
                  "drawpileCount": 28
                }
              ],
              "activePlayerIndex": 0,
              "phase": "DeploymentPhase",
              "turnNumber": 1,
              "transactionLog": [
                {
                  "sequenceNumber": 1,
                  "action": {
                    "type": "deploy",
                    "playerIndex": 0,
                    "column": 1,
                    "cardId": "card-3",
                    "timestamp": "2026-03-16T13:59:10.192Z"
                  },
                  "stateHashBefore": "before",
                  "stateHashAfter": "after",
                  "timestamp": "2026-03-16T13:59:10.192Z",
                  "turnHash": "turn-hash"
                }
              ]
            },
            "action": {
              "type": "deploy",
              "playerIndex": 0,
              "column": 1,
              "cardId": "card-3",
              "timestamp": "2026-03-16T13:59:10.192Z"
            },
            "events": [
              {
                "id": "00000000-0000-0000-0000-000000000010:turn:1:event:1",
                "type": "functional_update",
                "name": "card.deployed",
                "timestamp": "2026-03-16T13:59:10.192Z",
                "payload": { "gridIndex": 1, "phaseAfter": "DeploymentPhase" },
                "status": "ok"
              }
            ],
            "turnHash": "turn-hash"
          },
          "spectatorCount": 1
        }
        """

        let message = try ContractCoding.makeDecoder().decode(ServerMessage.self, from: Data(json.utf8))

        guard case let .gameState(matchID, result, spectatorCount) = message else {
            Issue.record("Expected a gameState message")
            return
        }

        #expect(matchID == "00000000-0000-0000-0000-000000000010")
        #expect(spectatorCount == 1)
        #expect(result.postState.rows == 2)
        #expect(result.postState.columns == 4)
        #expect(result.postState.phase == .turnPhase(.DeploymentPhase))
        #expect(result.postState.players[1].visibleHandCount == 11)
        #expect(result.postState.battlefieldCard(playerIndex: 0, row: 0, column: 1)?.card.face == "5")
        #expect(result.events?.first?.name == "card.deployed")
    }
}
