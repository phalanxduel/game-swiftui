@testable import PhalanxDuelClient
import AppKit
import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite("BootView Snapshot Tests")
struct BootViewSnapshotTests {
    private func snapshot(
        _ view: some View,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let hostingView = NSHostingView(rootView: view.frame(width: 390, height: 844))
        hostingView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        hostingView.wantsLayer = true
        hostingView.autoresizingMask = [.width, .height]
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.setContentSize(hostingView.frame.size)
        window.orderFrontRegardless()
        window.displayIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        assertSnapshot(
            of: hostingView,
            as: .image,
            file: file,
            testName: name,
            line: line
        )
        window.orderOut(nil)
    }

    @Test("Initial state snapshot")
    func initialState() {
        let sessionStore = SessionStore()
        let view = BootView(sessionStore: sessionStore)
        // Note: In a real environment, we would use a fixed clock/seed to ensure determinism
        snapshot(view, named: "initialState")
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
        snapshot(view, named: "loadingTasks")
    }

    @Test("Failure state snapshot")
    func failureState() {
        let sessionStore = SessionStore()
        if sessionStore.bootTasks.count > 0 {
            sessionStore.bootTasks[0].status = .failure
            sessionStore.bootTasks[0].errorMessage = "Connection timed out"
        }

        let view = BootView(sessionStore: sessionStore)
        snapshot(view, named: "failureState")
    }
}
