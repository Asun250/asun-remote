import XCTest
@testable import RemoteCore

final class WakeOnLANTests: XCTestCase {
    func testMACFormatsProduceStandardMagicPacket() throws {
        let expected = "ffffffffffff" + "a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5"
            + "a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5"
            + "a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5"
            + "a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5"
        for text in ["a0:b1:c2:d3:e4:f5", "A0-B1-C2-D3-E4-F5", "a0b1c2d3e4f5", " A0:B1:C2:D3:E4:F5\n"] {
            let mac = try TVMACAddress(text)
            XCTAssertEqual(mac.formatted, "A0:B1:C2:D3:E4:F5")
            XCTAssertEqual(mac.magicPacket.count, 102)
            XCTAssertEqual(mac.magicPacket.map { String(format: "%02x", $0) }.joined(), expected)
        }
    }

    func testRejectsMalformedMulticastAndEmptyMACAddresses() {
        for value in ["", "192.168.1.50", "A0:B1:C2:D3:E4", "A0:B1:C2:D3:E4:F500", "0:B1:C2:D3:E4:F5",
                      "A0:B1-C2:D3:E4:F5", "A0:B1:C2:D3:E4:GG", "00:00:00:00:00:00", "FF:FF:FF:FF:FF:FF",
                      "01:00:5E:00:00:01", "A0 B1 C2 D3 E4 F5", "A0:B1:C2:D3:E4:F5:anything"] {
            XCTAssertThrowsError(try TVMACAddress(value), value)
        }
        XCTAssertNoThrow(try TVMACAddress("02:11:22:33:44:55")) // Locally administered unicast is valid.
    }

    func testWakeStaysOnLANAndRejectsSelfNetworkAndBroadcast() {
        let phone: UInt32 = 0xC0A8010A // 192.168.1.10/24
        let mask: UInt32 = 0xFFFFFF00
        XCTAssertTrue(WakeNetwork.permits(target: 0xC0A80132, local: phone, mask: mask))
        for target in [UInt32(0xC0A80100), 0xC0A801FF, phone, 0xC0A80232, 0x08080808, 0xFFFFFFFF] {
            XCTAssertFalse(WakeNetwork.permits(target: target, local: phone, mask: mask))
        }
        // Do not assume /24: .255 is a host in this /23, .1.255 is the broadcast.
        XCTAssertTrue(WakeNetwork.permits(target: 0xC0A800FF, local: phone, mask: 0xFFFFFE00))
        XCTAssertFalse(WakeNetwork.permits(target: 0xC0A801FF, local: phone, mask: 0xFFFFFE00))
    }

    func testRejectsPointToPointAndInvalidMasks() {
        for mask in [UInt32(0), 0xFFFFFFFF, 0xFFFFFFFE, 0xFFFF00FF, 0xFF00FF00] {
            XCTAssertFalse(WakeNetwork.permits(target: 0xC0A80132, local: 0xC0A8010A, mask: mask))
        }
    }
}
