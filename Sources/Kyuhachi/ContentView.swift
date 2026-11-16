import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    let library: Library
    let emulator: Emulator
    let saveStates: SaveStateStore
    let settings: AppSettings

    @State private var selection: Game.ID?
    @State private var addingGame = false
    @State private var choosingDiskForDrive: Int?
    @State private var renaming: Game.ID?
    @State private var newName = ""
    @State private var visibleNotice: Emulator.Notice?
    @State private var gameForSettings: Game?

    private var currentGame: Game? {
        emulator.currentGameID.flatMap(library.game)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            detail
        }
        .fileImporter(isPresented: $addingGame, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result, let game = library.addGame(from: urls) {
                selection = game.id
            }
        }
        .fileImporter(
            isPresented: Binding(get: { choosingDiskForDrive != nil }, set: { if !$0 { choosingDiskForDrive = nil } }),
            allowedContentTypes: [.data]
        ) { result in
            if case .success(let url) = result, let drive = choosingDiskForDrive {
                emulator.insert(url, into: drive)
            }
        }
        .alert("Rename Game", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") {
                if let renaming { library.rename(renaming, to: newName) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $gameForSettings) { game in
            GameSettingsView(game: game, library: library, settings: settings)
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(library.games) { game in
                GameRow(game: game)
            }
        }
        .contextMenu(forSelectionType: Game.ID.self) { ids in
            if let id = ids.first, let game = library.game(id) {
                Button("Play") { play(game) }
                Button("Rename…") {
                    newName = game.name
                    renaming = id
                }
                restoreMenu(for: game)
                Button("Game Settings…") { gameForSettings = game }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(game.disks)
                }
                Divider()
                Button("Remove from Library", role: .destructive) {
                    library.remove(ids)
                }
            }
        } primaryAction: { ids in
            if let id = ids.first, let game = library.game(id) {
                play(game)
            }
        }
        .onDeleteCommand {
            if let selection { library.remove([selection]) }
        }
        .overlay {
            if library.games.isEmpty {
                ContentUnavailableView {
                    Label("No Games", systemImage: "square.stack")
                } description: {
                    Text("Add a game's floppy or hard disk images with the + button, or drop them here.")
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let game = library.addGame(from: urls) else { return false }
            selection = game.id
            return true
        }
        .toolbar {
            ToolbarItem {
                Button("Add Game…", systemImage: "plus") { addingGame = true }
            }
        }
    }

    private func play(_ game: Game) {
        library.markPlayed(game.id)
        emulator.play(game)
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let game = currentGame {
            ScreenView(emulator: emulator, mouseCaptured: emulator.mouseCaptured, aspect: settings.aspect)
                .overlay(alignment: .top) {
                    if let visibleNotice {
                        Text(visibleNotice.text)
                            .font(.callout)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect()
                            .padding(.top, 12)
                            .transition(.opacity)
                    }
                }
                .onChange(of: emulator.mouseCaptured) { _, captured in
                    if captured {
                        emulator.showNotice(String(localized: "Press ⌘ to release the mouse"))
                    }
                }
                .task(id: emulator.notice) {
                    guard let notice = emulator.notice else { return }
                    withAnimation { visibleNotice = notice }
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { visibleNotice = nil }
                }
                .navigationTitle(game.name)
                .navigationSubtitle(driveSummary)
                .dropDestination(for: URL.self) { urls, _ in
                    for (drive, url) in urls.prefix(2).enumerated() {
                        emulator.insert(url, into: drive)
                    }
                    return !urls.isEmpty
                }
                .toolbar {
                    ToolbarItemGroup {
                        driveMenu(0, game: game)
                        driveMenu(1, game: game)
                    }
                    ToolbarItemGroup {
                        Button("Save State", systemImage: "square.and.arrow.down") { saveStates.save(emulator) }
                            .help("Save the game as it is now (⌘S)")
                        restoreMenu(for: game)
                    }
                    ToolbarItem {
                        Toggle("Capture Mouse", systemImage: "computermouse", isOn: Binding(
                            get: { emulator.mouseCaptured },
                            set: { emulator.mouseCaptured = $0 }
                        ))
                        .help("Send the mouse to the PC-98 (press ⌘ to release)")
                    }
                    ToolbarItem {
                        Button("Reset", systemImage: "arrow.counterclockwise") { emulator.reset() }
                            .help("Reset the PC-98")
                    }
                }
        } else {
            ContentUnavailableView {
                Label("No Game Running", systemImage: "display")
            } description: {
                Text("Double-click a game in the sidebar to start it.")
            }
        }
    }

    private var driveSummary: String {
        var parts = emulator.drives.enumerated()
            .map { "FDD\($0.offset + 1): \($0.element?.lastPathComponent ?? "—")" }
        if let hardDisk = emulator.hardDisk {
            parts.insert("HDD: \(hardDisk.lastPathComponent)", at: 0)
        }
        return parts.joined(separator: "   ")
    }

    /// Saved states of `game`, newest first; choosing one restores it.
    private func restoreMenu(for game: Game) -> some View {
        let states = saveStates.states(for: game.id)
        return Menu {
            ForEach(states) { state in
                Button {
                    library.markPlayed(game.id)
                    saveStates.restore(state, of: game, in: emulator)
                } label: {
                    Label {
                        Text(state.date.formatted(date: .abbreviated, time: .shortened))
                    } icon: {
                        if let thumbnail = state.thumbnail {
                            Image(nsImage: thumbnail)
                        }
                    }
                }
            }
            if !states.isEmpty {
                Divider()
                Menu("Delete") {
                    ForEach(states) { state in
                        Button(state.date.formatted(date: .abbreviated, time: .shortened), role: .destructive) {
                            saveStates.delete(state)
                        }
                    }
                }
            }
            Button("Show Saved States in Finder") { saveStates.showInFinder(for: game.id) }
        } label: {
            Label("Restore", systemImage: "clock.arrow.circlepath")
        }
        .help("Go back to a saved state")
    }

    private func driveMenu(_ drive: Int, game: Game) -> some View {
        Menu {
            ForEach(game.floppies, id: \.self) { disk in
                Toggle(disk.lastPathComponent, isOn: Binding(
                    get: { emulator.drives[drive] == disk },
                    set: { if $0 { emulator.insert(disk, into: drive) } }
                ))
            }
            Divider()
            Button("Other Disk…") { choosingDiskForDrive = drive }
            Button("Eject") { emulator.eject(drive) }
                .disabled(emulator.drives[drive] == nil)
        } label: {
            Label("FDD\(drive + 1)", systemImage: "opticaldiscdrive")
        }
        .help("Change the disk in floppy drive \(drive + 1)")
    }
}

struct GameRow: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(game.name)
                    .lineLimit(1)
                Spacer()
                if let lastPlayed = game.lastPlayed {
                    Text(shortDate(lastPlayed))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text(diskSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var diskSummary: String {
        let floppies = game.floppies.count
        switch (game.hardDisk != nil, floppies) {
        case (true, 0): return String(localized: "Hard disk")
        case (true, _): return String(localized: "Hard disk, \(floppies) floppies")
        default: return String(localized: "\(floppies) floppies")
        }
    }
}

/// Like Mail: the time for today, then "Yesterday", the weekday, or the date.
func shortDate(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return date.formatted(date: .omitted, time: .shortened)
    }
    if calendar.isDateInYesterday(date) {
        return String(localized: "Yesterday")
    }
    if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: .now)).day, days < 7 {
        return date.formatted(.dateTime.weekday(.wide))
    }
    return date.formatted(date: .numeric, time: .omitted)
}
