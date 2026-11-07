import SwiftUI
import UIKit

private enum RemoteTheme {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.09)
    static let panel = Color(red: 0.075, green: 0.10, blue: 0.15)
    static let accent = Color(red: 0.35, green: 0.90, blue: 0.85)
}

@MainActor
struct ContentView: View {
    @ObservedObject var model: RemoteModel
    @State private var settings = false
    @State private var keyboard = false
    @State private var confirmPower = false
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            remote.tabItem { Label("Remote", systemImage: "appletvremote.gen1") }.tag(0)
            library(isApps: true).tabItem { Label("Apps", systemImage: "square.grid.2x2") }.tag(1)
            library(isApps: false).tabItem { Label("Inputs", systemImage: "cable.connector") }.tag(2)
        }
        .tint(RemoteTheme.accent)
        .sheet(isPresented: $settings) { ConnectionView(model: model) }
        .sheet(isPresented: $keyboard) { KeyboardView(model: model) }
        .confirmationDialog("Turn off your TV?", isPresented: $confirmPower, titleVisibility: .visible) {
            Button("Turn off TV", role: .destructive) { model.powerOff() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Power-on from this app is still experimental. Keep the TV’s own power button available until you have tested wake from standby.")
        }
    }

    private var remote: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    connectionCard
                    if let message = model.message { notice(message) }
                    if !model.connected { setupHint }
                    VStack(spacing: 24) {
                        HStack {
                            smallButton("Keyboard", "keyboard") { keyboard = true }
                            Spacer()
                            smallButton("Turn off TV", "power", color: .red) { confirmPower = true }
                        }
                        directionPad
                        HStack(spacing: 14) {
                            wideButton("Back", "arrow.uturn.backward") { model.press(.back) }
                            wideButton("Home", "house.fill") { model.press(.home) }
                            wideButton("Inputs", "cable.connector") { tab = 2 }
                        }
                        HStack(spacing: 16) {
                            rocker(title: "VOLUME", value: model.volume.map(String.init) ?? "—",
                                   up: { model.changeVolume(up: true) }, down: { model.changeVolume(up: false) })
                            VStack(spacing: 14) {
                                smallButton(model.muted == true ? "Unmute" : "Mute",
                                            model.muted == true ? "speaker.slash.fill" : "speaker.wave.2.fill") { model.toggleMute() }
                                Text(model.muted == true ? "Muted" : "Sound").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity)
                            rocker(title: "CHANNEL", value: "CH",
                                   up: { model.changeChannel(up: true) }, down: { model.changeChannel(up: false) })
                        }
                        HStack(spacing: 12) {
                            smallButton("Rewind", "backward.fill") { model.media("rewind") }
                            smallButton("Play", "play.fill") { model.media("play") }
                            smallButton("Pause", "pause.fill") { model.media("pause") }
                            smallButton("Fast forward", "forward.fill") { model.media("fastForward") }
                        }
                        Text("Playback and text entry depend on the TV app. Channel buttons control the TV tuner.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .disabled(!model.connected)
                    .opacity(model.connected ? 1 : 0.35)
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(RemoteTheme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("ASUN").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(5)
                    .foregroundStyle(RemoteTheme.accent)
                Text("Remote").font(.system(size: 34, weight: .bold, design: .rounded))
            }
            Spacer()
            smallButton("Connection settings", "slider.horizontal.3") { settings = true }
        }
    }

    private var connectionCard: some View {
        Button { settings = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "tv").font(.system(size: 25))
                    .foregroundStyle(RemoteTheme.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("LG UM6970").font(.headline)
                    HStack(spacing: 6) {
                        Circle().fill(model.connected ? RemoteTheme.accent : Color.gray).frame(width: 6, height: 6)
                        Text(model.connected ? "Connected · \(model.connectedAddress)" : model.waking ? "Sending wake request…" : model.pairing ? "Waiting for your TV…" : "Not connected")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if model.pairing || model.waking { ProgressView() }
                else { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
            }
            .padding(18)
            .background(RemoteTheme.panel, in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain)
    }

    private var setupHint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.waking ? "Sending wake request" : model.pairing ? "Check your TV screen" : "Connect or wake your TV").font(.headline)
            Text(model.waking ? "Keep the app open. Sending a request does not confirm that the TV has turned on." : model.pairing ? "Choose Allow or Accept if the TV asks to connect Asun Remote. Keep the app open." : "Connect while the TV is on. If it is in standby, you can test power on after setting up its MAC address.")
                .font(.subheadline).foregroundStyle(.secondary)
            if model.waking {
                Button("Cancel wake request") { model.disconnect() }
            } else if model.pairing {
                Button("Cancel connection") { model.disconnect() }
            } else {
                Button(model.address.isEmpty ? "Connect TV" : "Reconnect") {
                    if model.address.isEmpty { settings = true } else { model.connect() }
                }.buttonStyle(.borderedProminent).foregroundStyle(RemoteTheme.background)
                if !model.address.isEmpty {
                    Button {
                        if model.hasWakeAddress { model.tryPowerOn() } else { settings = true }
                    } label: {
                        Label(model.hasWakeAddress ? "Try turning on" : "Set up power on", systemImage: "power")
                    }.buttonStyle(.bordered)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var directionPad: some View {
        VStack(spacing: 2) {
            padButton("Up", "chevron.up", .up)
            HStack(spacing: 2) {
                padButton("Left", "chevron.left", .left)
                Button { haptic(); model.press(.ok) } label: {
                    Text("OK").font(.system(size: 20, weight: .bold, design: .rounded))
                        .frame(width: 82, height: 82)
                        .background(RemoteTheme.accent.gradient, in: Circle())
                        .foregroundStyle(RemoteTheme.background)
                        .contentShape(Circle())
                }.buttonStyle(PressStyle()).accessibilityLabel("OK, select")
                padButton("Right", "chevron.right", .right)
            }
            padButton("Down", "chevron.down", .down)
        }
        .frame(width: 276, height: 276)
        .background(RemoteTheme.panel.gradient, in: Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.05), lineWidth: 1))
    }

    private func padButton(_ name: String, _ icon: String, _ button: RemoteButton) -> some View {
        Button { haptic(); model.press(button) } label: {
            Image(systemName: icon).font(.system(size: 23, weight: .semibold))
                .frame(width: 82, height: 70).contentShape(Rectangle())
        }.buttonStyle(PressStyle()).accessibilityLabel(name)
    }

    private func smallButton(_ name: String, _ icon: String, color: Color = .white,
                             action: @escaping () -> Void) -> some View {
        Button { haptic(); action() } label: {
            Image(systemName: icon).font(.system(size: 19, weight: .medium))
                .frame(minWidth: 48, minHeight: 48).foregroundStyle(color)
                .background(RemoteTheme.panel, in: RoundedRectangle(cornerRadius: 17))
                .contentShape(RoundedRectangle(cornerRadius: 17))
        }.buttonStyle(PressStyle()).accessibilityLabel(name)
    }

    private func wideButton(_ name: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button { haptic(); action() } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 19, weight: .medium))
                Text(name).font(.caption)
            }.frame(maxWidth: .infinity).frame(height: 74)
                .background(RemoteTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                .contentShape(RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(PressStyle()).accessibilityLabel(name)
    }

    private func rocker(title: String, value: String, up: @escaping () -> Void,
                        down: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button { haptic(); up() } label: {
                Image(systemName: "plus").font(.title3).frame(maxWidth: .infinity).frame(height: 48)
                    .contentShape(Rectangle())
            }.accessibilityLabel(title == "VOLUME" ? "Volume up" : "Channel up")
            Text(value).font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
            Text(title).font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
            Button { haptic(); down() } label: {
                Image(systemName: "minus").font(.title3).frame(maxWidth: .infinity).frame(height: 48)
                    .contentShape(Rectangle())
            }.accessibilityLabel(title == "VOLUME" ? "Volume down" : "Channel down")
        }.buttonStyle(PressStyle()).frame(maxWidth: .infinity)
            .padding(.vertical, 6).background(RemoteTheme.panel, in: Capsule())
    }

    private func notice(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle").foregroundStyle(RemoteTheme.accent)
            Text(text).font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
            Button { model.message = nil } label: {
                Image(systemName: "xmark").frame(width: 28, height: 28)
            }.accessibilityLabel("Dismiss message")
        }.padding(16).background(RemoteTheme.panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private func library(isApps: Bool) -> some View {
        NavigationStack {
            Group {
                if !model.connected {
                    ContentUnavailableView {
                        Label("Connect your TV", systemImage: "tv")
                    } description: { Text("Your TV’s \(isApps ? "apps" : "inputs") will appear after pairing.") }
                    actions: { Button("Connection settings") { settings = true } }
                } else {
                    List {
                        if let message = model.message {
                            Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
                        }
                        if model.loadingLists {
                            HStack { ProgressView(); Text("Reading your TV…") }
                        }
                        if let problem = isApps ? model.appsProblem : model.inputsProblem {
                            Text(problem).foregroundStyle(.secondary)
                        }
                        if isApps {
                            ForEach(model.apps) { app in
                                Button { model.launch(app) } label: {
                                    Label(app.title, systemImage: "play.rectangle").padding(.vertical, 10)
                                }.foregroundStyle(.primary)
                            }
                            if model.apps.isEmpty && !model.loadingLists && model.appsProblem == nil {
                                Text("The TV returned no apps.").foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(model.inputs) { input in
                                Button { model.selectInput(input) } label: {
                                    HStack {
                                        Label(input.title, systemImage: "cable.connector")
                                        Spacer()
                                        Text(input.connected ? "Connected" : "No signal detected").font(.caption).foregroundStyle(.secondary)
                                    }.padding(.vertical, 10)
                                }.foregroundStyle(.primary)
                            }
                            if model.inputs.isEmpty && !model.loadingLists && model.inputsProblem == nil {
                                Text("The TV returned no inputs.").foregroundStyle(.secondary)
                            }
                        }
                    }.scrollContentBackground(.hidden)
                }
            }
            .background(RemoteTheme.background)
            .navigationTitle(isApps ? "Your apps" : "TV inputs")
            .toolbar {
                if model.connected {
                    Button("Refresh", systemImage: "arrow.clockwise") { model.refreshLists() }.disabled(model.loadingLists)
                }
            }
        }
    }

    private func haptic() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.70 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
