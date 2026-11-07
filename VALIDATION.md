# Validation — Asun Remote v1

Prepared on November 6, 2026. Target family: LG webOS UM6970PUA. This is an unsigned source project.

## Completed

| Check | Result |
| --- | --- |
| Core Swift package compilation | Passed with Swift 6.0.3, Swift 5 language mode, Linux. |
| Automated core tests | **15 tests passed, 0 failures.** |
| Parsing every iOS app Swift source | Passed using the Swift compiler frontend. This checks syntax, not Apple SDK type compatibility. |
| Xcode project structure | Parsed with an independent OpenStep parser; all object and file references resolve, including all 9 app/core Swift files. |
| App Info.plist and privacy manifest | Parsed successfully; local network permission text and local-only ATS exception are present. |
| Shared Xcode scheme | XML parsed; target identifiers match the project. |
| App icons | All 9 declared PNG files exist, with matching dimensions and opaque RGB pixels. |
| Mac validation script | Shell syntax check passed. |

The tests exercise real core code with simulated TV socket messages: initial approval, refusal, saved-key reconnection, pairing timeout, command timeout and recovery, cancellation, disconnect during a command, old-connection shutdown during reconnect, out-of-order replies, failed commands, navigation framing, concurrent pointer setup, input/app parsing, volume response variants, and isolation of the TV’s network endpoint.

Command used for the successful package run:

```sh
swift test -j 1 -Xswiftc -disable-batch-mode
```

The initial parallel compiler driver run failed in the container’s process environment. The subsequent single-job build and test run completed successfully. No app-code change was needed for that environment issue.

## Not yet verified

- A full iOS build against the Apple SDK: no Xcode/Mac is connected here.
- On-screen layout or VoiceOver behavior in an iOS Simulator or on an iPhone.
- Keychain persistence and self-signed certificate handling on iOS.
- The TV’s actual pairing prompt, navigation, app list, inputs, sound output, keyboard behavior, and firmware-specific permissions.
- Signed device installation or TestFlight distribution.

## Next verification on a Mac and TV

1. Run `bash scripts/check-mac.sh`, then install from Xcode following README.md.
2. Pair using Secure mode while the TV is on. Reject one pairing request, then retry and accept it.
3. Verify Volume +, Mute, Home, directional navigation, and OK.
4. Open a real installed app, switch an input, and check playback/text input in apps that support them.
5. Background and reopen the app; confirm the saved pairing reconnects.
6. Disconnect Wi-Fi or turn off the TV; confirm the UI reports the dropped connection.
7. If Secure is unsupported by the TV firmware, try explicit Legacy compatibility. Keep the chosen mode documented for this TV.

Power-on/wake from standby is outside this version and must not be reported as working.

## Windows installation follow-up

Added a manual GitHub Actions workflow on `macos-15`, pinned to the image’s Xcode 16.4 installation, plus an unsigned arm64 IPA packaging script and Windows/Sideloadly instructions. Official GitHub action commit references were resolved from their current `v4` tags on November 6, 2026.

The cloud workflow has not been uploaded or executed. Its existence does not mean that an IPA has been produced or that the full iOS build has passed. The existing 15 core tests remain the test result for unchanged app code.

The workflow YAML, manual-only trigger, minimal repository permissions, pinned actions, source paths, and build-script shell syntax were checked locally. The build script’s non-macOS guard was also exercised and returned the intended cloud-build guidance. These checks do not execute Xcode or validate an IPA.
