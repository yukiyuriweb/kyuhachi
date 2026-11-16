import SwiftUI

@main
struct KyuhachiApp: App {
    @State private var library = Library(directory: Emulator.supportDirectory)

    private var currentGame: Game? {
        Emulator.shared.currentGameID.flatMap(library.game)
    }

    private var latestState: SaveState? {
        currentGame.flatMap { SaveStateStore.shared.states(for: $0.id).first }
    }

    private func restoreLatest() {
        guard let game = currentGame, let state = latestState else { return }
        SaveStateStore.shared.restore(state, of: game, in: .shared)
    }

    var body: some Scene {
        // A single window: NP2kai can run only one machine per process.
        Window("Kyuhachi", id: "main") {
            ContentView(library: library, emulator: .shared, saveStates: .shared, settings: .shared)
                .frame(minWidth: 760, minHeight: 460)
        }
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .saveItem) {
                Button("Save State") { SaveStateStore.shared.save(.shared) }
                    .keyboardShortcut("s")
                    .disabled(Emulator.shared.currentGameID == nil)
                Button("Restore Latest State") { restoreLatest() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(latestState == nil)
            }
            CommandMenu("Machine") {
                Button("Reset") { Emulator.shared.reset() }
                    .keyboardShortcut("r")
                    .disabled(Emulator.shared.currentGameID == nil)
            }
        }

        Settings {
            SettingsView(settings: .shared)
        }
    }
}
