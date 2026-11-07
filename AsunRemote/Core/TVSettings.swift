import Foundation

enum TVSettingsSection: String, CaseIterable, Identifiable, Sendable {
    case all, picture, sound, channels, connection, general, safety, accessibility
    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All Settings"
        case .picture: return "Picture"
        case .sound: return "Sound"
        case .channels: return "Channels"
        case .connection: return "Connection"
        case .general: return "General"
        case .safety: return "Safety"
        case .accessibility: return "Accessibility"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "gearshape"
        case .picture: return "tv"
        case .sound: return "speaker.wave.2"
        case .channels: return "antenna.radiowaves.left.and.right"
        case .connection: return "network"
        case .general: return "wrench.and.screwdriver"
        case .safety: return "lock"
        case .accessibility: return "accessibility"
        }
    }

    var target: String? {
        switch self {
        case .all, .safety: return nil
        case .picture: return "picture"
        case .sound: return "sound"
        case .channels: return "channel"
        case .connection: return "network"
        case .general: return "general"
        case .accessibility: return "accessibility"
        }
    }

    var launchPayload: TVPayload {
        var payload: TVPayload = ["id": .string("com.palm.app.settings")]
        if let target { payload["params"] = .object(["target": .string(target)]) }
        // No verified Safety deep link: open real All Settings, then let the
        // user select Safety. Never automate PIN changes, resets, or updates.
        return payload
    }

    var acceptedMessage: String {
        self == .safety
            ? "Settings request accepted. Select Safety on your TV using the arrows below."
            : "Settings request accepted. Check your TV for \(title). If another page opens, select \(title) with the arrows below."
    }
}

enum TVAudioOutput: String, CaseIterable, Identifiable, Sendable {
    case tvSpeakers = "tv_speaker", bluetooth = "bt_soundbar"
    var id: Self { self }
    var title: String { self == .tvSpeakers ? "TV speakers" : "Bluetooth audio" }
    var symbol: String { self == .tvSpeakers ? "tv" : "headphones" }
}

struct TVAudioStatus: Equatable, Sendable {
    let output: TVAudioOutput?
    var title: String { output?.title ?? "Other TV audio output" }

    init(_ payload: TVPayload) throws {
        guard let value = payload["soundOutput"]?.string, !value.isEmpty else {
            throw RemoteError.message("The TV did not report its sound output.")
        }
        // An unrecognized output is not evidence of either speakers or Bluetooth.
        output = TVAudioOutput(rawValue: value)
    }
}

enum TVAudioChangeResult: Sendable {
    case reported(TVAudioStatus)
    case acceptedUnverified(String)
}
