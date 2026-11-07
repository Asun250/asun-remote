import SwiftUI

@MainActor
struct TVSettingsView: View {
    @ObservedObject var model: RemoteModel
    let openConnection: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                Section {
                    NavigationLink {
                        BluetoothAudioView(model: model)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bluetooth devices")
                                Text("Headphones, earbuds & speakers")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "headphones") }
                    }
                }
                tvMenus
                TVSettingsFeedback(model: model)
            }
            .navigationTitle("TV Settings")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                TVSettingsRemote(model: model)
            }
        }
    }

    private var connectionSection: some View {
        Section {
            Button(action: openConnection) {
                Label(model.connected ? "TV connected · Connection settings" : "Connect your TV",
                      systemImage: model.connected ? "tv.fill" : "wifi")
            }
        } footer: {
            Text("Open your TV’s actual settings and use the arrows below while watching the TV. Setting names and available options come from your TV.")
        }
    }

    private var tvMenus: some View {
        Section("TV menus") {
            ForEach(TVSettingsSection.allCases) { section in
                Button {
                    Task { await model.openTVSettings(section) }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.title)
                            Text(section == .safety ? "Open All Settings, then select Safety" : "Opens on TV")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: section.symbol) }
                }
                .disabled(!model.connected || model.settingsBusy)
            }
        }
    }
}

@MainActor
private struct BluetoothAudioView: View {
    @ObservedObject var model: RemoteModel

    var body: some View {
        Form {
            if !model.connected {
                Section {
                    Label("Connect your TV first from TV Settings.", systemImage: "wifi.slash")
                }
            }
            pairingSection
            audioSection
            TVSettingsFeedback(model: model)
        }
        .navigationTitle("Bluetooth audio")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TVSettingsRemote(model: model)
        }
        .task(id: model.connected) {
            if model.connected { await model.refreshSoundOutput() }
        }
    }

    private var pairingSection: some View {
        Section {
            Label("Listen to your TV through earbuds, headphones, or a Bluetooth speaker.", systemImage: "tv")
            Text("1. Put your audio device in pairing mode.")
            Button {
                Task { await model.openTVSettings(.sound) }
            } label: {
                Label("2. Open Sound settings on TV", systemImage: "speaker.wave.2")
            }
            .disabled(!model.connected || model.settingsBusy)
            Text("3. On the TV, choose Sound Out → Bluetooth → Device Selection (or Device List).")
            Text("4. Use the arrows and OK below to select your device and connect.")
        } header: {
            Text("Connect a device")
        } footer: {
            Text("Available devices and connection prompts appear on the TV. Audio plays from the TV to the device; it does not pass through your iPhone. Device compatibility depends on the TV.")
        }
    }

    private var audioSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Last checked output").font(.caption).foregroundStyle(.secondary)
                Text(model.audioStatus?.title ?? "Not available")
                    .font(.headline)
            }
            if let problem = model.audioProblem {
                Text(problem).font(.footnote).foregroundStyle(.secondary)
            }
            Button {
                Task { await model.refreshSoundOutput() }
            } label: { Label("Refresh output", systemImage: "arrow.clockwise") }
            .disabled(!model.connected || model.settingsBusy)
            Button {
                Task { await model.setSoundOutput(.bluetooth) }
            } label: { Label("Use paired Bluetooth device", systemImage: "headphones") }
            .disabled(!model.connected || model.settingsBusy)
            Button {
                Task { await model.setSoundOutput(.tvSpeakers) }
            } label: { Label("Use TV speakers", systemImage: "tv") }
            .disabled(!model.connected || model.settingsBusy)
        } header: {
            Text("Sound output")
        } footer: {
            Text("The Bluetooth shortcut uses the TV’s paired device. Pair a new device using the steps above. If a shortcut is unavailable, choose the output in the TV’s Sound settings. Refresh after making changes on the TV.")
        }
    }
}

@MainActor
private struct TVSettingsFeedback: View {
    @ObservedObject var model: RemoteModel

    var body: some View {
        if model.settingsBusy || model.settingsNotice != nil {
            Section {
                if model.settingsBusy { ProgressView("Waiting for TV…") }
                if let notice = model.settingsNotice {
                    Text(notice).font(.footnote)
                }
            }
        }
    }
}

@MainActor
private struct TVSettingsRemote: View {
    @ObservedObject var model: RemoteModel

    var body: some View {
        VStack(spacing: 6) {
            Text("Control the menu on your TV")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    direction("Up", "chevron.up", .up)
                    HStack(spacing: 4) {
                        direction("Left", "chevron.left", .left)
                        Button { model.press(.ok) } label: {
                            Text("OK").font(.headline).frame(width: 48, height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle)
                        .accessibilityLabel("OK, select on TV")
                        direction("Right", "chevron.right", .right)
                    }
                    direction("Down", "chevron.down", .down)
                }
                VStack(spacing: 12) {
                    menuButton("Back", "arrow.uturn.backward", .back)
                    menuButton("TV menu", "gearshape", .menu)
                }
            }
            .disabled(!model.connected || model.settingsBusy)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func direction(_ title: String, _ symbol: String, _ button: RemoteButton) -> some View {
        Button { model.press(button) } label: {
            Image(systemName: symbol).font(.headline)
                .frame(width: 44, height: 44)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func menuButton(_ title: String, _ symbol: String, _ button: RemoteButton) -> some View {
        Button { model.press(button) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                Text(title).font(.caption)
            }
            .frame(minWidth: 72, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
    }
}
