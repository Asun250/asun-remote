# Asun Remote for iPhone

A native SwiftUI remote-control project for Mark Anthony’s **LG webOS UM6970PUA**, identified from the TV photo showing firmware **05.40.97**. iPhone with iOS 17 or later. No third-party app dependencies.

**Version 1.4 adds a separate YouTube search option.** Open Keyboard, leave **YouTube** selected, type on your iPhone, then tap **Search YouTube on TV**. It asks the YouTube TV app to open search results directly; it does not type into the currently focused search box and does not wait for LG field detection. If YouTube opens only its home screen, try **Compatibility search** once with the retained query.

The user confirmed the v1.2 OK and volume changes work. They installed v1.3 and confirmed YouTube still reports no text field even after refreshing. Version 1.4 keeps the registered LG keyboard under **TV field** for apps that support it, while YouTube uses its own search launch route. The new route needs physical verification on this TV; a successful TV request does not prove that YouTube displayed results. All 32 core tests passed and the complete v1.4 iPhone build succeeded.

Standby wake remains experimental and unverified; the TV's physical power button is available for turning it on.

**Only have Windows? Start with [WINDOWS_SETUP.md](WINDOWS_SETUP.md).** Sideloadly on Windows can sign and install the IPA. The project includes a manual GitHub Actions cloud-Mac build and an unsigned IPA packaging script for future updates.

## What the app implements

- Direct connection from iPhone to TV on your home network; no PC helper.
- On-screen TV pairing approval, with pairing key stored in iPhone Keychain.
- Secure WebSocket connection with a saved TV certificate; explicit legacy connection option.
- Directional pad, OK, Back, Home, volume, mute, and tuner channel controls.
- Separate Play, Pause, Rewind, and Fast-forward controls.
- Installed apps and actual input names read from the TV.
- Direct YouTube search, plus LG text entry under TV field for apps that support remote typing.
- Power **off**, with an on-screen confirmation.
- Experimental **Try turning on** control, with per-TV MAC storage and bounded local unicast wake packets.
- Connection timeouts, command errors, and reconnect after returning to the app.

Power **on** must be tested before relying on it. See the setup and limitations below. Volume routed through a soundbar/receiver, individual app playback, and text-entry behavior need testing on your setup. The user has reported initial real-TV behavior; the v1.4 YouTube search route, LG-native text entry, and other firmware-specific functions still need on-device testing.

## Install using a Mac

1. Extract the ZIP on a Mac. Install a version of **Xcode compatible with the iOS version on your iPhone**.
2. Open **AsunRemote.xcodeproj**. Choose the **AsunRemote** scheme.
3. Open Xcode Settings → Apple Accounts and sign in yourself. Do not share your password or signing certificates.
4. Select the AsunRemote target → Signing & Capabilities. Leave automatic signing enabled and select your team. If Xcode says the bundle identifier is unavailable, change `com.markanthony.asunremote` to a unique identifier under your name.
5. Connect and unlock the iPhone, trust the Mac, and select the iPhone as the run destination.
6. Enable Developer Mode on the iPhone if Xcode asks. Press **Run** in Xcode.

A free Personal Team can be used for personal device testing. Apple’s free provisioning profiles expire after **7 days**, so the app must then be rebuilt/reinstalled. TestFlight or broader distribution requires the appropriate Apple Developer membership and a signed build. A cloud Mac/build service is another build route, but it does not remove Apple’s signing requirements.

The Mac is needed for installation/building, not for normal remote use afterward.

## Pair with your LG TV

1. Turn on the TV. Connect your iPhone to the same home network; the TV can use Wi-Fi or Ethernet.
2. On the TV, open **Settings → All Settings → Connection / Network** and open the active connection. Find the **IP address**. Wi-Fi may put it under Advanced Settings. Do not copy the gateway or DNS address.
3. If the TV exposes **LG Connect Apps** or a setting that permits mobile connections, enable it. Menu labels vary with firmware.
4. Open Asun Remote → **Connect TV**. Enter the TV’s local IPv4 address and start with **Secure**.
5. Allow **Local Network** access on the iPhone. Accept the pairing request on the TV with your physical remote.
6. Once connected, test **Volume +** and **Home**, then open Apps and Inputs.

