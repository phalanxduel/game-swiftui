@testable import PhalanxDuelClient
import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite("BootView Snapshot Tests")
struct BootViewSnapshotTests {
    @Test("Initial state snapshot")
    func initialState() {
        let sessionStore = SessionStore()
        let view = BootView(sessionStore: sessionStore)
        // Note: In a real environment, we would use a fixed clock/seed to ensure determinism
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    @Test("Loading tasks snapshot")
    func loadingTasks() {
        let sessionStore = SessionStore()
        // Modify internal state for the snapshot
        // We can do this because we're on the @MainActor
        if sessionStore.bootTasks.count > 1 {
            sessionStore.bootTasks[0].status = .success
            sessionStore.bootTasks[1].status = .loading
        }

        let view = BootView(sessionStore: sessionStore)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    @Test("Failure state snapshot")
    func failureState() {
        let sessionStore = SessionStore()
        if sessionStore.bootTasks.count > 0 {
            sessionStore.bootTasks[0].status = .failure
            sessionStore.bootTasks[0].errorMessage = "Connection timed out"
        }

        let view = BootView(sessionStore: sessionStore)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }
}
