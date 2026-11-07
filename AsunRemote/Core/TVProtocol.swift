import Foundation

enum RemoteError: Error, LocalizedError, Equatable, Sendable {
    case message(String)
    case disconnected
    case notPaired
    case timedOut

    var errorDescription: String? {
        switch self {
        case .message(let message): return message
        case .disconnected: return "The TV connection closed. Check that the TV is on, then reconnect."
        case .notPaired: return "Connect and approve pairing on your TV first."
        case .timedOut: return "The TV did not respond. Check the TV screen for a pairing request."
        }
    }
}

enum ConnectionMode: String, CaseIterable, Codable, Sendable {
    case secure, legacy
    var port: Int { self == .secure ? 3001 : 3000 }
    var scheme: String { self == .secure ? "wss" : "ws" }
    var label: String { self == .secure ? "Secure (recommended)" : "Legacy compatibility" }
}

struct TVEndpoint: Equatable, Sendable {
    let host: String
    let mode: ConnectionMode
    var url: URL { URL(string: "\(mode.scheme)://\(host):\(mode.port)")! }
    var storageKey: String { "\(mode.rawValue):\(host)" }

    init(address: String, mode: ConnectionMode) throws {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4,
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy({ (48...57).contains($0) }) }),
              parts.allSatisfy({ $0.count == 1 || !$0.hasPrefix("0") }) else {
            throw RemoteError.message("Enter the TV’s local IP address, such as 192.168.1.50, without a port or web address.")
        }
        let octets = parts.compactMap { UInt8($0) }
        guard octets.count == 4 else { throw RemoteError.message("Each part of an IP address must be between 0 and 255.") }
        let privateAddress = octets[0] == 10
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
            || (octets[0] == 169 && octets[1] == 254)
        guard privateAddress else { throw RemoteError.message("Use the TV’s private home-network IPv4 address.") }
        host = value
        self.mode = mode
    }

    func validatedPointerURL(_ value: String) throws -> URL {
        guard let url = URL(string: value), url.scheme == mode.scheme,
              url.host == host, url.port == mode.port,
              url.user == nil, url.password == nil, url.fragment == nil,
              !url.path.isEmpty else {
            throw RemoteError.message("The TV returned an unexpected remote-control address. Reconnect to your TV.")
        }
        return url
    }
}

enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? value.decode(Double.self) { self = .number(number) }
        else if let string = try? value.decode(String.self) { self = .string(string) }
        else if let object = try? value.decode([String: JSONValue].self) { self = .object(object) }
        else { self = .array(try value.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let item): try value.encode(item)
        case .number(let item): try value.encode(item)
        case .bool(let item): try value.encode(item)
        case .object(let item): try value.encode(item)
        case .array(let item): try value.encode(item)
        case .null: try value.encodeNil()
        }
    }

    var string: String? { if case .string(let value) = self { return value }; return nil }
    var number: Double? { if case .number(let value) = self { return value }; return nil }
    var bool: Bool? { if case .bool(let value) = self { return value }; return nil }
    var object: [String: JSONValue]? { if case .object(let value) = self { return value }; return nil }
    var array: [JSONValue]? { if case .array(let value) = self { return value }; return nil }
}

typealias TVPayload = [String: JSONValue]

struct TVEnvelope: Codable, Sendable {
    var type: String
    var id: String?
    var uri: String?
    var payload: TVPayload?
    var error: String?

    func text() throws -> String { String(decoding: try JSONEncoder().encode(self), as: UTF8.self) }
}

enum TVProtocol {
    // Only capabilities used by this remote. No TV developer mode or private signing manifest.
    static let permissions = [
        "LAUNCH", "CONTROL_AUDIO", "CONTROL_INPUT_MEDIA_PLAYBACK", "CONTROL_POWER",
        "READ_INSTALLED_APPS", "CONTROL_DISPLAY", "CONTROL_INPUT_JOYSTICK",
        "CONTROL_INPUT_TV", "READ_INPUT_DEVICE_LIST", "CONTROL_MOUSE_AND_KEYBOARD",
        "CONTROL_INPUT_TEXT"
    ]

