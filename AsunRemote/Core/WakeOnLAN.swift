import Foundation

/// A unicast device address, never a broadcast/multicast target MAC.
struct TVMACAddress: Equatable, Sendable {
    let bytes: [UInt8]
    var formatted: String { bytes.map { String(format: "%02X", $0) }.joined(separator: ":") }

    init(_ text: String) throws {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact: String
        if value.contains(":") || value.contains("-") {
            let separator: Character = value.contains(":") ? ":" : "-"
            let parts = value.split(separator: separator, omittingEmptySubsequences: false)
            guard parts.count == 6, parts.allSatisfy({ $0.count == 2 }) else {
                throw RemoteError.message("Enter all six pairs of the TV’s MAC address, such as A0:B1:C2:D3:E4:F5.")
            }
            compact = parts.joined()
        } else { compact = value }
        let chars = Array(compact.utf8)
        guard chars.count == 12, chars.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else {
            throw RemoteError.message("A MAC address contains 12 hexadecimal characters. Copy the TV’s Wi-Fi or Ethernet MAC, not its IP address.")
        }
        let parsed = stride(from: 0, to: 12, by: 2).compactMap {
            UInt8(String(decoding: chars[$0..<($0 + 2)], as: UTF8.self), radix: 16)
        }
        guard parsed.count == 6, parsed[0] & 1 == 0, parsed.contains(where: { $0 != 0 }) else {
            throw RemoteError.message("Use the MAC address of your TV’s active network connection.")
        }
        bytes = parsed
    }

    /// The standard 102-byte magic packet: six FF bytes, then 16 copies of the MAC.
    var magicPacket: Data {
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }
        return packet
    }
}

enum WakeNetwork {
    /// Numeric IPv4 values in host byte order. Reject network/broadcast addresses and
    /// off-subnet routes so a wake attempt stays on the selected local LAN.
    static func permits(target: UInt32, local: UInt32, mask: UInt32) -> Bool {
        let hosts = ~mask
        guard mask != 0, hosts >= 3, hosts & (hosts &+ 1) == 0 else { return false }
        return target & mask == local & mask && target != local
            && target & hosts != 0 && target & hosts != hosts
    }
}
