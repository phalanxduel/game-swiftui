import Foundation

public nonisolated enum PhalanxError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)
    case unauthenticated
    case serverError(code: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The configured server URL is invalid."
        case let .networkError(error):
            error.localizedDescription
        case let .decodingError(error):
            "Failed to decode server response: \(error.localizedDescription)"
        case let .encodingError(error):
            "Failed to encode request: \(error.localizedDescription)"
        case .unauthenticated:
            "Authentication is required for this request."
        case let .serverError(code, message):
            "[\(code)] \(message)"
        }
    }
}

public nonisolated struct CreateMatchResponse: Codable, Equatable, Sendable {
    public let matchId: String
}

public nonisolated struct StandardErrorResponse: Codable, Equatable, Sendable {
    public let error: String
    public let code: String
}

public nonisolated struct ServerHealthResponse: Codable, Equatable, Sendable {
    public nonisolated struct Observability: Codable, Equatable, Sendable {
        public let otelActive: Bool
        public let region: String

        enum CodingKeys: String, CodingKey {
            case otelActive = "otel_active"
            case region
        }
    }

    public let status: String
    public let timestamp: Date
    public let version: String
    public let uptimeSeconds: Int
    public let memoryHeapUsedMB: Int
    public let observability: Observability

    enum CodingKeys: String, CodingKey {
        case status
        case timestamp
        case version
        case uptimeSeconds = "uptime_seconds"
        case memoryHeapUsedMB = "memory_heap_used_mb"
        case observability
    }
}

public nonisolated struct ServerDefaultsResponse: Codable, Equatable, Sendable {
    public nonisolated struct Metadata: Codable, Equatable, Sendable {
        public nonisolated struct Constraints: Codable, Equatable, Sendable {
            public nonisolated struct NumericConstraint: Codable, Equatable, Sendable {
                public let min: Int?
                public let max: Int?
                public let note: String?
            }

            public let rows: NumericConstraint
            public let columns: NumericConstraint
            public let maxHandSize: NumericConstraint
            public let initialDraw: NumericConstraint
            public let startingLifepoints: NumericConstraint
            public let totalSlots: NumericConstraint
        }

        public let configSource: String
        public let constraints: Constraints
        public let botStrategies: [String]
    }

    public let specVersion: String
    public let rows: Int
    public let columns: Int
    public let maxHandSize: Int
    public let initialDraw: Int
    public let startingLifepoints: Int
    public let modeDamagePersistence: DamageMode
    public let meta: Metadata

    enum CodingKeys: String, CodingKey {
        case specVersion
        case rows
        case columns
        case maxHandSize
        case initialDraw
        case startingLifepoints
        case modeDamagePersistence
        case meta = "_meta"
    }
}

public nonisolated struct ActiveMatchPlayerSummary: Codable, Equatable, Sendable {
    public let name: String
    public let connected: Bool
}

public nonisolated struct ActiveMatchSummary: Codable, Identifiable, Equatable, Sendable {
    public let matchId: String
    public let players: [ActiveMatchPlayerSummary]
    public let spectatorCount: Int
    public let phaseName: String?
    public let turnNumber: Int?
    public let ageSeconds: Int
    public let lastActivitySeconds: Int

    public var id: String {
        matchId
    }

    enum CodingKeys: String, CodingKey {
        case matchId
        case players
        case spectatorCount
        case phaseName = "phase"
        case turnNumber
        case ageSeconds
        case lastActivitySeconds
    }
}

public final class RestClient {
    private let environment: AppEnvironment
    private let session: URLSession

    public init(environment: AppEnvironment = .current, session: URLSession = .shared) {
        self.environment = environment
        self.session = session
    }

    public func createMatch() async throws -> String {
        var request = URLRequest(url: environment.matchesURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let response: CreateMatchResponse = try await perform(request, expectingStatusCodes: Set([201]))
        return response.matchId
    }

    public func fetchMatches() async throws -> [ActiveMatchSummary] {
        var request = URLRequest(url: environment.matchesURL)
        request.httpMethod = "GET"
        return try await perform(request, expectingStatusCodes: Set([200]))
    }

    public func fetchHealth() async throws -> ServerHealthResponse {
        var request = URLRequest(url: environment.healthURL)
        request.httpMethod = "GET"
        return try await perform(request, expectingStatusCodes: Set([200]))
    }

    public func fetchDefaults() async throws -> ServerDefaultsResponse {
        var request = URLRequest(url: environment.defaultsURL)
        request.httpMethod = "GET"
        return try await perform(request, expectingStatusCodes: Set([200]))
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        expectingStatusCodes: Set<Int>
    ) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PhalanxError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PhalanxError.invalidURL
        }

        guard expectingStatusCodes.contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw PhalanxError.unauthenticated
            }

            if let serverError = try? ContractCoding.makeDecoder().decode(StandardErrorResponse.self, from: data) {
                throw PhalanxError.serverError(code: serverError.code, message: serverError.error)
            }

            throw PhalanxError.serverError(
                code: "HTTP_\(httpResponse.statusCode)",
                message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }

        do {
            return try ContractCoding.makeDecoder().decode(T.self, from: data)
        } catch {
            throw PhalanxError.decodingError(error)
        }
    }
}
