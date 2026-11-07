# Validation — Asun Remote 1.4

Updated November 7, 2026 (UTC). Target family: LG webOS UM6970PUA.

## Current update: v1.4

The user installed v1.3 and confirmed that YouTube still does not expose a text field, including after Refresh. Version 1.4 adds a default YouTube destination in the keyboard sheet. It launches `youtube.leanback.v4` with a percent-encoded `q=` query in `contentTarget`, using the installed app's recognized `inAppSearchParams` metadata when available. An explicit Compatibility search button tries the other known parameter (`target` or `contentTarget`); it never retries automatically. The LG-native TV field mode retains its focused-field guard.

The phone query is retained after launch acknowledgement because the TV's acknowledgement cannot confirm visible YouTube results. This is direct search, not insertion into the current field. No new permissions, external relay, TV debugging, root access, or account credentials are introduced.

Five regression tests cover single-query encoding and length limits, direct search without keyboard registration, search with an explicitly unfocused IME, launch rejection without automatic retry, and recognition of only supported YouTube metadata. The previous 27 tests remain. All 32 core tests passed with zero failures, and the complete Release iPhone app compiled successfully. No v1.4 physical-TV or simulator UI test has been performed.

## Successful v1.4 build

- [Cloud run #6](https://github.com/Asun250/asun-remote/actions/runs/42349121400) built source commit `349ce2400a762db303c875d8c4a266e609053d04`.
- 32 core tests, zero failures; unsigned Release iPhone build successful.
- Artifact ZIP: 378,803 bytes; SHA-256 `002765372ac24a1abd166025023e9b65ba5fae165ce4960afa5ce636bb4dbd31`.
- IPA: 379,053 bytes; SHA-256 `d44fe484b343c2b8e699e97a94cc9f0330a439e870a5fe67fcd11d6887f397bb`.
- ZIP and IPA integrity, version 1.4.0 (5), bundle identifier `com.markanthony.asunremote`, iPhoneOS platform, minimum iOS 17.0, and arm64 Mach-O executable verified.
- Verified IPA copied to `C:\Asun remote app\AsunRemote-v1.4.ipa` with the same SHA-256. The distributed ZIP is the unchanged cloud artifact.
- The user requested public visibility; GitHub's repository settings confirmed the repository is public.

## Version 1.3 history

The user confirmed v1.2 works and then reported that typing in YouTube Search does not work. Code inspection found no `registerRemoteKeyboard` subscription, no focused-field detection, and a separate Enter / Search action that could submit without first sending the phone draft.

The update establishes a session-scoped keyboard subscription, processes ongoing `currentWidget.focus` events, and clears keyboard state on reconnect. Sending requires a reported focused field. Send & Search waits for insertion acknowledgement before Enter. If Enter fails after acknowledged insertion, the UI clears the sent draft and reports the partial result so retry does not append it twice. Rejected or unconfirmed text remains in the draft. The keyboard UI reports readiness, progress, errors, and the distinction between editing the phone draft and deleting a TV character.

Eight new protocol tests cover registration/insertion/submission ordering with Unicode and whitespace, ongoing focus changes, an acknowledgement without field status, insertion failure, partial success, unsubscribing/rechecking with stale events, keyboard-service rejection without breaking volume commands, and reconnect isolation. All **27 core tests passed with zero failures**, and the complete Release iPhone build succeeded.

After installation, the user tested YouTube and confirmed no text field is detected, even after refreshing. The v1.3 route did not solve YouTube input. An LG browser field and simulator UI have not been tested.

## Successful v1.3 build

- [Cloud run #5](https://github.com/Asun250/asun-remote/actions/runs/42347538818) built source commit `bf6117287ef4aca7c041390b3858c8b94eee61eb`.
- 27 core tests, zero failures; unsigned Release iPhone build successful.
- Artifact ZIP: 360,488 bytes; SHA-256 `5e6ce1b2d081b49510a560a051334f1c80ef0a0428da9590f562b7cd49d66f16`.
- IPA: 360,026 bytes; SHA-256 `8417ed186e6bae412a180812d28d9d9c9f61c042ecbc38580c9604d2040f89dc`.
- ZIP/IPA integrity, embedded version 1.3.0 (4), bundle identifier `com.markanthony.asunremote`, iPhoneOS platform, minimum iOS 17.0, and arm64 executable verified.
- Verified IPA copied to `C:\Asun remote app\AsunRemote-v1.3.ipa` with the same SHA-256. The distributed ZIP is the unchanged cloud artifact.

## Version 1.2 history

The user reports that OK reacts but does not open the selected YouTube/Netflix profile, and Volume Down only works occasionally. The installed version number was not confirmed. App launch and some TV communication are now evidenced by the user's report; it does not establish correct profile selection or reliable volume control.

Code inspection found that OK sent `type:click`, while the D-pad moves focus. It now sends a single `type:button` with `name:ENTER`. The existing navigation regression test checks Up → Enter → Back over one pointer socket and the exact framing. The volume rocker labels had no explicit hit shape around their small glyphs; each now has a full-width, 48-point-high rectangular hit area. Other drawn buttons have explicit matching hit shapes.

All 19 core tests passed with zero failures, including the updated Up → Enter → Back check, and the complete iOS Release build succeeded. No automated UI or physical-TV test has been run for the corrected tap areas. On-device checks must cover both streaming apps and taps around the minus glyph. Power-on remains experimental; the user found the physical power button sufficient for turning the TV on.

## Successful v1.2 build

- [Cloud run #4](https://github.com/Asun250/asun-remote/actions/runs/42346339029) built source commit `e9ec42a9e847f758cf51caabfa1b1d2a5f66a273`.
- All 19 core tests passed with zero failures; the unsigned Release iPhone app compiled successfully.
- Artifact archive SHA-256: `143804185f5a98dd3de695efcd9e5162b5b4131b8c8a4b253fe96ddda7b33088`.
- IPA SHA-256: `622571618795f32b61100558837003d8406130862053f7f48dbf17861e7cbbb8`; 328,554 bytes.
- Archive and IPA integrity checked. Embedded bundle identifier `com.markanthony.asunremote`, version `1.2.0`, build `3`, iPhoneOS platform, minimum iOS 17.0, and arm64 Mach-O executable confirmed.
- The distributed ZIP is the unmodified cloud artifact, including the version 1.2 Windows installation instructions.

These automated checks establish compilation, package integrity, and simulated protocol behavior. The later user report confirmed that the v1.2 OK and volume changes worked on the TV.

## Version 1.1 validation history

Version 1.1 adds MAC parsing and a standard 102-byte Wake-on-LAN packet; a nonblocking, interface-bound UDP unicast sender; per-IP MAC storage; and an explicitly experimental power-on control accessible while disconnected. Three requests go to UDP port 9, 250 ms apart. Targets must be directly attached local IPv4 hosts; network, broadcast, self, off-subnet, point-to-point, and invalid-mask destinations are rejected. No multicast/broadcast entitlement is added.

Four new tests cover MAC normalization and packet bytes, malformed/multicast MAC rejection, same-LAN constraints including a /23 boundary, and invalid/point-to-point masks. The existing 15 tests cover pairing, cancellation, request ordering/timeouts, navigation, reconnect isolation, and TV response parsing.

The previous Linux Swift toolchain is no longer available in this workspace. Validation used the cloud Mac's real Swift compiler. All **19 core tests passed with zero failures** (15 existing + 4 wake tests), and the complete iOS Release build succeeded. Local structural checks passed for both plists, the 11 app/core source paths, Xcode object references, version 1.1.0 (2), and the count of 19 test methods. These checks do not compile Swift or run the tests.

The user explicitly approved uploading the update to the existing private Asun250/asun-remote repository and running its existing iPhone cloud build. The upload and build completed successfully.

## Physical verification still required

- Version 1.4 direct YouTube results for both query formats; native layout and accessibility. LG-browser field readiness, insertion and submission still need verification. The user confirmed v1.2 working and v1.3 YouTube field detection failing.
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
