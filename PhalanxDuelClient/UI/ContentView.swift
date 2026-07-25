import SwiftUI
#if os(macOS)
import AppKit
#endif

public struct ContentView: View {
    @StateObject private var sessionStore = SessionStore()

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if sessionStore.isBooting {
                    BootView(sessionStore: sessionStore)
#if os(iOS)
                        .toolbar(.hidden, for: .navigationBar)
#endif
                } else if sessionStore.hasActiveSession {
                    GameSessionView(sessionStore: sessionStore)
                } else {
                    ServerConnectView(sessionStore: sessionStore)
                }
            }
            .toolbar {
                if !sessionStore.isBooting && sessionStore.hasActiveSession {
#if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Disconnect") {
                            sessionStore.disconnect()
                        }
                    }
#else
                    ToolbarItem(placement: .navigation) {
                        Button("Disconnect") {
                            sessionStore.disconnect()
                        }
                    }
#endif
                }
            }
        }
#if os(macOS)
        .onAppear {
            placeAutomationWindowOnPrimaryScreen()
        }
#endif
    }

#if os(macOS)
    private func placeAutomationWindowOnPrimaryScreen() {
        guard ProcessInfo.processInfo.environment["PHALANX_AUTOMATION"] == "true" else {
            return
        }

        DispatchQueue.main.async {
            guard let screen = NSScreen.screens.first,
                  let window = NSApplication.shared.windows.first else {
                return
            }

            // Automation cannot interact with the window itself, so it is
            // maximized on launch: fill the visible screen area rather than
            // a fixed size, guaranteeing the full board stays on-screen.
            window.setFrame(screen.visibleFrame, display: true)
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
#endif
}
