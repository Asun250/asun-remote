import Foundation
import Darwin

/// Bounded, nonblocking UDP unicast on the TV's directly attached IPv4 LAN.
/// No multicast/broadcast entitlement is requested or bypassed. A successful send
/// means the OS accepted a datagram; it does not confirm that the TV received it.
enum TVWakeSender {
    @MainActor
    static func send(to endpoint: TVEndpoint, mac: TVMACAddress) async throws {
        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = UInt16(9).bigEndian
        guard inet_pton(AF_INET, endpoint.host, &destination.sin_addr) == 1 else {
            throw RemoteError.message("Check the TV’s IP address.")
        }
        let interface = try localInterface(for: UInt32(bigEndian: destination.sin_addr.s_addr))
        let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else { throw networkError() }
        defer { Darwin.close(descriptor) }

        var index = interface
        guard withUnsafePointer(to: &index, { setsockopt(descriptor, IPPROTO_IP, IP_BOUND_IF, $0, socklen_t(MemoryLayout<UInt32>.size)) }) == 0,
              fcntl(descriptor, F_SETFL, O_NONBLOCK) != -1 else { throw networkError() }

        let packet = mac.magicPacket
        for attempt in 0..<3 {
            try Task.checkCancellation()
            let count = packet.withUnsafeBytes { data in
                withUnsafePointer(to: &destination) { address in
                    address.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.sendto(descriptor, data.baseAddress, data.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
            guard count == packet.count else { throw networkError() }
            if attempt < 2 { try await Task.sleep(nanoseconds: 250_000_000) }
        }
    }

    private static func localInterface(for target: UInt32) throws -> UInt32 {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { throw networkError() }
        defer { freeifaddrs(interfaces) }
        var cursor = interfaces
        while let current = cursor {
            let entry = current.pointee
            cursor = entry.ifa_next
            guard entry.ifa_flags & UInt32(IFF_UP) != 0,
                  entry.ifa_flags & UInt32(IFF_BROADCAST) != 0,
                  entry.ifa_flags & UInt32(IFF_LOOPBACK | IFF_POINTOPOINT) == 0,
                  let address = entry.ifa_addr, address.pointee.sa_family == sa_family_t(AF_INET),
                  let netmask = entry.ifa_netmask, netmask.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let local = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            let mask = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            if WakeNetwork.permits(target: target, local: local, mask: mask) {
                let index = if_nametoindex(entry.ifa_name)
                if index != 0 { return index }
            }
        }
        throw RemoteError.message("Join the same home Wi-Fi network as the TV and check its IP address. Power-on testing needs a direct local network connection.")
    }

    private static func networkError() -> RemoteError {
        let code = errno
        if code == EACCES || code == EPERM {
            return .message("The iPhone blocked the wake request. Allow Asun Remote in Settings → Privacy & Security → Local Network, then try again.")
        }
        return .message("Could not send the wake request (network error \(code)). Check Wi-Fi and try again. The TV’s power state is unknown.")
    }
}
