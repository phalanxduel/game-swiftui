---
name: phalanxduel-swiftui-instructions
scope: repository
audience: all coding agents
canonical: true
---

# Agent Instructions

This repository is the native macOS SwiftUI client for Phalanx Duel. The server
remains authoritative; do not implement gameplay rules or infer authoritative
match state in the client. Keep wire behavior aligned with the browser client
and published server contracts.

- Read `README.md` for build, validation, and release workflows.
- Check `docs/integration-gaps.md` before changing server/client contracts; it
  records observed evidence and current resolution status.
- Run `bin/check` for the fast local gate. Use `bin/ci` for the broader unit-test
  lane; UI verification requires a running server and interactive desktop.
- Keep signing, release, and Homebrew tap changes within the documented release
  workflow.
