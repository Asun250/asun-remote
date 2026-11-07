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
                        .disabled(model.pairing || model.connected)
                    Picker("Connection", selection: $model.mode) {
                        ForEach(ConnectionMode.allCases, id: \.self) { mode in Text(mode.label).tag(mode) }
                    }.disabled(model.pairing || model.connected)
                    if model.mode == .legacy {
                        Text("Legacy uses an unencrypted connection on your home Wi-Fi. Choose it only if Secure cannot connect.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    if model.connected {
                        Label("Connected to \(model.connectedAddress)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        Button("Disconnect") { model.disconnect() }
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
                Section("About this version") {
                    Text("Works locally. No subscription, ads, LG login, or cloud account is used by this app.")
                    Text("Turn the TV on with its physical remote. This version supports power off; waking from standby still needs device testing.")
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("First select a search or text field on your TV. Some apps do not accept remote typing.")
                        .foregroundStyle(.secondary)
                    TextField("Type for your TV", text: $text, axis: .vertical)
                        .lineLimit(3...6).autocorrectionDisabled()
                        .onChange(of: text) { _, value in
                            if value.count > 500 { text = String(value.prefix(500)) }
                        }
                    Button("Send text") { model.typeText(text) }.disabled(text.isEmpty || !model.connected)
                }
                Section {
                    Button("Enter / Search", systemImage: "return") { model.enterText() }
                    Button("Delete one character", systemImage: "delete.left") { model.deleteCharacter() }
                }.disabled(!model.connected)
                if let message = model.message {
                    Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("TV keyboard").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
