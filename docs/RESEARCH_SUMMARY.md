# Research Summary: Phalanx Duel SwiftUI Client

## Upstream Authority (../game)
The upstream repository is the canonical source of truth for all game rules, contracts, and service definitions.

### Game Rules & Mechanics
- **Turn Lifecycle**: Strict 8-phase deterministic cycle (`StartTurn`, `Deployment`, `Attack`, `Resolution`, `Cleanup`, `Reinforcement`, `Draw`, `EndTurn`).
- **Attack Resolution**: Deterministic "Target Chain" logic.
- **Suit Effects**: 
  - ♣/♠ (Weapons): Double damage to cards/players.
  - ♦/♥ (Shields): Damage reduction.
- **Special Modes**: Classic Aces (restricted destruction), Classic Face Cards (rank-based eligibility), and Damage Persistence (Classic vs. Cumulative).
- **Board Geometry**: Row-major indexing, typically 2x4.

### Services & Infrastructure
- **Endpoints**: 
  - REST: `/health`, `/api/defaults`, `/matches`, `/matches/:id/log`.
  - WebSocket: `/ws` for real-time play.
- **Hosting**: Fly.io (Production/Staging), PostgreSQL, OpenTelemetry for observability.

## Client State (game-swiftui)

### Architecture
- **Thin Client**: The client renders state and sends intent; it does not calculate rules.
- **Store**: `SessionStore` (MainActor-safe `ObservableObject`) owns the connection and authoritative state.
- **Models**: Complete `Codable` mapping of the upstream `schema.ts`.

### Current Progress
- **Boot Sequence**: High-polish `BootView` handles environment init and server discovery.
- **Networking**: `WebSocketClient` and `RestClient` are operational.
- **UI**: Rudimentary `GameTableView` and `ServerConnectView` implemented.

### Integration Gaps
- **`preState` Semantics**: Upstream `gameState` broadcasts currently send "post-state" in the `preState` field, blocking native turn-diffing.
- **Gameplay Actions**: Deploy and Attack UI interactions are pending.
