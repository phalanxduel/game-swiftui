# Client Architecture

## Goal

Build a clean native SwiftUI client that validates and consumes the official Phalanx Duel server contract without copying upstream implementation logic or reimplementing match rules locally.

## Thin-Client Principles

1. `../game` is authoritative for rules, runtime behavior, transport shapes, and terminology.
2. This repository only renders authoritative state and sends player intent.
3. No local gameplay resolution, replay logic, or combat calculation belongs in the Swift client.
4. Any contract ambiguity is documented and escalated upstream instead of hidden in client code.
5. Local derived UI state must stay clearly separate from authoritative server state.

## Isolation Boundary

### Upstream responsibilities

- Rule evaluation
- Match initialization
- Turn sequencing
- State filtering for players vs spectators
- Event generation
- Replay verification
- Canonical schemas and protocol evolution

### SwiftUI client responsibilities

- Server configuration
- REST bootstrap/discovery calls
- WebSocket connection lifecycle
- Contract decoding into Swift models
- Observable session state for SwiftUI
- Human-readable rendering of server/game/session state
- Debug logging for integration validation

## Local Layering

| Layer | Responsibility |
| --- | --- |
| `App/` | App entry point and top-level dependency wiring |
| `UI/` | SwiftUI views only; no network transport logic or rules logic |
| `Domain/` | `Codable` contract models using upstream terminology |
| `Networking/` | REST client, WebSocket transport, and server configuration |
| `GameState/` | Observable session controller/store that owns connection and authoritative state flow |
| `Debug/` | Lightweight in-memory diagnostic/event log surfaces |

## Authoritative State Model

The client should treat these as distinct:

- Server configuration and endpoint discovery
- Session identity
  - `matchId`
  - player/spectator role
  - `playerId`
  - `playerIndex`
- Latest authoritative `gameState.result.postState`
- Recent authoritative `PhalanxEvent`s
- Transport/debug metadata

Important rule:

- Render from `postState`.
- Do not build UI features that depend on `preState` semantics until upstream clarifies/fixes that payload.

## Transport Strategy

The client configuration must allow the REST, WebSocket, and documentation bases to differ. In local development, the upstream Vite app proxies gameplay traffic through `http://localhost:5173`, while `/docs/json` remains available only from `http://localhost:3001`.

### REST

Used for bootstrap and out-of-band discovery:

- `GET /health`
- `GET /api/defaults`
- `GET /matches`
- `POST /matches`
- Future candidates: `GET /matches/completed`, `GET /matches/:id/log`

### WebSocket

Used for session and live state:

- Connect to `/ws`
- Send `joinMatch` or `watchMatch` after connection opens
- Receive `matchCreated`, `matchJoined`, `spectatorJoined`, `gameState`, and error/status messages

## State Flow Into SwiftUI

1. `ServerConfiguration` derives REST and WS endpoints from an authoritative base URL.
2. `SessionStore` performs REST discovery and records the resulting server snapshot.
3. `SessionStore` opens `WebSocketClient` and sends the pending session intent.
4. Incoming `ServerMessage`s are decoded into domain models.
5. `SessionStore` publishes:
   - connection state
   - current session identity
   - latest `GameState`
   - recent `PhalanxEvent`s
   - debug log entries
6. SwiftUI views read only from the published session state.

## Debug and Logging Strategy

The native client should help validate the contract, not just present gameplay state.

Current approach:

- Keep an in-memory diagnostic log of:
  - REST requests/results
  - WS state changes
  - incoming server message types
  - integration errors
- Surface recent `PhalanxEvent`s directly in the UI
- Avoid local persistence frameworks for now
- Prefer simple, inspectable debug state over opaque abstraction

Future optional extensions:

- Export session traces to JSON
- Pull and render `/matches/:id/log`
- Show richer turn-hash and transaction-log inspection

## Upstream Gap Escalation Path

Whenever a blocking or risky ambiguity is found:

1. Record the evidence in [`docs/integration-gaps.md`](./integration-gaps.md).
2. Add a recommended upstream issue title.
3. Keep the Swift client conservative:
   - hide the uncertain feature
   - or mark it as unsupported
   - but do not invent the missing behavior

## Non-Goals For This First Slice

- Local match simulation
- Offline mode
- Persistence-backed history
- Full auth/account flows
- Complete action UI for every rule path
- Generated client code from OpenAPI

The first slice exists to validate the authoritative contract and provide a clear native observation shell, not to outgrow the upstream server.
