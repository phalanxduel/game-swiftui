import SwiftUI

public struct ContentView: View {
    @StateObject private var sessionStore = SessionStore()

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if sessionStore.isBooting {
                    BootView(sessionStore: sessionStore)
                } else if sessionStore.hasActiveSession {
                    GameSessionView(sessionStore: sessionStore)
                } else {
                    ServerConnectView(sessionStore: sessionStore)
                }
            }
            .toolbar {
                if !sessionStore.isBooting && sessionStore.hasActiveSession {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Disconnect") {
                            sessionStore.disconnect()
                        }
                    }
                }
            }
        }
    }
}
