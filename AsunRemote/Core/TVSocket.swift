import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol TVSocket: Sendable {
    func send(_ text: String) async throws
    func receive() async throws -> String
    func close() async
}

typealias SocketFactory = @Sendable (URL) async throws -> any TVSocket

final class SessionSocket: TVSocket, @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(url: URL, session: URLSession) {
        task = session.webSocketTask(with: url)
        task.maximumMessageSize = 1_048_576
        task.resume()
    }

    func send(_ text: String) async throws { try await task.send(.string(text)) }

    func receive() async throws -> String {
        switch try await task.receive() {
        case .string(let text): return text
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8) else {
                throw RemoteError.message("The TV sent an unreadable response.")
            }
            return text
        @unknown default: throw RemoteError.message("The TV sent an unsupported message.")
        }
    }

    func close() async { task.cancel(with: .goingAway, reason: nil) }
}
