import SwiftUI

@main
struct KyuhachiApp: App {
    @State private var library = Library(directory: Emulator.supportDirectory)

    var body: some Scene {
        // A single window: NP2kai can run only one machine per process.
        Window("Kyuhachi", id: "main") {
            ContentView(library: library, emulator: .shared)
                .frame(minWidth: 760, minHeight: 460)
        }
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
