import Foundation

actor LGTVClient {
    private struct Pending {
        let expectedType: String
        let continuation: CheckedContinuation<TVPayload, Error>
        let timeout: Task<Void, Never>
    }

    private let factory: SocketFactory
    private let requestTimeout: TimeInterval
    private let pairingTimeout: TimeInterval
    private var socket: (any TVSocket)?
    private var pointer: (any TVSocket)?
    private var pointerOpening: Task<any TVSocket, Error>?
    private var receiveTask: Task<Void, Never>?
    private var pointerReceiveTask: Task<Void, Never>?
    private var pointerID = UUID()
    private var pending: [String: Pending] = [:]
    private var generation = UUID()
    private var endpoint: TVEndpoint?
    private(set) var isConnected = false

    init(requestTimeout: TimeInterval = 8, pairingTimeout: TimeInterval = 60,
         factory: @escaping SocketFactory) {
        self.factory = factory
        self.requestTimeout = requestTimeout
        self.pairingTimeout = pairingTimeout
    }

    func connect(to endpoint: TVEndpoint, clientKey: String?) async throws -> String {
        await disconnect()
        let current = generation
        self.endpoint = endpoint
        let connection = try await factory(endpoint.url)
        guard current == generation else { await connection.close(); throw CancellationError() }
        socket = connection
        receiveTask = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    let text = try await connection.receive()
                    await self?.receive(text, generation: current)
                }
            } catch { await self?.connectionFailed(error, generation: current) }
        }
        do {
            let response = try await exchange(TVProtocol.registration(id: UUID().uuidString, clientKey: clientKey),
                                              expected: "registered", timeout: pairingTimeout)
            guard current == generation else { throw CancellationError() }
            guard let key = response["client-key"]?.string ?? clientKey, !key.isEmpty else {
                throw RemoteError.message("The TV did not return a pairing key. Forget this TV and pair again.")
            }
            isConnected = true
            return key
        } catch {
            if current == generation { await disconnect() }
            throw error
        }
    }

    func disconnect() async {
        generation = UUID()
        isConnected = false
        endpoint = nil
        receiveTask?.cancel(); receiveTask = nil
        pointerReceiveTask?.cancel(); pointerReceiveTask = nil
        pointerID = UUID()
        pointerOpening?.cancel(); pointerOpening = nil
        let old = socket; socket = nil
        let oldPointer = pointer; pointer = nil
        let abandoned = pending.values
        pending.removeAll()
        for item in abandoned {
            item.timeout.cancel()
            item.continuation.resume(throwing: RemoteError.disconnected)
        }
        await old?.close()
        await oldPointer?.close()
    }

    func request(_ uri: String, payload: TVPayload = [:]) async throws -> TVPayload {
        guard isConnected else { throw RemoteError.notPaired }
        return try await exchange(TVEnvelope(type: "request", id: UUID().uuidString,
                                             uri: "ssap://" + uri, payload: payload),
                                  expected: "response", timeout: requestTimeout)
    }

    func press(_ button: RemoteButton) async throws {
        guard isConnected, let endpoint else { throw RemoteError.notPaired }
        let current = generation
        if pointer == nil {
            if pointerOpening == nil {
                let factory = factory
                pointerOpening = Task {
                    let response = try await self.request("com.webos.service.networkinput/getPointerInputSocket")
                    guard let path = response["socketPath"]?.string else {
                        throw RemoteError.message("The TV did not provide its navigation connection.")
                    }
                    let url = try endpoint.validatedPointerURL(path)
                    try Task.checkCancellation()
                    return try await factory(url)
                }
            }
            do {
                guard let opening = pointerOpening else { throw RemoteError.disconnected }
                let opened = try await opening.value
                guard current == generation, isConnected else {
                    await opened.close()
                    throw RemoteError.disconnected
                }
                // Several simultaneous presses may have awaited the same open operation.
                if pointer == nil {
                    pointer = opened
                    let openedID = UUID()
                    pointerID = openedID
                    pointerReceiveTask = Task { [weak self] in
                        do { while !Task.isCancelled { _ = try await opened.receive() } }
                        catch { await self?.pointerFailed(generation: current, pointerID: openedID) }
                    }
                }
                pointerOpening = nil
            } catch {
                if current == generation { pointerOpening = nil }
                throw error
            }
        }
        guard let connection = pointer, current == generation else { throw RemoteError.disconnected }
        let sendingID = pointerID
        do { try await connection.send(button.wireMessage) }
        catch { await pointerFailed(generation: current, pointerID: sendingID); throw error }
    }

    private func exchange(_ message: TVEnvelope, expected: String, timeout: TimeInterval) async throws -> TVPayload {
        guard let connection = socket, let id = message.id else { throw RemoteError.disconnected }
        let text = try message.text()
        let current = generation
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                let timer = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000)) }
                    catch { return }
                    await self?.fail(id, error: RemoteError.timedOut)
                }
                pending[id] = Pending(expectedType: expected, continuation: continuation, timeout: timer)
                Task {
                    do { try await connection.send(text) }
                    catch {
                        self.fail(id, error: error)
                        await self.connectionFailed(error, generation: current)
                    }
                }
            }
        } onCancel: {
            Task { await self.fail(id, error: CancellationError()) }
        }
    }

    private func receive(_ text: String, generation current: UUID) async {
        guard current == generation else { return }
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(TVEnvelope.self, from: data) else {
            await connectionFailed(RemoteError.message("The TV sent an invalid response."), generation: current)
            return
        }
        guard let id = message.id, let item = pending[id] else { return }
        let payload = message.payload ?? [:]
        if message.type == "error" || payload["returnValue"]?.bool == false {
            fail(id, error: RemoteError.message(message.error ?? payload["errorText"]?.string ?? "The TV could not complete this command."))
            return
        }
        // A pairing prompt is an intermediate response, not a successful registration.
        guard message.type == item.expectedType else { return }
        pending.removeValue(forKey: id)
        item.timeout.cancel()
        item.continuation.resume(returning: payload)
    }

    private func fail(_ id: String, error: Error) {
        guard let item = pending.removeValue(forKey: id) else { return }
        item.timeout.cancel()
        item.continuation.resume(throwing: error)
    }

    private func connectionFailed(_ error: Error, generation current: UUID) async {
        guard current == generation else { return }
        let waiting = pending.values
        pending.removeAll()
        for item in waiting { item.timeout.cancel(); item.continuation.resume(throwing: error) }
        await disconnect()
    }

    private func pointerFailed(generation current: UUID, pointerID failedID: UUID) async {
        guard current == generation, failedID == pointerID else { return }
        pointerID = UUID()
        let old = pointer; pointer = nil
        pointerReceiveTask?.cancel(); pointerReceiveTask = nil
        await old?.close()
    }
}
