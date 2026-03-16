import Foundation

public nonisolated struct AppEnvironment: Equatable, Sendable {
    public let name: String
    public let apiBaseURL: URL
    public let webSocketURL: URL
    public let documentationBaseURL: URL

    public init(
        name: String,
        apiBaseURL: URL,
        webSocketURL: URL? = nil,
        documentationBaseURL: URL? = nil
    ) {
        self.name = name
        self.apiBaseURL = apiBaseURL
        self.webSocketURL = webSocketURL ?? Self.derivedWebSocketURL(from: apiBaseURL)
        self.documentationBaseURL = documentationBaseURL ?? apiBaseURL
    }

    public init(
        name: String,
        apiBaseURLString: String,
        webSocketURLString: String? = nil,
        documentationBaseURLString: String? = nil
    ) throws {
        guard let apiBaseURL = Self.normalizedURL(from: apiBaseURLString) else {
            throw AppEnvironmentError.invalidBaseURL(apiBaseURLString)
        }

        let webSocketURL: URL?
        if let webSocketURLString, !webSocketURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsedURL = Self.normalizedURL(from: webSocketURLString) else {
                throw AppEnvironmentError.invalidWebSocketURL(webSocketURLString)
            }
            webSocketURL = parsedURL
        } else {
            webSocketURL = nil
        }

        let documentationBaseURL: URL?
        if let documentationBaseURLString, !documentationBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsedURL = Self.normalizedURL(from: documentationBaseURLString) else {
                throw AppEnvironmentError.invalidDocumentationURL(documentationBaseURLString)
            }
            documentationBaseURL = parsedURL
        } else {
            documentationBaseURL = nil
        }

        self.init(
            name: name,
            apiBaseURL: apiBaseURL,
            webSocketURL: webSocketURL,
            documentationBaseURL: documentationBaseURL
        )
    }

    public static let localProxy = AppEnvironment(
        name: "Local Proxy",
        apiBaseURL: URL(string: "http://localhost:5173")!,
        webSocketURL: URL(string: "ws://localhost:5173/ws")!,
        documentationBaseURL: URL(string: "http://localhost:3001")!
    )

    public static let localDirect = AppEnvironment(
        name: "Local Direct",
        apiBaseURL: URL(string: "http://localhost:3001")!,
        webSocketURL: URL(string: "ws://localhost:3001/ws")!,
        documentationBaseURL: URL(string: "http://localhost:3001")!
    )

    public static let production = AppEnvironment(
        name: "Production",
        apiBaseURL: URL(string: "https://play.phalanxduel.com")!,
        webSocketURL: URL(string: "wss://play.phalanxduel.com/ws")!,
        documentationBaseURL: URL(string: "https://play.phalanxduel.com")!
    )

    public static let presets: [AppEnvironment] = [.localProxy, .localDirect, .production]

    public nonisolated static var current: AppEnvironment {
        let environment = ProcessInfo.processInfo.environment

        if let apiBaseURL = environment["PHALANX_CLIENT_BASE_URL"] {
            return (try? AppEnvironment(
                name: "Custom",
                apiBaseURLString: apiBaseURL,
                webSocketURLString: environment["PHALANX_CLIENT_WS_URL"],
                documentationBaseURLString: environment["PHALANX_CLIENT_DOCS_BASE_URL"]
            )) ?? .localProxy
        }

        return .localProxy
    }

    public var healthURL: URL {
        apiBaseURL.appendingPathComponent("health")
    }

    public var defaultsURL: URL {
        apiBaseURL.appendingPathComponent("api").appendingPathComponent("defaults")
    }

    public var matchesURL: URL {
        apiBaseURL.appendingPathComponent("matches")
    }

    public var completedMatchesURL: URL {
        matchesURL.appendingPathComponent("completed")
    }

    public var openAPIURL: URL {
        documentationBaseURL.appendingPathComponent("docs").appendingPathComponent("json")
    }

    private static func derivedWebSocketURL(from baseURL: URL) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        let normalizedPath = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalizedPath.isEmpty {
            components?.path = "/ws"
        } else {
            components?.path = "/\(normalizedPath)/ws"
        }

        return components?.url ?? baseURL.appendingPathComponent("ws")
    }

    private static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        guard var components = URLComponents(string: trimmed), let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "ws" || scheme == "wss" else {
            return nil
        }

        if components.path.hasSuffix("/") && components.path.count > 1 {
            components.path.removeLast()
        }

        return components.url
    }
}

public nonisolated enum AppEnvironmentError: LocalizedError {
    case invalidBaseURL(String)
    case invalidWebSocketURL(String)
    case invalidDocumentationURL(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let value):
            "Invalid API base URL: \(value)"
        case .invalidWebSocketURL(let value):
            "Invalid WebSocket URL: \(value)"
        case .invalidDocumentationURL(let value):
            "Invalid documentation base URL: \(value)"
        }
    }
}
