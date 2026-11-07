# Asun Remote for iPhone

A native SwiftUI remote-control project for Mark Anthony’s **LG webOS UM6970PUA**, identified from the TV photo showing firmware **05.40.97**. iPhone with iOS 17 or later. No third-party app dependencies.

**This download is source code, not an installable IPA or TestFlight link.** The control core has automated tests; the iPhone UI still needs an Xcode build and a real pairing test on your TV. There is no Mac or TV connected to the build environment used to prepare this project.

**Only have Windows? Start with [WINDOWS_SETUP.md](WINDOWS_SETUP.md).** The project now includes a manual GitHub Actions cloud-Mac build and an unsigned IPA packaging script. After that build succeeds, Sideloadly on Windows can sign and install the app. No cloud build or device installation has been completed yet.

## What the first version implements

- Direct connection from iPhone to TV on your home network; no PC helper.
- On-screen TV pairing approval, with pairing key stored in iPhone Keychain.
- Secure WebSocket connection with a saved TV certificate; explicit legacy connection option.
- Directional pad, OK, Back, Home, volume, mute, and tuner channel controls.
- Separate Play, Pause, Rewind, and Fast-forward controls.
- Installed apps and actual input names read from the TV.
- Text entry for TV apps that support remote typing.
- Power **off**, with an on-screen confirmation.
- Connection timeouts, command errors, and reconnect after returning to the app.

Power **on** from standby is not included. Turn the TV on with the physical remote for now. Volume routed through a soundbar/receiver, individual app playback, and text-entry behavior need testing on your setup. This project makes no claim of having been tested on the physical UM6970PUA yet.

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

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No connection | TV is on; correct TV IP; same LAN; not a guest network that isolates devices; VPN is not blocking LAN traffic. |
| No iPhone network permission | iPhone Settings → Privacy & Security → Local Network → enable Asun Remote. |
| Pairing prompt rejected/expired | Tap Connect again and approve the prompt on the TV. |
| TV identity changed | Confirm the IP still belongs to this TV. If it was reset/updated, use Forget pairing and pair again. |
| TV controls work, but an app ignores playback | Use the directional pad to operate that app’s own controls. App behavior varies. |
| Keyboard does nothing | First focus a TV search/text field; some TV apps block remote keyboard entry. |
| Volume does not change | Check whether a soundbar/receiver is handling volume instead of the TV. |
| TV is off | Wake it with the physical remote; this version does not send a standby wake packet. |

LG’s existing **LG ThinQ** app is an immediate alternative while the custom app is being signed and tested.

## Development and validation

The `Package.swift` file exposes the same three core files compiled into the iPhone app. Run `swift test` to test them. On a Mac with Xcode, run `bash scripts/check-mac.sh` to run core tests and compile the iOS Simulator app without device signing.

`Tests/RemoteCoreTests.swift` uses simulated TV messages. These tests do not replace hardware pairing, iOS Keychain/TLS validation, or UI testing. See `VALIDATION.md` for the checks actually run during preparation.

Main code locations:

- `AsunRemote/Core`: protocol messages, endpoint validation, WebSocket wrapper, connection/request lifecycle.
- `AsunRemote/TVTrustDelegate.swift`: certificate trust scoped to the selected TV.
- `AsunRemote/PairingStore.swift`: Keychain storage.
- `AsunRemote/RemoteModel.swift`: app state and command handling.
- `AsunRemote/ContentView.swift`, `ConnectionView.swift`: native iPhone screens.

## Privacy and connection design

No advertising, analytics, cloud relay, or LG account is used. Only the TV’s address/connection preference is stored in UserDefaults. Pairing credentials and the TV certificate are stored in the local, device-only Keychain.

Secure mode uses port 3001. LG TVs can use self-signed certificates, so first-use trust is restricted to the exact private address the user entered. The certificate is persisted only after TV pairing succeeds, and later connections must match it. This is trust on first use; it does not independently prove TV identity on a hostile network. Legacy mode uses port 3000 and no encryption. Pointer socket URLs must retain the selected TV’s host, scheme, and port.

The app does not open router ports, disable phone security settings, or enable TV developer mode. It needs ordinary Local Network permission.

## References

- [LG ThinQ TV setup and supported remote functions](https://www.lg.com/us/support/help-library/lg-tv-how-to-set-up-the-lg-thinq-app-on-your-lg-smart-tv--20152745625356)
- [LG UM6970 product family](https://www.lg.com/us/tvs/lg-70um6970pua-4k-uhd-tv) — the photo identifies the family, not the screen size.
- [Connect SDK webOS service documentation](https://connectsdk.com/en/latest/apis-ios/ios-webostvservice.html)
- [LG Connect SDK protocol reference implementation](https://github.com/ConnectSDK/Connect-SDK-iOS-Core) — consulted for protocol behavior; this app is an independent Swift implementation and bundles no Connect SDK code.
- [Apple: personal team and signing limitations](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Apple: local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
