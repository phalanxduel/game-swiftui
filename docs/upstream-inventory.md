# Upstream Inventory

This repository is a standalone SwiftUI client that treats [`../game`](../game) as the authoritative upstream implementation of Phalanx Duel. The inventory below records which upstream files are canonical, which are supporting references, and which ambiguities must stay explicit instead of being guessed around locally.

## Authority Chain

The strongest source-of-truth statement found upstream is:

- `backlog/decisions/DEC-2A-001 - Authority model is explicit.md`
  - `docs/RULES.md` is normative rules authority.
  - `shared/src/schema.ts` is contract authority.
  - `engine/src/state-machine.ts` is runtime transition authority.
  - `docs/system/ARCHITECTURE.md` is descriptive and must match runtime/contracts.

This is reinforced by:

- `docs/README.md`
- `docs/system/DEFINITION_OF_DONE.md`
- `docs/system/ARCHITECTURE.md`
- `docs/system/TYPE_OWNERSHIP.md`

## Canonical Sources

| File | Area | Why it appears canonical | Client impact |
| --- | --- | --- | --- |
| `../game/docs/RULES.md` | Gameplay rules and invariants | Explicitly named as normative rules authority in DEC-2A-001 and DoD | The Swift client must never resolve gameplay locally against anything else |
| `../game/shared/src/schema.ts` | Cross-package wire contracts | Explicitly named as contract authority in DEC-2A-001, docs wiki, DoD, and type ownership docs | Primary source for Swift `Codable` models and message shapes |
| `../game/shared/src/types.ts` | Generated TS type surface | Generated from `shared/src/schema.ts` | Secondary confirmation of contract names, not primary authoring source |
| `../game/shared/json-schema/*.json` | Machine-readable schema artifacts | Generated from `shared/src/schema.ts` | Useful external-reference artifacts for contract validation; source-of-truth remains `schema.ts` |
| `../game/server/src/app.ts` | HTTP routes, WebSocket endpoint, runtime URLs | Registers `/health`, `/api/defaults`, `/matches`, `/docs/json`, `/ws`, admin routes, and auth middleware | Authoritative server surface for bootstrap/connectivity |
| `../game/server/src/routes/matches.ts` | Match log and completed-match HTTP surface | Defines `/matches/completed` and `/matches/:id/log` | Needed for history/debug/log viewing in native client |
| `../game/server/src/routes/stats.ts` | Stats and replay-verification HTTP surface | Defines `/api/stats` and `/api/matches/:matchId/verify` | Supporting runtime diagnostics endpoints |
| `../game/server/src/match.ts` | Broadcast filtering and lifecycle wiring | Implements player/spectator state filtering and WS broadcast payloads | Critical for understanding what the Swift client can safely expect from `gameState` |
| `../game/engine/src/state-machine.ts` | Runtime transition authority | Named as runtime authority by DEC-2A-001 | Reference only; the Swift client must not replicate it |
| `../game/GLOSSARY.md` | Canonical terminology | Defines shared vocabulary like Match, Battlefield, Target Chain, Carryover | Native UI/docs should preserve these names where possible |

## Supporting References

These files are not the primary source of truth, but they are valuable for discovery, examples, and clarifying runtime behavior.

| File | Why it matters |
| --- | --- |
| `../game/README.md` | Confirms local dev URLs, Swagger/OpenAPI location, and the WS endpoint |
| `../game/docs/system/SITE_FLOW.md` | Best single narrative inventory of public HTTP routes and screen/transport flow |
| `../game/docs/system/ARCHITECTURE.md` | Describes server-authoritative design and dependency boundaries |
| `../game/docs/system/TYPE_OWNERSHIP.md` | Explains why cross-package shapes live in `shared/` and should not be duplicated elsewhere |
| `../game/server/tests/ws.test.ts` | Concrete examples of `createMatch`, `joinMatch`, `watchMatch`, and `gameState` message ordering |
| `../game/server/tests/defaults-endpoint.test.ts` | Confirms the intended `/api/defaults` payload shape at a high level |
| `../game/server/tests/match-log-routes.test.ts` | Confirms log route behavior and content negotiation |
| `../game/server/tests/lifecycle-events.test.ts` | Shows lifecycle event ordering and event-log expectations |
| `../game/server/tests/__snapshots__/openapi.test.ts.snap` | Reveals what the generated OpenAPI document currently exposes and omits |
| `../game/client/src/connection.ts` | Demonstrates the official client’s reconnect/auth-on-open behavior |
| `../game/client/src/state.ts` | Shows how the official client treats `matchCreated`, `matchJoined`, `spectatorJoined`, and `gameState` |
| `../game/client/src/game.ts` | Confirms battlefield indexing is row-major: `row * columns + col` |
| `../game/backlog/tasks/task-32 - JSON-Schema-for-Public-Event-Envelopes.md` | Signals an acknowledged upstream contract-publication gap |
| `../game/backlog/decisions/DEC-2D-003 - Public stream post-state payloads.md` | Confirms public streams are intended to be post-state oriented |

