import Foundation

public protocol WebSocketClientDelegate: AnyObject {
    func webSocketClient(_ client: WebSocketClient, didReceiveMessage message: ServerMessage)
    func webSocketClient(_ client: WebSocketClient, didUpdateState state: WebSocketClient.ConnectionState)
    func webSocketClient(_ client: WebSocketClient, didEncounterError error: Error)
}

public final class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
    public enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)

        public var label: String {
            switch self {
            case .disconnected:
                "Disconnected"
            case .connecting:
                "Connecting"
            case .connected:
                "Connected"
            case let .failed(message):
                "Failed: \(message)"
            }
        }
    }

    private let environment: AppEnvironment
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private var webSocketTask: URLSessionWebSocketTask?
    private var pendingMessages: [ClientMessage] = []

    public weak var delegate: WebSocketClientDelegate?
    public private(set) var state: ConnectionState = .disconnected {
        didSet {
            Task { @MainActor in
                delegate?.webSocketClient(self, didUpdateState: state)
            }
        }
    }

    private let decoder = ContractCoding.makeDecoder()
    private let encoder = ContractCoding.makeEncoder()

    public init(environment: AppEnvironment = .current) {
        self.environment = environment
    }

    public func connect() {
        guard state != .connected, state != .connecting else { return }

        state = .connecting

        let task = session.webSocketTask(with: environment.webSocketURL)
        webSocketTask = task
        task.resume()
    }

    public func disconnect() {
        pendingMessages.removeAll()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        state = .disconnected
    }

    public func send(message: ClientMessage) {
        guard webSocketTask != nil else {
            delegate?.webSocketClient(
                self,
                didEncounterError: PhalanxError.serverError(code: "WS_NOT_CONNECTED", message: "WebSocket is not connected.")
            )
            return
        }

        guard state == .connected else {
            pendingMessages.append(message)
            return
        }

        sendImmediately(message)
    }

    public func ping() {
        webSocketTask?.sendPing { [weak self] error in
            guard let self, let error else {
                return
            }

            self.state = .failed(error.localizedDescription)
            self.delegate?.webSocketClient(self, didEncounterError: error)
        }
    }

    private func sendImmediately(_ message: ClientMessage) {
        guard let task = webSocketTask else {
            return
        }

        do {
            let data = try encoder.encode(message)

            if ProcessInfo.processInfo.environment["PHALANX_VERBOSE_LOGGING"] == "true",
               let json = String(data: data, encoding: .utf8) {
                print("[WS DEBUG] Sending message: \(json)")
                // Also write to our diagnostic log
                writeToExternalLog("[WS DEBUG] Sending message: \(json)\n")
            }

            task.send(.data(data)) { [weak self] error in
                guard let self else {
                    return
                }

                if let error = error {
                    self.state = .failed(error.localizedDescription)
                    self.delegate?.webSocketClient(self, didEncounterError: error)
                }
            }
        } catch {
            delegate?.webSocketClient(self, didEncounterError: PhalanxError.encodingError(error))
        }
    }

    private func flushPendingMessages() {
        guard state == .connected else {
            return
        }

        let queued = pendingMessages
        pendingMessages.removeAll()

        for message in queued {
            sendImmediately(message)
        }
    }

    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(message):
                self.handleIncomingMessage(message)
                self.listen()
            case let .failure(error):
                if let error = error as? URLError, error.code == .cancelled {
                    self.state = .disconnected
                    return
                }

                self.state = .failed(error.localizedDescription)
                self.delegate?.webSocketClient(self, didEncounterError: error)
            }
        }
    }

    private func handleIncomingMessage(_ message: URLSessionWebSocketTask.Message) {
        let dataToDecode: Data

        switch message {
        case let .string(string):
            guard let data = string.data(using: .utf8) else { return }
            dataToDecode = data
        case let .data(data):
            dataToDecode = data
        @unknown default:
            return
        }

        if ProcessInfo.processInfo.environment["PHALANX_VERBOSE_LOGGING"] == "true",
           let json = String(data: dataToDecode, encoding: .utf8) {
            print("[WS DEBUG] Received message: \(json)")
            writeToExternalLog("[WS DEBUG] Received message: \(json)\n")
        }

        do {
            let decodedMessage = try decoder.decode(ServerMessage.self, from: dataToDecode)
            Task { @MainActor in
                delegate?.webSocketClient(self, didReceiveMessage: decodedMessage)
            }
        } catch {
            if ProcessInfo.processInfo.environment["PHALANX_VERBOSE_LOGGING"] == "true",
               let json = String(data: dataToDecode, encoding: .utf8) {
                writeToExternalLog("[WS DEBUG] Decoding failed for ServerMessage. Raw JSON: \(json)\n")
            }
            delegate?.webSocketClient(self, didEncounterError: PhalanxError.decodingError(error))
        }
    }

    private func writeToExternalLog(_ line: String) {
        if let logPath = ProcessInfo.processInfo.environment["PHALANX_DEBUG_LOG_PATH"] {
            let fileURL = URL(fileURLWithPath: logPath)
            if let data = line.data(using: .utf8) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                } else {
                    try? data.write(to: fileURL)
                }
            }
        }
    }

    public func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didOpenWithProtocol _: String?
    ) {
        state = .connected
        flushPendingMessages()
        listen()
    }

    public func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didCloseWith _: URLSessionWebSocketTask.CloseCode,
        reason _: Data?
    ) {
        if state != .disconnected {
            state = .disconnected
        }
    }
}