    static func registration(id: String, clientKey: String?) -> TVEnvelope {
        var payload: TVPayload = [
            "pairingType": .string("PROMPT"),
            "forcePairing": .bool(false),
            "manifest": .object([
                "manifestVersion": .number(1),
                "appVersion": .string("1.4.0"),
                "appId": .string("com.asunstudios.remote"),
                "vendorId": .string("Asun Studios"),
                "localizedAppNames": .object(["": .string("Asun Remote")]),
                "permissions": .array(permissions.map(JSONValue.string))
            ])
        ]
        if let clientKey, !clientKey.isEmpty { payload["client-key"] = .string(clientKey) }
        return TVEnvelope(type: "register", id: id, payload: payload)
    }
}

enum RemoteButton: String, CaseIterable, Sendable {
    case up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT"
    case home = "HOME", back = "BACK", menu = "MENU", ok = "ENTER"
    var wireMessage: String {
        // OK selects the focused item, like the physical remote. A pointer click
        // targets the cursor position and can miss focused streaming-app profiles.
        "type:button\nname:\(rawValue)\n\n"
    }
}

struct TVApp: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let youTubeSearchParameter: YouTubeSearchParameter?

    init(id: String, title: String, youTubeSearchParameter: YouTubeSearchParameter? = nil) {
        self.id = id
        self.title = title
        self.youTubeSearchParameter = youTubeSearchParameter
    }
    static func parse(_ payload: TVPayload) -> [TVApp] {
        (payload["apps"]?.array ?? []).compactMap { item in
            guard let data = item.object, let id = data["id"]?.string, !id.isEmpty else { return nil }
            return TVApp(id: id, title: data["title"]?.string ?? id,
                         youTubeSearchParameter: id == YouTubeSearch.appID
                            ? YouTubeSearchParameter.advertised(in: data["inAppSearchParams"]?.string) : nil)
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}

struct TVInput: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let connected: Bool
    static func parse(_ payload: TVPayload) -> [TVInput] {
        (payload["devices"]?.array ?? []).compactMap { item in
            guard let data = item.object, let id = data["id"]?.string, !id.isEmpty else { return nil }
            return TVInput(id: id, title: data["label"]?.string ?? id, connected: data["connected"]?.bool ?? false)
        }
    }
}

struct TVVolume: Equatable, Sendable {
    let level: Int?
    let muted: Bool?
    init(_ payload: TVPayload) {
        let data = payload["volumeStatus"]?.object ?? payload
        if let number = data["volume"]?.number, number.isFinite, (0...100).contains(number) {
            level = Int(number)
        } else { level = nil }
        muted = data["mute"]?.bool ?? data["muted"]?.bool
    }
}

struct TVKeyboardStatus: Equatable, Sendable {
    let focused: Bool?

    init(_ payload: TVPayload = [:]) {
        // A registration acknowledgement can arrive before any field status.
        // Missing focus must not be interpreted as a ready text field.
        focused = payload["currentWidget"]?.object?["focus"]?.bool
    }
}

struct TVTextSendError: Error, LocalizedError, Sendable {
    let textInserted: Bool
    let detail: String
    var errorDescription: String? { detail }
}

enum YouTubeSearchParameter: String, Sendable {
    case contentTarget, target
    var alternate: YouTubeSearchParameter { self == .contentTarget ? .target : .contentTarget }

    static func advertised(in template: String?) -> YouTubeSearchParameter? {
        guard let data = template?.data(using: .utf8),
              let fields = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
        // Use only the two documented query formats, never arbitrary TV-supplied
        // keys, URLs, launch destinations, or executable templates.
        for candidate in [Self.contentTarget, .target] {
            if fields[candidate.rawValue] == "q=$SEARCH_KEYWORD" { return candidate }
        }
        return nil
    }
}

enum YouTubeSearch {
    static let appID = "youtube.leanback.v4"

    static func payload(query: String, parameter: YouTubeSearchParameter) throws -> TVPayload {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count <= 500 else {
            throw RemoteError.message("Enter a YouTube search of 1 to 500 characters.")
        }
        // YouTube receives a query-string target. Encode the entire value so
        // ampersands, plus signs, Unicode, and pasted text remain one query.
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw RemoteError.message("This search text could not be encoded.")
        }
        return ["id": .string(appID), "params": .object([parameter.rawValue: .string("q=" + encoded)])]
    }
}
