import Foundation
import Combine

@MainActor
final class RemoteModel: ObservableObject {
    enum Phase: Equatable { case disconnected, pairing, connected }

    @Published var address: String
    @Published var mode: ConnectionMode
    @Published private(set) var phase: Phase = .disconnected
    @Published private(set) var connectedAddress = ""
    @Published var message: String?
    @Published private(set) var volume: Int?
    @Published private(set) var muted: Bool?
    @Published private(set) var apps: [TVApp] = []
    @Published private(set) var inputs: [TVInput] = []
    @Published private(set) var appsProblem: String?
    @Published private(set) var inputsProblem: String?
    @Published private(set) var loadingLists = false

    var connected: Bool { phase == .connected }
    var pairing: Bool { phase == .pairing }

    private var client: LGTVClient?
    private var session: URLSession?
    private var connectionTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?
    private var commandTail: Task<Void, Never>?
    private var connectionID = UUID()
    private var wantsConnection: Bool

    init() {
        address = UserDefaults.standard.string(forKey: "tvAddress") ?? ""
        mode = ConnectionMode(rawValue: UserDefaults.standard.string(forKey: "connectionMode") ?? "") ?? .secure
        wantsConnection = !address.isEmpty
    }

    func connect() {
        guard !pairing else { return }
        let endpoint: TVEndpoint
        let credential: PairingCredential?
        do {
            endpoint = try TVEndpoint(address: address, mode: mode)
            credential = try PairingStore.load(for: endpoint)
        } catch { message = error.localizedDescription; return }

        stop(preserveIntent: true)
        wantsConnection = true
        let id = connectionID
        let trust = TVTrustDelegate(endpoint: endpoint, credential: credential)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 86_400
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        let connectionSession = URLSession(configuration: configuration, delegate: trust, delegateQueue: nil)
        let connection = LGTVClient { url in SessionSocket(url: url, session: connectionSession) }
        session = connectionSession
        client = connection
        phase = .pairing
        message = nil

        connectionTask = Task {
            do {
                let key = try await connection.connect(to: endpoint, clientKey: credential?.clientKey)
                guard id == connectionID, !Task.isCancelled else { return }
                if endpoint.mode == .secure && trust.certificate == nil {
                    throw RemoteError.message("The secure TV identity could not be verified. Try pairing again.")
                }
                do { try PairingStore.save(PairingCredential(clientKey: key, certificate: trust.certificate), for: endpoint) }
                catch { message = error.localizedDescription }
                address = endpoint.host
                connectedAddress = endpoint.host
                phase = .connected
                UserDefaults.standard.set(endpoint.host, forKey: "tvAddress")
                UserDefaults.standard.set(endpoint.mode.rawValue, forKey: "connectionMode")
                startMonitor(connection: connection, id: id)
                await loadLists(connection: connection, id: id)
            } catch {
                guard id == connectionID, !Task.isCancelled else { return }
                let detail = trust.issue ?? friendlyError(error)
                stop(preserveIntent: false)
                message = detail
            }
        }
    }

    func disconnect() { stop(preserveIntent: false) }
    func suspend() { stop(preserveIntent: true) }
    func resume() { if wantsConnection && phase == .disconnected { connect() } }

    func forget() {
        do {
            let endpoint = try TVEndpoint(address: address, mode: mode)
            try PairingStore.delete(for: endpoint)
            stop(preserveIntent: false)
            UserDefaults.standard.removeObject(forKey: "tvAddress")
            UserDefaults.standard.removeObject(forKey: "connectionMode")
            address = ""
            mode = .secure
            message = nil
        } catch { message = error.localizedDescription }
    }

    func press(_ button: RemoteButton) { enqueue { try await $0.press(button) } }

    func changeVolume(up: Bool) {
        enqueue(refreshVolume: true) { connection in _ = try await connection.request(up ? "audio/volumeUp" : "audio/volumeDown") }
    }

    func toggleMute() {
        enqueue(refreshVolume: true) { connection in
            let current = TVVolume(try await connection.request("audio/getVolume"))
            guard let mute = current.muted else { throw RemoteError.message("The TV did not report whether it is muted.") }
            _ = try await connection.request("audio/setMute", payload: ["mute": .bool(!mute)])
        }
    }

    func changeChannel(up: Bool) {
        enqueue { connection in _ = try await connection.request(up ? "tv/channelUp" : "tv/channelDown") }
    }

    func media(_ action: String) {
        guard ["play", "pause", "rewind", "fastForward"].contains(action) else { return }
        enqueue { connection in _ = try await connection.request("media.controls/" + action) }
    }

