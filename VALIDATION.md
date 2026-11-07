# Validation — Asun Remote 1.2

Updated November 6, 2026 (Pacific time). Target family: LG webOS UM6970PUA.

## Current update: v1.2

The user reports that OK reacts but does not open the selected YouTube/Netflix profile, and Volume Down only works occasionally. The installed version number was not confirmed. App launch and some TV communication are now evidenced by the user's report; it does not establish correct profile selection or reliable volume control.

Code inspection found that OK sent `type:click`, while the D-pad moves focus. It now sends a single `type:button` with `name:ENTER`. The existing navigation regression test checks Up → Enter → Back over one pointer socket and the exact framing. The volume rocker labels had no explicit hit shape around their small glyphs; each now has a full-width, 48-point-high rectangular hit area. Other drawn buttons have explicit matching hit shapes.

The existing 19 core tests and complete iOS build will run for this update. No automated UI or physical-TV test has been run for the corrected tap areas. On-device checks must cover both streaming apps and taps around the minus glyph. Power-on remains experimental; the user found the physical power button sufficient for turning the TV on.

## Version 1.1 validation history

Version 1.1 adds MAC parsing and a standard 102-byte Wake-on-LAN packet; a nonblocking, interface-bound UDP unicast sender; per-IP MAC storage; and an explicitly experimental power-on control accessible while disconnected. Three requests go to UDP port 9, 250 ms apart. Targets must be directly attached local IPv4 hosts; network, broadcast, self, off-subnet, point-to-point, and invalid-mask destinations are rejected. No multicast/broadcast entitlement is added.

Four new tests cover MAC normalization and packet bytes, malformed/multicast MAC rejection, same-LAN constraints including a /23 boundary, and invalid/point-to-point masks. The existing 15 tests cover pairing, cancellation, request ordering/timeouts, navigation, reconnect isolation, and TV response parsing.

The previous Linux Swift toolchain is no longer available in this workspace. Validation used the cloud Mac's real Swift compiler. All **19 core tests passed with zero failures** (15 existing + 4 wake tests), and the complete iOS Release build succeeded. Local structural checks passed for both plists, the 11 app/core source paths, Xcode object references, version 1.1.0 (2), and the count of 19 test methods. These checks do not compile Swift or run the tests.

The user explicitly approved uploading the update to the existing private Asun250/asun-remote repository and running its existing iPhone cloud build. The upload and build completed successfully.

## Physical verification still required

- Corrected v1.2 tap areas and streaming-app profile selection; native layout and accessibility.
- Keychain/TLS persistence and reliable behavior of all remote commands on this TV.
- Wake request acceptance by the signed iOS app with Local Network permission.
- Actual power-on after short standby, 15 minutes, and overnight. The app cannot infer screen power from successful UDP transmission. A later registered TV session confirms connectivity only.
- Unicast wake can fail after ARP cache expiry or deeper standby. These limits remain even if all automated tests and compilation pass.

Do not report reliable power on, off, or complete remote replacement as hardware-verified until the user performs those checks. Use the TV's physical power button as fallback during testing.

## Prior build and installation evidence

The [v1.0 cloud run](https://github.com/Asun250/asun-remote/actions/runs/42342321883), commit `09f1ec6f2072fdd5112e82fd927f84948c66638a`, passed 15 core tests and the full unsigned iPhoneOS 18.5 arm64 build with Xcode 16.4 / Apple Swift 6.1.2. The original IPA SHA-256 was `218f802d84b8de5327c1dd7d073b2050689db5fb21088fb53902c87afc6c9a04`.

The user connected the iPhone through a rear PC USB port and provided a Sideloadly screenshot showing Done / 100%. They enabled Developer Mode and restarted the phone. At that point app opening and TV pairing had not yet been confirmed; the later v1.2 bug report provides evidence of app use and some TV communication.

## Successful v1.1 build

- [Cloud run #3](https://github.com/Asun250/asun-remote/actions/runs/42345317807) built source commit `e5c0da8420704e144c12aa576ebb68215998dbeb`.
- Xcode 16.4, Apple Swift 6.1.2; 19 tests, zero failures; full arm64 iPhone app compiled.
- Artifact archive SHA-256: `0f37d03dd9ff98c2fdf24164a0c260b8977df1ded5b325b6e0aa553b25458f34`.
- IPA SHA-256: `361fed2f7047209ce9e718bd05cadd7cc0a3e3f1398c8ca5d92a8d4464757fbc`; 326,401 bytes.
- Archive and IPA integrity checked. Embedded bundle identifier `com.markanthony.asunremote`, version `1.1.0`, build `2`, iPhoneOS platform, minimum iOS 17.0, and arm64 Mach-O executable confirmed.
- The compiled IPA is unchanged when packaging the updated Windows instructions.

These results prove compilation and simulated protocol behavior, not physical standby wake. No wake test has yet been performed on the user's TV.
