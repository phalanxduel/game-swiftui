# Phalanx Duel — SwiftUI Client

Native macOS client for [Phalanx Duel](https://github.com/phalanxduel/phalanxduel), a
head-to-head combat card game. Talks to the same server and wire protocol as the
[browser client](https://github.com/phalanxduel/phalanxduel/tree/main/client) — the
server is always authoritative; this app never invents gameplay logic locally.

**Status: alpha.** Ad-hoc signed, unnotarized, not yet App Store-ready.

## Install

```bash
brew tap phalanxduel/tap
brew install --cask phalanx-duel-client
```

Or grab the zip from the [latest release](https://github.com/phalanxduel/game-swiftui/releases/latest),
unzip it, and right-click → Open on first launch (Gatekeeper will otherwise
block it, since this build isn't notarized).

### Signing in

Registration is web-only. Either:

- Sign in with an existing account directly in the app, or
- Sign in on the web client and click **"Open in Desktop App"** — this hands
  off a short-lived, single-use code via a `phalanxduel://` URL rather than
  putting your session token anywhere it could leak.

## Building from source

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open PhalanxDuelClient.xcodeproj
```

To build a distributable, ad-hoc-signed `.app` the same way releases are cut:

```bash
bin/archive-app.sh
```

## Cutting a Release

Push a tag matching `vX.Y.Z` (set `MARKETING_VERSION` in `project.yml` to match
first) and [`.github/workflows/release.yml`](.github/workflows/release.yml)
does the rest: runs `bin/archive-app.sh`, generates release notes from
conventional-commit messages since the previous tag, creates the GitHub
release with the zip attached, and bumps
[`phalanxduel/homebrew-tap`](https://github.com/phalanxduel/homebrew-tap)'s
`Casks/phalanx-duel-client.rb` `version`/`sha256` automatically.

## Compatibility

On connect, the client checks the server's reported wire-format version
(`schemaVersion` from `/api/defaults`) against what it was built for, and
shows a warning banner if they don't match on the major version. See
[`docs/architecture/versioning.md`](https://github.com/phalanxduel/phalanxduel/blob/main/docs/architecture/versioning.md)
in the main repo for the full policy.

## Related

- [phalanxduel/phalanxduel](https://github.com/phalanxduel/phalanxduel) — server, engine, browser client, Go CLI
- [phalanxduel/homebrew-tap](https://github.com/phalanxduel/homebrew-tap) — Homebrew formula/cask source