    func launch(_ app: TVApp) {
        enqueue { connection in _ = try await connection.request("system.launcher/launch", payload: ["id": .string(app.id)]) }
    }

    func selectInput(_ input: TVInput) {
        enqueue { connection in _ = try await connection.request("tv/switchInput", payload: ["inputId": .string(input.id)]) }
    }

    func typeText(_ text: String) {
        guard !text.isEmpty, text.count <= 500 else { return }
        enqueue { connection in
            _ = try await connection.request("com.webos.service.ime/insertText", payload: ["text": .string(text), "replace": .bool(false)])
        }
    }

    func enterText() {
        enqueue { connection in _ = try await connection.request("com.webos.service.ime/sendEnterKey") }
    }

    func deleteCharacter() {
        enqueue { connection in
            _ = try await connection.request("com.webos.service.ime/deleteCharacters", payload: ["count": .number(1)])
        }
    }

    func powerOff() {
        enqueue { [weak self] connection in
            do { _ = try await connection.request("system/turnOff") }
            catch {
                if await connection.isConnected { throw error }
                self?.message = "Connection closed after the power-off request."
            }
            self?.disconnect()
        }
    }

    func refreshLists() {
        guard connected, !loadingLists, let client else { return }
        let id = connectionID
        Task { await loadLists(connection: client, id: id) }
    }

    private func enqueue(refreshVolume: Bool = false, _ operation: @escaping @MainActor (LGTVClient) async throws -> Void) {
        guard connected, let client else { return }
        let previous = commandTail
        let id = connectionID
        commandTail = Task {
            await previous?.value
            guard id == connectionID, connected, !Task.isCancelled else { return }
            do {
                try await operation(client)
                guard id == connectionID, connected else { return }
                if refreshVolume, let result = try? await client.request("audio/getVolume") {
                    guard id == connectionID else { return }
                    updateVolume(result)
                }
            } catch {
                guard id == connectionID, !Task.isCancelled else { return }
                message = friendlyError(error)
                if !(await client.isConnected) { stop(preserveIntent: true) }
            }
        }
    }

    private func startMonitor(connection: LGTVClient, id: UUID) {
        monitorTask = Task {
            while !Task.isCancelled {
                guard id == connectionID else { return }
                if !(await connection.isConnected) {
                    stop(preserveIntent: true)
                    message = "TV disconnected. Turn it on and tap Reconnect."
                    return
                }
                if let result = try? await connection.request("audio/getVolume") {
                    guard id == connectionID else { return }
                    updateVolume(result)
                }
                do { try await Task.sleep(nanoseconds: 4_000_000_000) }
                catch { return }
            }
        }
    }

    private func loadLists(connection: LGTVClient, id: UUID) async {
        guard id == connectionID else { return }
        loadingLists = true
        async let appResponse = optionalRequest(connection, "com.webos.applicationManager/listApps")
        async let inputResponse = optionalRequest(connection, "tv/getExternalInputList")
        let (appResult, inputResult) = await (appResponse, inputResponse)
        guard id == connectionID else { return }
        apps = appResult.map(TVApp.parse) ?? []
        inputs = inputResult.map(TVInput.parse) ?? []
        appsProblem = appResult == nil ? "Your TV did not return its apps. Tap Refresh to retry." : nil
        inputsProblem = inputResult == nil ? "Your TV did not return its inputs. Tap Refresh to retry." : nil
        loadingLists = false
    }

    private func optionalRequest(_ connection: LGTVClient, _ uri: String) async -> TVPayload? {
        try? await connection.request(uri)
    }

    private func updateVolume(_ payload: TVPayload) {
        let status = TVVolume(payload)
        volume = status.level
        muted = status.muted
    }

    private func stop(preserveIntent: Bool) {
        if !preserveIntent { wantsConnection = false }
        connectionID = UUID()
        connectionTask?.cancel(); connectionTask = nil
        monitorTask?.cancel(); monitorTask = nil
        commandTail?.cancel(); commandTail = nil
        let old = client; client = nil
        session?.invalidateAndCancel(); session = nil
        Task { await old?.disconnect() }
        phase = .disconnected
        connectedAddress = ""
        volume = nil; muted = nil
        apps = []; inputs = []
        appsProblem = nil; inputsProblem = nil
        loadingLists = false
    }

    private func friendlyError(_ error: Error) -> String {
        if let remote = error as? RemoteError { return remote.localizedDescription }
        let network = error as NSError
        if network.domain == NSURLErrorDomain {
            return "Could not reach your TV. Keep the TV on, connect both devices to the same home network, and allow Local Network access for Asun Remote in iPhone Settings. If Secure does not work, try Legacy compatibility in Connection settings."
        }
        return error.localizedDescription
    }
}