The address in the input placeholder is an example, not your TV’s actual address. No network scan is performed. A manual IP avoids requiring Apple’s restricted multicast-discovery entitlement for this personal build.

If Secure cannot connect, try the explicit **Legacy compatibility** option. That option uses unencrypted WebSocket traffic on the local network. It has its own saved pairing and is never selected automatically. If your router changes the TV’s IP address, update it and pair again; a router DHCP reservation can keep the address stable.

## Set up and test power on

1. Pair with the TV while it is on. Confirm normal controls work first.
2. On this LG generation, look for **Settings → All Settings → Connection → Mobile TV On → Turn on via Wi-Fi**. Some firmware puts Mobile TV On under General. Enable it and leave the TV plugged in.
3. Find the **MAC address of the TV's active network interface** in its network details (Wi-Fi MAC when connected by Wi-Fi; wired MAC when connected by Ethernet). In Asun Remote's Connection settings, enter it under Power-on test. The MAC is saved for that TV IP address.
4. Have access to the TV's own physical power button while testing. Turn it off, then tap **Try turning on** on the Remote screen. A sent request is not confirmation. Watch the actual screen; when it lights up, tap Reconnect.
5. Repeat after at least 15 minutes of standby, and after overnight standby. A successful immediate off/on test does not prove long-term reliability.

**Limitations:** This personal build sends UDP unicast to port 9 of the entered TV IP, restricted to a directly attached IPv4 LAN. It does not send broadcast or multicast. Apple requires the managed multicast networking entitlement for broadcast/multicast on iOS; this build does not request or bypass that entitlement. Unicast wake depends on the TV/interface accepting the packet and on local address resolution (ARP). It may fail once cached address information expires or the TV enters deeper standby. Sending successfully only means the iPhone accepted the datagram.

If wake fails, use LG ThinQ to check whether the TV can wake with its supported app. Do not depend on this build to replace a broken power button until the standby tests pass. The PC is not required to send the app's wake attempt. Never unplug the TV for a wake test, and no router port forwarding is needed. A DHCP reservation can keep the configured TV IP stable.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No connection | TV is on; correct TV IP; same LAN; not a guest network that isolates devices; VPN is not blocking LAN traffic. |
| No iPhone network permission | iPhone Settings → Privacy & Security → Local Network → enable Asun Remote. |
| Pairing prompt rejected/expired | Tap Connect again and approve the prompt on the TV. |
| TV identity changed | Confirm the IP still belongs to this TV. If it was reset/updated, use Forget pairing and pair again. |
| TV controls work, but an app ignores playback | Use the directional pad to operate that app’s own controls. App behavior varies. |
| Keyboard does nothing | For YouTube, choose Keyboard → YouTube, enter a query, and tap Search YouTube on TV. No TV field detection is required. If it opens only Home, try Compatibility search once. For an LG-native field, choose TV field and wait for TV text field ready before Send & Search. |
| Volume does not change | Check whether a soundbar/receiver is handling volume instead of the TV. |
| TV is off | Configure Mobile TV On and the active MAC, then use Try turning on. Wake remains unverified; use the TV’s physical button if it fails. |
| Wake works immediately but fails later | Unicast/ARP or deeper standby may be the limit. Test LG ThinQ; do not treat this build as a reliable power-on replacement yet. |

LG’s existing **LG ThinQ** app is an immediate alternative while the custom app is being signed and tested.

## Development and validation

The `Package.swift` file exposes the same core files compiled into the iPhone app. Run `swift test` to test them. On a Mac with Xcode, run `bash scripts/check-mac.sh` to run core tests and compile the iOS Simulator app without device signing.

`Tests/RemoteCoreTests.swift` uses simulated TV messages. These tests do not replace hardware pairing, iOS Keychain/TLS validation, or UI testing. See `VALIDATION.md` for the checks actually run during preparation.

Main code locations:

- `AsunRemote/Core`: protocol messages, endpoint validation, WebSocket wrapper, connection/request lifecycle.
- `AsunRemote/TVTrustDelegate.swift`: certificate trust scoped to the selected TV.
- `AsunRemote/PairingStore.swift`: Keychain storage.
- `AsunRemote/RemoteModel.swift`: app state and command handling.
- `AsunRemote/ContentView.swift`, `ConnectionView.swift`: native iPhone screens.

## Privacy and connection design

No advertising, analytics, cloud relay, or LG account is used. The TV’s address, connection preference, and per-IP wake MAC are stored locally in UserDefaults. Pairing credentials and the TV certificate are stored in the local, device-only Keychain.

Secure mode uses port 3001. LG TVs can use self-signed certificates, so first-use trust is restricted to the exact private address the user entered. The certificate is persisted only after TV pairing succeeds, and later connections must match it. This is trust on first use; it does not independently prove TV identity on a hostile network. Legacy mode uses port 3000 and no encryption. Pointer socket URLs must retain the selected TV’s host, scheme, and port.

The app does not open router ports, disable phone security settings, or enable TV developer mode. It needs ordinary Local Network permission.

## References

- [LG ThinQ TV setup and supported remote functions](https://www.lg.com/us/support/help-library/lg-tv-how-to-set-up-the-lg-thinq-app-on-your-lg-smart-tv--20152745625356)
- [LG UM6970 product family](https://www.lg.com/us/tvs/lg-70um6970pua-4k-uhd-tv) — the photo identifies the family, not the screen size.
- [Connect SDK webOS service documentation](https://connectsdk.com/en/latest/apis-ios/ios-webostvservice.html)
- [LG Connect SDK protocol reference implementation](https://github.com/ConnectSDK/Connect-SDK-iOS-Core) — consulted for protocol behavior; this app is an independent Swift implementation and bundles no Connect SDK code.
- [Apple: personal team and signing limitations](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [LG 2019-generation Mobile TV On guide](https://kr.eguide.lgappstv.com/manual/w19_mr/dvb/Contents/settings/connection/mobiletvon_e_c_a_t/eng/w45__settings__connection__mobiletvon_e_c_a_t__eng.html)
- [Apple: local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)

## Control references

- [webOS pointer socket button names, including ENTER](https://github.com/hobbyquaker/lgtv2#methods)
- [WebOSClient remote Enter / OK usage](https://github.com/jareksedy/WebOSClient)
- [Apple: explicit content shape for hit testing](https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:))
- [LG Connect SDK: keyboard registration, field status, and ordered text commands](https://github.com/ConnectSDK/Connect-SDK-Android-Core/blob/master/src/com/connectsdk/service/webos/WebOSTVKeyboardInput.java)
- [YouTube: use an iPhone to connect to and control the TV app](https://support.google.com/youtube/answer/7640706?co=GENIE.Platform%3DiOS&hl=en)

## YouTube search implementation references

- [Stock LG YouTube app metadata, webOS 4.9.7 / C9](https://github.com/webos-uxomis/youtube-webos-cobalt-ipks/blob/main/webOS-4.9.7-14-SoC-o18-OLED65C9PLA-youtube.leanback.v4-1.0.18.info.txt) advertises `contentTarget: q=$SEARCH_KEYWORD`. This is evidence from a related TV, not verification on the UM6970PUA.
- [Connect SDK iOS launch implementation](https://github.com/ConnectSDK/Connect-SDK-iOS-Core/blob/master/Services/WebOSTVService.m) forwards app ID and params through `ssap://system.launcher/launch`.
- [Modified webosbrew YouTube metadata](https://github.com/webosbrew/youtube-webos/blob/main/assets/appinfo.json) advertises the alternative `target` query. This is a modified app reference, not proof that all stock versions accept it.

If the installed YouTube app advertises a recognized query parameter, the app uses it. Otherwise it defaults to `contentTarget`. Compatibility search explicitly tries the other parameter. Queries are percent-encoded as a single value. No automatic retries, browser fallback, account-token access, or TV developer mode is involved.
