import Foundation
import Observation

/// A game: a name and the disk images that make it up, in order. A game
/// may have a hard disk image as well as (or instead of) floppies.
struct Game: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var disks: [URL]
    var lastPlayed: Date?
    /// Core options this game overrides (machine settings it needs), by key.
    var options: [String: String]? = nil

    var floppies: [URL] {
        disks.filter { floppyExtensions.contains($0.pathExtension.lowercased()) }
    }

    var hardDisk: URL? {
        disks.first { hardDiskExtensions.contains($0.pathExtension.lowercased()) }
    }
}

/// File extensions NP2kai reads as floppy disk images (as in its own file dialog).
let floppyExtensions: Set<String> = [
    "d88", "88d", "d98", "98d", "fdi", "xdf", "hdm", "dup", "2hd", "tfd", "nfd", "hd4", "hd5", "hd9",
    "fdd", "h01", "hdb", "ddb", "dd6", "dcp", "dcu", "flp", "bin", "fim", "img", "ima", "vfdd",
]

/// File extensions NP2kai reads as IDE/SASI hard disk images.
let hardDiskExtensions: Set<String> = ["hdi", "thd", "nhd", "vhd", "sln"]

/// The user's games, kept in Application Support.
@MainActor @Observable
final class Library {
    private(set) var games: [Game] = []
    private let fileURL: URL

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("Library.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Game].self, from: data) {
            games = saved
        }
    }

    func game(_ id: Game.ID) -> Game? {
        games.first { $0.id == id }
    }

    /// Adds one game made of the given disk images and returns it.
    /// Returns nil when none of the files is a disk image.
    @discardableResult
    func addGame(from urls: [URL]) -> Game? {
        let disks = urls
            .filter {
                let ext = $0.pathExtension.lowercased()
                return floppyExtensions.contains(ext) || hardDiskExtensions.contains(ext)
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        guard !disks.isEmpty else { return nil }
        let game = Game(name: Self.suggestedName(for: disks), disks: disks)
        games.append(game)
        save()
        return game
    }

    func rename(_ id: Game.ID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let i = games.firstIndex(where: { $0.id == id }) else { return }
        games[i].name = name
        save()
    }

    /// Adds a disk image to the end of a game's disks.
    func addDisk(_ url: URL, to id: Game.ID) {
        guard let i = games.firstIndex(where: { $0.id == id }), !games[i].disks.contains(url) else { return }
        games[i].disks.append(url)
        save()
    }

    func remove(_ ids: Set<Game.ID>) {
        games.removeAll { ids.contains($0.id) }
        save()
    }

    /// Sets (or, with nil, clears) a core option override for one game.
    func setOption(_ key: String, to value: String?, for id: Game.ID) {
        guard let i = games.firstIndex(where: { $0.id == id }) else { return }
        var options = games[i].options ?? [:]
        options[key] = value
        games[i].options = options.isEmpty ? nil : options
        save()
        if Emulator.shared.currentGameID == id {
            Emulator.shared.refreshOptions(gameOverrides: games[i].options ?? [:])
        }
    }

    func markPlayed(_ id: Game.ID) {
        guard let i = games.firstIndex(where: { $0.id == id }) else { return }
        games[i].lastPlayed = .now
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(games)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Kyuhachi: could not save library: \(error)")
        }
    }

    /// A name for a set of disks: the part of the file names they share
    /// ("Foo Disk A.fdi", "Foo Disk B.fdi" → "Foo"), or else the folder name.
    static func suggestedName(for disks: [URL]) -> String {
        let names = disks.map { $0.deletingPathExtension().lastPathComponent }
        if names.count == 1 {
            return names[0]
        }
        var prefix = names[0]
        for name in names.dropFirst() {
            prefix = String(prefix.commonPrefix(with: name))
        }
        let trimmed = prefix
            .replacingOccurrences(of: #"(?i)[\s_\-(\[]*(disk|disc|fd)?[\s_\-(\[]*$"#, with: "", options: .regularExpression)
        if trimmed.count >= 2 {
            return trimmed
        }
        return disks[0].deletingLastPathComponent().lastPathComponent
    }
}
