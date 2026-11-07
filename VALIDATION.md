# Validation — Asun Remote 1.1

Updated November 6, 2026 (Pacific time). Target family: LG webOS UM6970PUA.

## Current update

Version 1.1 adds MAC parsing and a standard 102-byte Wake-on-LAN packet; a nonblocking, interface-bound UDP unicast sender; per-IP MAC storage; and an explicitly experimental power-on control accessible while disconnected. Three requests go to UDP port 9, 250 ms apart. Targets must be directly attached local IPv4 hosts; network, broadcast, self, off-subnet, point-to-point, and invalid-mask destinations are rejected. No multicast/broadcast entitlement is added.

Four new tests cover MAC normalization and packet bytes, malformed/multicast MAC rejection, same-LAN constraints including a /23 boundary, and invalid/point-to-point masks. The existing 15 tests cover pairing, cancellation, request ordering/timeouts, navigation, reconnect isolation, and TV response parsing.

The previous Linux Swift toolchain is no longer available in this workspace. Validation for this update will use the cloud Mac's real Swift compiler, 19 core tests, and the complete iOS Release build. Results are pending; do not substitute the previous v1.0 artifact for v1.1. Local structural checks passed for both plists, the 11 app/core source paths, Xcode object references, version 1.1.0 (2), and the count of 19 test methods. These checks do not compile Swift or run the tests.

The user explicitly approved uploading the update to the existing private Asun250/asun-remote repository and running its existing iPhone cloud build. The updated build results will be recorded below.

## Physical verification still required

- App launch after Developer Mode is enabled; native layout and accessibility.
- Pairing, Keychain/TLS persistence, and actual remote commands on this TV.
- Wake request acceptance by the signed iOS app with Local Network permission.
- Actual power-on after short standby, 15 minutes, and overnight. The app cannot infer screen power from successful UDP transmission. A later registered TV session confirms connectivity only.
- Unicast wake can fail after ARP cache expiry or deeper standby. These limits remain even if all automated tests and compilation pass.

Do not report reliable power on, off, or complete remote replacement as hardware-verified until the user performs those checks. Use the TV's physical power button as fallback during testing.

## Prior build and installation evidence

The [v1.0 cloud run](https://github.com/Asun250/asun-remote/actions/runs/42342321883), commit `09f1ec6f2072fdd5112e82fd927f84948c66638a`, passed 15 core tests and the full unsigned iPhoneOS 18.5 arm64 build with Xcode 16.4 / Apple Swift 6.1.2. The original IPA SHA-256 was `218f802d84b8de5327c1dd7d073b2050689db5fb21088fb53902c87afc6c9a04`.

The user connected the iPhone through a rear PC USB port and provided a Sideloadly screenshot showing Done / 100%. They enabled Developer Mode and restarted the phone. The app opening and TV pairing have not yet been confirmed.
