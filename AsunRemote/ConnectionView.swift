import SwiftUI

@MainActor
struct ConnectionView: View {
    @ObservedObject var model: RemoteModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmForget = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("LG webOS UM6970PUA", systemImage: "tv")
                    Text("Keep your TV on and connect your iPhone to the same home network. A TV connected to your router by Ethernet also works.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("TV connection") {
                    TextField("TV IP address · e.g. 192.168.1.50", text: $model.address)
                        .keyboardType(.decimalPad).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityLabel("TV IP address")
                        .disabled(model.pairing || model.connected || model.waking)
                    Picker("Connection", selection: $model.mode) {
                        ForEach(ConnectionMode.allCases, id: \.self) { mode in Text(mode.label).tag(mode) }
                    }.disabled(model.pairing || model.connected || model.waking)
                    if model.mode == .legacy {
                        Text("Legacy uses an unencrypted connection on your home Wi-Fi. Choose it only if Secure cannot connect.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    if model.connected {
                        Label("Connected to \(model.connectedAddress)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        Button("Disconnect") { model.disconnect() }
                    } else if model.waking {
                        HStack { ProgressView(); Text("Sending a wake request…") }
                        Button("Cancel") { model.disconnect() }
                    } else if model.pairing {
                        HStack { ProgressView(); Text("Check the TV for an Allow / Accept prompt.") }
                        Button("Cancel connection") { model.disconnect() }
                    } else {
                        Button("Connect & pair") { model.connect() }.disabled(model.address.isEmpty)
                    }
                    if let message = model.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                }
                Section("Find the TV address") {
                    Text("On the TV, open Settings → All Settings → Connection (or Network). Open the active Wi-Fi or Wired Connection and find its IP address. Wi-Fi may show it under Advanced Settings.")
                    Text("Enter the IP address, not the DNS server or gateway. If the TV offers LG Connect Apps or Mobile TV On, enable it. Allow Local Network access when your iPhone asks.")
                    Text("You only need to approve the TV pairing once unless its address or saved pairing changes.")
                }.font(.subheadline)
                Section("Power-on test") {
                    Text("First pair with the TV while it is on. On the TV, enable Settings → All Settings → Connection → Mobile TV On → Turn on via Wi-Fi. Some firmware places Mobile TV On under General.")
                        .font(.subheadline)
                    TextField("TV MAC address · A0:B1:C2:D3:E4:F5", text: $model.wakeMACAddress)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .accessibilityLabel("TV network MAC address")
                        .disabled(!model.validTVAddress || model.waking)
                    Text("Copy the MAC address for the TV’s active Wi-Fi or wired connection from its network details. It is different from the IP address. Saved automatically for this TV IP.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Leave the TV plugged in and your iPhone on the same home Wi-Fi. Once the TV is off, use Try turning on from the Remote screen.")
                        .font(.subheadline)
                    Text("Power-on is experimental and has not been verified on your TV. Some TVs or networks stop accepting this wake request after standby. Test immediately, after 15 minutes, and overnight before relying on it. Keep the TV’s own power button available during testing.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("About this version") {
                    Text("Works locally. No subscription, ads, LG login, or cloud account is used by this app.")
                    Text("Version 1.3 adds TV text-field detection and Send & Search. Power-on remains experimental; a wake request is separate from a confirmed TV connection.")
                    Text("A soundbar or receiver may control volume separately. Individual TV apps may limit playback or keyboard commands.")
                }.font(.footnote).foregroundStyle(.secondary)
                if !model.address.isEmpty {
                    Section {
                        Button("Forget this pairing", role: .destructive) { confirmForget = true }
                    }
                }
            }
            .navigationTitle("Connect your TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Forget this TV pairing?", isPresented: $confirmForget, titleVisibility: .visible) {
                Button("Forget pairing", role: .destructive) { model.forget() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("You will need to approve Asun Remote on the TV again.") }
            .onChange(of: model.connected) { _, connected in if connected { dismiss() } }
        }
    }
}

@MainActor
struct KeyboardView: View {
    @ObservedObject var model: RemoteModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var checkID = UUID()
    @FocusState private var typing: Bool

    private var ready: Bool {
        model.connected && model.keyboardStatus.focused == true
            && !model.keyboardChecking && !model.keyboardBusy && model.keyboardProblem == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("TV search field") {
                    if !model.connected {
                        Label("Connect to your TV first", systemImage: "wifi.slash")
                    } else if model.keyboardChecking {
                        HStack { ProgressView(); Text("Checking the TV keyboard…") }
                    } else if let problem = model.keyboardProblem {
                        Label("Keyboard connection unavailable", systemImage: "exclamationmark.triangle")
                        Text(problem).font(.footnote).foregroundStyle(.secondary)
                    } else if model.keyboardStatus.focused == true {
                        Label("TV text field ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Label("No TV text field detected", systemImage: "text.cursor")
                        Text("Select the search box on your TV and press OK. This status updates when the TV makes a field available.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Check TV field again", systemImage: "arrow.clockwise") { checkID = UUID() }
                        .disabled(!model.connected || model.keyboardBusy || model.keyboardChecking)
                }
                Section("Type on your iPhone") {
                    TextField("Type for your TV", text: $text, axis: .vertical)
                        .lineLimit(2...4).autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($typing)
                        .disabled(model.keyboardBusy)
                        .onChange(of: text) { _, value in
                            if value.count > 500 { text = String(value.prefix(500)) }
                        }
                    Button { send(search: false) } label: {
                        Label("Send to TV", systemImage: "paperplane")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }.disabled(text.isEmpty || !ready)
                    Button { send(search: true) } label: {
                        Label(text.isEmpty ? "Search on TV" : "Send & Search", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }.disabled(!ready)
                    if model.keyboardBusy { HStack { ProgressView(); Text("Sending…") } }
                    if let notice = model.keyboardNotice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
                }
                Section {
                    Button("Delete one character on TV", systemImage: "delete.left") {
                        Task { await model.deleteKeyboardCharacter() }
                    }.disabled(!ready)
                    Text("Editing the draft above changes only your iPhone text. Send to TV appends it; Send & Search also submits it. Confirmed text is cleared from the draft so it is not sent twice.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("If YouTube stays unavailable") {
                    Text("Some YouTube screens use their own keyboard and do not expose a field to LG remote apps. If the status stays unavailable with Search selected, this text connection cannot type into that screen. Use the arrow controls or YouTube’s phone-to-TV connection for that screen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("TV keyboard").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: checkID) { await model.watchKeyboard() }
            .onAppear { typing = true }
            .onChange(of: model.connected) { _, _ in checkID = UUID() }
        }
    }

    private func send(search: Bool) {
        let draft = text
        Task {
            let accepted = await model.sendKeyboardText(draft, search: search)
            if accepted && text == draft { text = "" }
        }
    }
}