## Runtime Surface Identified

### HTTP

Observed in `README.md`, `docs/system/SITE_FLOW.md`, `server/src/app.ts`, and route files:

- `GET /health`
- `GET /api/defaults`
- `POST /matches`
- `GET /matches`
- `GET /matches/completed`
- `GET /matches/:id/log`
- `GET /matches/:matchId/replay`
- `GET /api/stats`
- `GET /api/matches/:matchId/verify`
- `GET /docs`
- `GET /docs/json`

Additional auth/admin routes exist upstream, but they are not required for this first thin native slice:

- `/api/auth/*`
- `/admin`
- `/admin/ab-tests`

### WebSocket

Observed in `server/src/app.ts`, `shared/src/schema.ts`, and `server/tests/ws.test.ts`:

- Endpoint: `ws://localhost:3001/ws`
- Client messages:
  - `createMatch`
  - `joinMatch`
  - `watchMatch`
  - `action`
  - `authenticate`
- Server messages:
  - `matchCreated`
  - `matchJoined`
  - `spectatorJoined`
  - `gameState`
  - `actionError`
  - `matchError`
  - `opponentDisconnected`
  - `opponentReconnected`
  - `authenticated`
  - `auth_error`

## Local Runtime Profiles

Confirmed against the running local server and upstream Vite config:

- `../game/client/vite.config.ts` proxies `/health`, `/api`, `/matches`, and `/ws` from `http://localhost:5173` to the server on `http://localhost:3001`.
- `GET http://localhost:5173/docs/json` does not return the OpenAPI JSON. It returns the Vite app shell instead because `/docs/json` is not proxied.

That means the native client needs two practical local profiles:

- `Local Proxy`
  - API base: `http://localhost:5173`
  - WebSocket base: `ws://localhost:5173/ws`
  - Docs/OpenAPI base: `http://localhost:3001`
- `Local Direct`
  - API base: `http://localhost:3001`
  - WebSocket base: `ws://localhost:3001/ws`
  - Docs/OpenAPI base: `http://localhost:3001`

## Observed State and Filtering Rules

From `server/src/match.ts`:

- Player broadcasts are filtered with `filterStateForPlayer`.
  - The local player keeps their real `hand` and `drawpile`.
  - The opponent is redacted to `hand: []`, `drawpile: []`, plus `handCount` and `drawpileCount`.
- Spectator broadcasts are filtered with `filterStateForSpectator`.
  - Both players’ `hand` and `drawpile` are redacted.
- Battlefield indexing is row-major.
  - Evidence: `engine/src/state.ts` and `client/src/game.ts` use `row * columns + col`.

## Terminology To Preserve

The native client should prefer upstream terminology exactly where possible:

- `Match`
- `Player`
- `Battlefield`
- `Column`
- `Rank`
- `Target Chain`
- `Carryover`
- `Cleanup Phase`
- `Reinforcement Phase`
- `SpecVersion`
- `PhalanxEvent`
- `GameState`
- `MatchEventLog`
- `turnHash`

Terms that currently need careful handling:

- `Graveyard` is the glossary term, but the shared state contract uses `discardPile`.
- `Classic` appears both as a rules template concept and in wire fields like `modeClassicAces`.
- `gameState.result.postState` is the public-safe state the client should trust for rendering.

## First-Pass Ambiguities

These are concrete uncertainties or mismatches that the Swift client should not guess through:

1. The WebSocket `PhalanxTurnResult.preState` payload appears inconsistent with its name and schema intent.
2. `/api/defaults` documents a total-slot constraint that conflicts with `docs/RULES.md` and `shared/src/schema.ts`.
3. The generated OpenAPI document is discoverable, but not rich enough yet for safe external code generation.
4. Public event-envelope publication is still tracked as an upstream task rather than one clearly documented consumer artifact.
5. Rules/glossary terminology and state-schema field names are not perfectly aligned (`Graveyard` vs `discardPile`).

These are tracked in [`docs/integration-gaps.md`](./integration-gaps.md).
