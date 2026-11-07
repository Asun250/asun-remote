# Use Asun Remote with a Windows PC

You do not need to own a Mac. A cloud Mac builds the app once, then **Sideloadly on Windows** signs and installs it on your iPhone. After installation, the remote communicates directly with your LG TV. Your PC is only needed for installation and periodic signing refreshes.

**Version 1.2:** fixes OK selecting the highlighted item and makes the entire plus/minus button area tappable. Install the new IPA over the existing app using the **same Apple account and bundle identifier**. Do not delete the installed app first.

On Mark's PC, choose **Downloads → AsunRemote-v1.2.ipa** in Sideloadly, then click **Start**. If using this ZIP instead, extract it and select `dist/AsunRemote-unsigned.ipa`. The checksum is in `dist/SHA256SUMS.txt`. Confirm version 1.2 in the app's Connection settings after updating; older Downloads files may contain v1.0 or v1.1.

After Sideloadly shows Done, test these two fixes on the TV:

1. In YouTube, use the arrows to highlight a profile, then press OK once. Repeat in Netflix.
2. Tap Volume Down several times, including slightly beside the minus symbol within its button area. Each tap should register. Check Volume Up too.
3. If a tap still fails, note whether the iPhone vibrates and whether the TV displays its volume indicator or the app shows an error. This separates a missed tap from a TV/network response problem.

## 1. Put the project in a private GitHub repository

Already completed: the source is in the private repository [Asun250/asun-remote](https://github.com/Asun250/asun-remote). Skip to step 3 to install v1.2. The repository/build instructions below are for rebuilding or moving the project later.

Put the contents of the extracted **AsunRemote** folder at the repository root. The root must contain all of these:

- `.github/workflows/build-iphone.yml`
- `AsunRemote.xcodeproj/`
- `AsunRemote/`
- `Package.swift`
- `Tests/`
- `scripts/`
- `WINDOWS_SETUP.md`

Keep `.github` when uploading; it contains the cloud build. Do not upload the ZIP as one repository file, and do not place the project under an extra enclosing folder. The workflow needs to be on the repository’s default branch.

## 2. Build the iPhone app in GitHub Actions

1. Open the repository’s **Actions** tab.
2. Select **Build iPhone app for Windows**.
3. Choose **Run workflow**.
4. When the run finishes successfully, download the **AsunRemote-for-Windows** artifact from the run’s page.
5. Extract the artifact ZIP. It contains **AsunRemote-unsigned.ipa**, its SHA-256 checksum, and these instructions.

The workflow uses a standard macOS runner, runs the protocol tests, builds an arm64 iPhone app, and packages it as an unsigned IPA. It does not require your Apple password, signing certificate, or Apple account in GitHub. Signing happens on your Windows PC in the next step.

This workflow is manual only, with a 20-minute job limit and seven-day artifact retention. Private-repository builds consume your GitHub Actions allowance; extra usage can be billed if paid overages are enabled. Check your GitHub Actions allowance/budget before starting. The workflow does not alter billing settings or buy runner capacity.

If the run fails, share the run link so the actual compiler error can be fixed. Do not proceed using an old or Simulator build.

## 3. Install from Windows with Sideloadly

1. Download Sideloadly only from [sideloadly.io](https://sideloadly.io/), using the Windows version appropriate for your PC.
2. Follow its current setup guidance for the Apple device drivers it requires.
3. Connect your unlocked iPhone to the PC with a USB cable. Tap **Trust** on the phone if asked.
4. Open Sideloadly, select the iPhone, and choose **AsunRemote-unsigned.ipa**.
5. Enter your Apple account credentials yourself in Sideloadly and complete any Apple verification prompts. Do not put credentials in this chat, the source code, or GitHub.
6. Start installation. Sideloadly signs the app for your iPhone and installs it.
7. If prompted, trust your developer profile in iPhone Settings → General → VPN & Device Management. Enable Developer Mode under Settings → Privacy & Security, following the phone’s prompts.

With a free Apple account, the app’s signing expires after **seven days**. Sideloadly offers automatic refresh while its helper is running and the iPhone is reachable by USB or configured Wi-Fi sync. Keep the same Apple account and bundle identifier when refreshing/reinstalling so app data and saved pairing can be retained. Free accounts also have limits on the number of sideloaded apps.

This is personal sideloading, not an App Store installation. No jailbreak is required. An unsigned IPA cannot install merely by opening it on the iPhone.

## 4. Connect to the TV

Turn the TV on and put the iPhone on your home network. Open Asun Remote, enter the TV’s local IP address, allow Local Network access, and accept the pairing prompt on the TV. The full pairing instructions are in README.md.

For power-on testing, enable **Mobile TV On → Turn on via Wi-Fi** on the TV and enter its active network **MAC address** in Asun Remote's Connection settings. Pair while the TV is on first. Keep access to the TV's physical power button; then test **Try turning on** immediately, after 15 minutes off, and overnight. Seeing “Wake request sent” does not confirm that the TV woke. Tap Reconnect once the screen turns on. Some TVs/networks cannot accept this build's unicast wake signal after standby.

The PC does not relay remote commands. It can be off during normal remote use, provided the app’s signing has not expired.

## Sources

- [Sideloadly downloads and features](https://sideloadly.io/)
- [Sideloadly setup, Windows support, refresh and signing limits](https://sideloadly.io/faq)
- [GitHub: manually running a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
- [GitHub: hosted macOS runners and private-repository usage](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [Apple: personal-team signing limits](https://developer.apple.com/help/account/basics/about-your-developer-account)
