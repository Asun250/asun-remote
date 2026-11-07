import XCTest
@testable import RemoteCore

private actor FakeSocket: TVSocket {
    typealias Handler = @Sendable (String, FakeSocket) async throws -> Void
    var handler: Handler?
    private(set) var sent: [String] = []
    private var incoming: [String] = []
    private var waiter: CheckedContinuation<String, Error>?
    private var closed = false

    init(handler: Handler? = nil) { self.handler = handler }
    func setHandler(_ handler: Handler?) { self.handler = handler }
    func send(_ text: String) async throws {
        guard !closed else { throw RemoteError.disconnected }
        sent.append(text)
        try await handler?(text, self)
    }
    func receive() async throws -> String {
        if !incoming.isEmpty { return incoming.removeFirst() }
        if closed { throw RemoteError.disconnected }
        return try await withCheckedThrowingContinuation { waiter = $0 }
    }
    func push(_ text: String) {
        if let waiter { self.waiter = nil; waiter.resume(returning: text) }
        else { incoming.append(text) }
    }
    func close() async {
        closed = true
        waiter?.resume(throwing: RemoteError.disconnected)
        waiter = nil
    }
    func waitForSent(_ count: Int) async throws {
        for _ in 0..<500 {
            if sent.count >= count { return }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        throw RemoteError.timedOut
    }
}

private func decode(_ text: String) throws -> TVEnvelope {
    try JSONDecoder().decode(TVEnvelope.self, from: Data(text.utf8))
}

private func registered(_ text: String, _ socket: FakeSocket) async throws {
    let request = try decode(text)
    if request.type == "register" {
        await socket.push(try TVEnvelope(type: "registered", id: request.id,
                                        payload: ["client-key": .string("test-pair-key")]).text())
    }
}

private func keyboardReply(_ text: String, _ socket: FakeSocket, focused: Bool? = true) async throws {
    let request = try decode(text)
    if request.type == "register" { try await registered(text, socket); return }
    if request.type == "unsubscribe" { return }
    var payload: TVPayload = ["returnValue": .bool(true)]
    if request.type == "subscribe", let focused {
        payload["currentWidget"] = .object(["focus": .bool(focused)])
    }
    await socket.push(try TVEnvelope(type: "response", id: request.id, payload: payload).text())
}

private actor SocketQueue {
    var sockets: [FakeSocket]
    init(_ sockets: [FakeSocket]) { self.sockets = sockets }
    func next() throws -> FakeSocket {
        guard !sockets.isEmpty else { throw RemoteError.disconnected }
        return sockets.removeFirst()
    }
}

final class RemoteCoreTests: XCTestCase {
    private func endpoint(_ mode: ConnectionMode = .secure) throws -> TVEndpoint {
        try TVEndpoint(address: "192.168.1.50", mode: mode)
    }

    func testPrivateAddressValidationAndPointerIsolation() throws {
        for address in ["10.0.0.9", "172.16.1.9", "172.31.9.2", "192.168.1.50", "169.254.2.8"] {
            XCTAssertNoThrow(try TVEndpoint(address: address, mode: .secure))
        }
        for address in ["8.8.8.8", "127.0.0.1", "172.32.0.2", "0.0.0.0", "256.1.2.3", "192.168.1.1:3001", "ws://192.168.1.1", "192.168.1.01", "192.168..1", "192.168.1.1\n@evil.test"] {
            XCTAssertThrowsError(try TVEndpoint(address: address, mode: .secure), address)
        }
        let tv = try endpoint()
        XCTAssertNoThrow(try tv.validatedPointerURL("wss://192.168.1.50:3001/resources/pointer"))
        for path in ["wss://192.168.1.51:3001/pointer", "ws://192.168.1.50:3000/pointer", "wss://192.168.1.50:443/pointer", "wss://user@192.168.1.50:3001/pointer", "wss://example.com:3001/pointer"] {
            XCTAssertThrowsError(try tv.validatedPointerURL(path))
        }
    }

    func testPairingPromptDoesNotCountAsConnection() async throws {
        let socket = FakeSocket { text, socket in
            let request = try decode(text)
            await socket.push(try TVEnvelope(type: "response", id: request.id,
                                            payload: ["pairingType": .string("PROMPT")]).text())
        }
        let client = LGTVClient(factory: { _ in socket })
        let tv = try endpoint()
        let pairing = Task { try await client.connect(to: tv, clientKey: nil) }
        try await socket.waitForSent(1)
        let before = await client.isConnected
        XCTAssertFalse(before)
        let requests = await socket.sent
        let registration = try decode(XCTUnwrap(requests.first))
        XCTAssertNil(registration.payload?["client-key"])
        await socket.push(try TVEnvelope(type: "registered", id: registration.id,
                                        payload: ["client-key": .string("new-key")]).text())
        let key = try await pairing.value
        XCTAssertEqual(key, "new-key")
        let after = await client.isConnected
        XCTAssertTrue(after)
        await client.disconnect()
    }

    func testSavedPairingKeyIsSentAndReused() async throws {
        let socket = FakeSocket { text, socket in
            let request = try decode(text)
            await socket.push(try TVEnvelope(type: "registered", id: request.id, payload: [:]).text())
        }
        let client = LGTVClient(factory: { _ in socket })
        let key = try await client.connect(to: endpoint(), clientKey: "saved-key")
        XCTAssertEqual(key, "saved-key")
        let requests = await socket.sent
        XCTAssertEqual(try decode(XCTUnwrap(requests.first)).payload?["client-key"]?.string, "saved-key")
        await client.disconnect()
    }

    func testDeniedPairingNeverEnablesControls() async throws {
        let socket = FakeSocket { text, socket in
            let request = try decode(text)
            await socket.push(try TVEnvelope(type: "error", id: request.id, error: "403 User rejected pairing").text())
        }
        let client = LGTVClient(factory: { _ in socket })
        do { _ = try await client.connect(to: endpoint(), clientKey: nil); XCTFail("Pairing must fail") }
        catch { XCTAssertTrue(error.localizedDescription.contains("rejected")) }
        let connected = await client.isConnected
        XCTAssertFalse(connected)
        do { _ = try await client.request("audio/volumeUp"); XCTFail("Must block controls") }
        catch { XCTAssertEqual(error as? RemoteError, .notPaired) }
    }

    func testOutOfOrderRepliesMatchTheCorrectRequests() async throws {
        let socket = FakeSocket { text, socket in try await registered(text, socket) }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        let volume = Task { try await client.request("audio/getVolume") }
        let apps = Task { try await client.request("com.webos.applicationManager/listApps") }
        try await socket.waitForSent(3)
        let requests = try await socket.sent.map(decode).filter { $0.type == "request" }
        for request in requests.reversed() {
            let payload: TVPayload = request.uri?.contains("getVolume") == true
                ? ["volume": .number(26)] : ["apps": .array([])]
            await socket.push(try TVEnvelope(type: "response", id: request.id, payload: payload).text())
        }
        let v = try await volume.value
        let a = try await apps.value
        XCTAssertEqual(v["volume"]?.number, 26)
        XCTAssertEqual(a["apps"]?.array, [])
        await client.disconnect()
    }

    func testTimeoutCleansUpAndNextCommandCanSucceed() async throws {
        let socket = FakeSocket { text, socket in try await registered(text, socket) }
        let client = LGTVClient(requestTimeout: 0.05, factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        do { _ = try await client.request("audio/getVolume"); XCTFail("Expected timeout") }
        catch { XCTAssertEqual(error as? RemoteError, .timedOut) }
        await socket.setHandler { text, socket in
            let request = try decode(text)
            await socket.push(try TVEnvelope(type: "response", id: request.id, payload: ["returnValue": .bool(true)]).text())
        }
        let response = try await client.request("audio/volumeUp")
        XCTAssertEqual(response["returnValue"]?.bool, true)
        await client.disconnect()
    }

    func testDisconnectResumesAnOutstandingCommand() async throws {
        let socket = FakeSocket { text, socket in try await registered(text, socket) }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        let command = Task { try await client.request("audio/getVolume") }
        try await socket.waitForSent(2)
        await client.disconnect()
        do { _ = try await command.value; XCTFail("Expected disconnect") }
        catch { XCTAssertEqual(error as? RemoteError, .disconnected) }
    }

    func testCancelledRequestDoesNotPoisonConnection() async throws {
        let socket = FakeSocket { text, socket in try await registered(text, socket) }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        let command = Task { try await client.request("audio/getVolume") }
        try await socket.waitForSent(2)
        command.cancel()
        do { _ = try await command.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        let connected = await client.isConnected
        XCTAssertTrue(connected)
        await client.disconnect()
    }

    func testTVCommandFailureIsNotReportedAsSuccess() async throws {
        let socket = FakeSocket { text, socket in
            let request = try decode(text)
            if request.type == "register" { try await registered(text, socket); return }
            await socket.push(try TVEnvelope(type: "response", id: request.id,
                                            payload: ["returnValue": .bool(false), "errorText": .string("Unsupported input")]).text())
        }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        do { _ = try await client.request("tv/switchInput"); XCTFail("Expected rejection") }
        catch { XCTAssertEqual(error.localizedDescription, "Unsupported input") }
        await client.disconnect()
    }

    func testNavigationUsesRemoteEnterToSelectTheFocusedItem() async throws {
        let pointer = FakeSocket()
        let control = FakeSocket { text, socket in
            let request = try decode(text)
            if request.type == "register" { try await registered(text, socket); return }
            await socket.push(try TVEnvelope(type: "response", id: request.id,
                                            payload: ["socketPath": .string("wss://192.168.1.50:3001/pointer")]).text())
        }
        let client = LGTVClient(factory: { url in url.path == "/pointer" ? pointer : control })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        try await client.press(.up)
        try await client.press(.ok)
        try await client.press(.back)
        let commands = await pointer.sent
        XCTAssertEqual(commands, ["type:button\nname:UP\n\n", "type:button\nname:ENTER\n\n", "type:button\nname:BACK\n\n"])
        let requests = try await control.sent.map(decode)
        XCTAssertEqual(requests.filter { $0.uri?.contains("getPointerInputSocket") == true }.count, 1)
        await client.disconnect()
    }

    func testUntrustedPointerAddressIsRejected() async throws {
        let control = FakeSocket { text, socket in
            let request = try decode(text)
            if request.type == "register" { try await registered(text, socket); return }
            await socket.push(try TVEnvelope(type: "response", id: request.id,
                                            payload: ["socketPath": .string("wss://example.com:3001/steal")]).text())
        }
        let client = LGTVClient(factory: { _ in control })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        do { try await client.press(.up); XCTFail("Must reject another host") }
        catch { XCTAssertTrue(error.localizedDescription.contains("unexpected")) }
        await client.disconnect()
    }

    func testBothVolumeFormatsAndDeviceLists() {
        XCTAssertEqual(TVVolume(["volume": .number(20), "mute": .bool(true)]).level, 20)
        let nested = TVVolume(["volumeStatus": .object(["volume": .number(31), "mute": .bool(false)])])
        XCTAssertEqual(nested.level, 31)
        XCTAssertEqual(nested.muted, false)
        XCTAssertNil(TVVolume(["volume": .number(999)]).level)
        XCTAssertNil(TVVolume([:]).muted)
        let apps = TVApp.parse(["apps": .array([
            .object(["id": .string("youtube"), "title": .string("YouTube")]),
            .object(["id": .string("netflix"), "title": .string("Netflix")]), .object([:])
        ])])
        XCTAssertEqual(apps.map(\.title), ["Netflix", "YouTube"])
        let inputs = TVInput.parse(["devices": .array([
            .object(["id": .string("HDMI_1"), "label": .string("Console"), "connected": .bool(true)])
        ])])
        XCTAssertEqual(inputs.first?.id, "HDMI_1")
        XCTAssertEqual(inputs.first?.connected, true)
    }

    func testPairingTimesOutWithoutAnApproval() async throws {
        let socket = FakeSocket()
        let client = LGTVClient(pairingTimeout: 0.05, factory: { _ in socket })
        do { _ = try await client.connect(to: endpoint(), clientKey: nil); XCTFail("Expected pairing timeout") }
        catch { XCTAssertEqual(error as? RemoteError, .timedOut) }
        let connected = await client.isConnected
        XCTAssertFalse(connected)
    }

    func testReconnectSurvivesTheOldSocketsShutdown() async throws {
        let first = FakeSocket { text, socket in try await registered(text, socket) }
        let second = FakeSocket { text, socket in try await registered(text, socket) }
        let queue = SocketQueue([first, second])
        let client = LGTVClient(factory: { _ in try await queue.next() })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        _ = try await client.connect(to: endpoint(), clientKey: "test-pair-key")
        await Task.yield()
        let connected = await client.isConnected
        XCTAssertTrue(connected)
        await client.disconnect()
    }

    func testSimultaneousNavigationSharesOnePointerConnection() async throws {
        let pointer = FakeSocket()
        let control = FakeSocket { text, socket in
            let request = try decode(text)
            if request.type == "register" { try await registered(text, socket); return }
            await socket.push(try TVEnvelope(type: "response", id: request.id,
                                            payload: ["socketPath": .string("wss://192.168.1.50:3001/pointer")]).text())
        }
        let client = LGTVClient(factory: { url in url.path == "/pointer" ? pointer : control })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        async let up: Void = client.press(.up)
        async let down: Void = client.press(.down)
        _ = try await (up, down)
        let messages = await pointer.sent
        XCTAssertEqual(messages.count, 2)
        let requests = try await control.sent.map(decode)
        XCTAssertEqual(requests.filter { $0.uri?.contains("getPointerInputSocket") == true }.count, 1)
        await client.disconnect()
    }

    func testKeyboardRegistersBeforeSendingAndSearchWaitsForTextAcknowledgement() async throws {
        let socket = FakeSocket { text, socket in
            let request = try decode(text)
            if request.uri?.hasSuffix("insertText") != true { try await keyboardReply(text, socket) }
        }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        let text = "  café \"jazz\" 🎵\n2026  "
        let sending = Task { try await client.sendText(text, submit: true) }
        try await socket.waitForSent(3)
        let before = try await socket.sent.map(decode)
        XCTAssertEqual(before.map(\.type), ["register", "subscribe", "request"])
        XCTAssertEqual(before[1].uri, "ssap://com.webos.service.ime/registerRemoteKeyboard")
        XCTAssertEqual(before[1].payload?["subscribe"], .bool(true))
        XCTAssertEqual(before[2].uri, "ssap://com.webos.service.ime/insertText")
        XCTAssertEqual(before[2].payload?["text"], .string(text))
        XCTAssertEqual(before[2].payload?["replace"], .number(0))
        await socket.push(try TVEnvelope(type: "response", id: before[2].id,
                                        payload: ["returnValue": .bool(true)]).text())
        try await sending.value
        let after = try await socket.sent.map(decode)
        XCTAssertEqual(after.count, 4)
        XCTAssertEqual(after.last?.uri, "ssap://com.webos.service.ime/sendEnterKey")
        await client.disconnect()
    }

    func testKeyboardTracksFocusChangesWithoutRepeatedSubscriptions() async throws {
        let socket = FakeSocket { text, socket in try await keyboardReply(text, socket, focused: false) }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        let initial = try await client.keyboardState()
        XCTAssertEqual(initial.focused, false)
        let requests = try await socket.sent.map(decode)
        let id = try XCTUnwrap(requests.last?.id)
        await socket.push(try TVEnvelope(type: "response", id: id,
                                        payload: ["currentWidget": .object(["focus": .bool(true)])]).text())
        _ = try await client.request("audio/getVolume") // Drain the earlier status update.
        let ready = try await client.keyboardState()
        XCTAssertEqual(ready.focused, true)
        try await client.sendText("test", submit: false)
        try await client.deleteTextCharacter()
        await socket.push(try TVEnvelope(type: "response", id: id,
                                        payload: ["currentWidget": .object(["focus": .bool(false)])]).text())
        _ = try await client.request("audio/getVolume")
        do { try await client.sendText("do not send", submit: true); XCTFail("Field is no longer focused") }
        catch { XCTAssertEqual((error as? TVTextSendError)?.textInserted, false) }
        let sent = try await socket.sent.map(decode)
        XCTAssertEqual(sent.filter { $0.type == "subscribe" }.count, 1)
        XCTAssertEqual(sent.filter { $0.uri?.hasSuffix("insertText") == true }.count, 1)
        XCTAssertEqual(sent.first { $0.uri?.hasSuffix("deleteCharacters") == true }?.payload?["count"], .number(1))
        await client.disconnect()
    }

    func testKeyboardAcknowledgementWithoutFieldDoesNotEnableTyping() async throws {
        let socket = FakeSocket { text, socket in try await keyboardReply(text, socket, focused: nil) }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        let state = try await client.keyboardState()
        XCTAssertNil(state.focused)
        do { try await client.sendText("private draft", submit: true); XCTFail("Unknown field must not receive text") }
        catch { XCTAssertEqual((error as? TVTextSendError)?.textInserted, false) }
        let sent = try await socket.sent.map(decode)
        XCTAssertFalse(sent.contains { $0.uri?.hasSuffix("insertText") == true || $0.uri?.hasSuffix("sendEnterKey") == true })
        await client.disconnect()
    }

    func testRejectedTextDoesNotSendSearchOrReportInsertion() async throws {
        let socket = FakeSocket { text, socket in
            let request = try decode(text)
            if request.uri?.hasSuffix("insertText") == true {
                await socket.push(try TVEnvelope(type: "response", id: request.id,
                    payload: ["returnValue": .bool(false), "errorText": .string("Input unavailable")]).text())
            } else { try await keyboardReply(text, socket) }
        }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        do { try await client.sendText("query", submit: true); XCTFail("Expected failure") }
        catch {
            XCTAssertEqual((error as? TVTextSendError)?.textInserted, false)
            XCTAssertEqual(error.localizedDescription, "Input unavailable")
        }
        let sent = try await socket.sent.map(decode)
        XCTAssertFalse(sent.contains { $0.uri?.hasSuffix("sendEnterKey") == true })
        await client.disconnect()
    }

    func testSearchFailureReportsAcceptedTextWithoutResendingIt() async throws {
        let socket = FakeSocket { text, socket in
            let request = try decode(text)
            if request.uri?.hasSuffix("sendEnterKey") == true {
                await socket.push(try TVEnvelope(type: "error", id: request.id, error: "Search unavailable").text())
            } else { try await keyboardReply(text, socket) }
        }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        do { try await client.sendText("query", submit: true); XCTFail("Expected failure") }
        catch {
            XCTAssertEqual((error as? TVTextSendError)?.textInserted, true)
            XCTAssertEqual(error.localizedDescription, "Search unavailable")
        }
        let sent = try await socket.sent.map(decode)
        XCTAssertEqual(sent.filter { $0.uri?.hasSuffix("insertText") == true }.count, 1)
        await client.disconnect()
    }

    func testKeyboardRecheckUnsubscribesAndIgnoresTheOldField() async throws {
        let socket = FakeSocket { text, socket in try await keyboardReply(text, socket) }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        _ = try await client.keyboardState()
        let oldRequests = try await socket.sent.map(decode)
        let oldID = try XCTUnwrap(oldRequests.last?.id)
        await client.resetKeyboard()
        await socket.setHandler { text, socket in try await keyboardReply(text, socket, focused: false) }
        _ = try await client.keyboardState()
        await socket.push(try TVEnvelope(type: "response", id: oldID,
                                        payload: ["currentWidget": .object(["focus": .bool(true)])]).text())
        _ = try await client.request("audio/getVolume")
        let state = try await client.keyboardState()
        XCTAssertEqual(state.focused, false)
        let sent = try await socket.sent.map(decode)
        XCTAssertEqual(sent.first { $0.type == "unsubscribe" }?.id, oldID)
        XCTAssertEqual(sent.filter { $0.type == "subscribe" }.count, 2)
        await client.disconnect()
    }

    func testKeyboardSubscriptionErrorDoesNotDisableOtherControls() async throws {
        let socket = FakeSocket { text, socket in
            let request = try decode(text)
            if request.type == "subscribe" {
                await socket.push(try TVEnvelope(type: "error", id: request.id, error: "403 Keyboard unavailable").text())
            } else { try await keyboardReply(text, socket) }
        }
        let client = LGTVClient(factory: { _ in socket })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        for _ in 0..<2 {
            do { _ = try await client.keyboardState(); XCTFail("Expected keyboard rejection") }
            catch { XCTAssertTrue(error.localizedDescription.contains("403")) }
        }
        _ = try await client.request("audio/volumeDown")
        let sent = try await socket.sent.map(decode)
        XCTAssertEqual(sent.filter { $0.type == "subscribe" }.count, 1)
        let connected = await client.isConnected
        XCTAssertTrue(connected)
        await client.disconnect()
    }

    func testReconnectDoesNotReuseTheOldKeyboardFocus() async throws {
        let first = FakeSocket { text, socket in try await keyboardReply(text, socket) }
        let second = FakeSocket { text, socket in try await keyboardReply(text, socket, focused: false) }
        let queue = SocketQueue([first, second])
        let client = LGTVClient(factory: { _ in try await queue.next() })
        _ = try await client.connect(to: endpoint(), clientKey: nil)
        _ = try await client.keyboardState()
        _ = try await client.connect(to: endpoint(), clientKey: "test-pair-key")
        do { try await client.sendText("do not send", submit: false); XCTFail("Old focus must be discarded") }
        catch { XCTAssertEqual((error as? TVTextSendError)?.textInserted, false) }
        let sent = try await second.sent.map(decode)
        XCTAssertEqual(sent.map(\.type), ["register", "subscribe"])
        await client.disconnect()
    }
}
