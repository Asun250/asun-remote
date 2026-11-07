import SwiftUI

@main
@MainActor
struct AsunRemoteApp: App {
    @StateObject private var model = RemoteModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
                .onAppear { model.resume() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.resume() }
                    if phase == .background { model.suspend() }
                }
        }
    }
}
