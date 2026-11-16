import AppKit
import Foundation
import Observation

/// One saved machine state: the state file plus a screenshot beside it.
struct SaveState: Identifiable, Hashable {
    let url: URL
    let date: Date

    var id: URL { url }
    var thumbnailURL: URL { url.deletingPathExtension().appendingPathExtension("png") }

    /// A small copy of the screenshot for menus.
    var thumbnail: NSImage? {
        guard let image = NSImage(contentsOf: thumbnailURL) else { return nil }
        image.size = NSSize(width: 64, height: 40)
        return image
    }
}

/// Saved states, one folder per game under Application Support/Kyuhachi/States.
@MainActor @Observable
final class SaveStateStore {
    static let shared = SaveStateStore()

    /// Bumped on every change, so views that list states refresh.
    private var revision = 0
    private let root = Emulator.supportDirectory.appendingPathComponent("States", isDirectory: true)

    /// The game's states, newest first.
    func states(for gameID: Game.ID) -> [SaveState] {
        _ = revision
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory(for: gameID), includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files
            .filter { $0.pathExtension == "np2s" }
            .map { url in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return SaveState(url: url, date: date ?? .distantPast)
            }
            .sorted { $0.date > $1.date }
    }

    /// Saves the running machine as a new state of the current game.
    func save(_ emulator: Emulator) {
        guard let gameID = emulator.currentGameID else { return }
        let folder = directory(for: gameID)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"  // local time
        let name = formatter.string(from: .now)
        var url = folder.appendingPathComponent(name).appendingPathExtension("np2s")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(name)-\(n)").appendingPathExtension("np2s")
            n += 1
        }
        let state = SaveState(url: url, date: .now)
        let screenshot = emulator.currentFrame
        emulator.saveState(to: url) { [self] ok in
            if ok, let screenshot,
               let png = NSBitmapImageRep(cgImage: screenshot).representation(using: .png, properties: [:]) {
                try? png.write(to: state.thumbnailURL)
            }
            revision += 1
            emulator.showNotice(ok ? String(localized: "State saved") : String(localized: "Could not save the state"))
        }
    }

    func restore(_ state: SaveState, of game: Game, in emulator: Emulator) {
        emulator.loadState(from: state.url, game: game) { ok in
            emulator.showNotice(ok ? String(localized: "State restored") : String(localized: "Could not restore the state"))
        }
    }

    func delete(_ state: SaveState) {
        try? FileManager.default.removeItem(at: state.url)
        try? FileManager.default.removeItem(at: state.thumbnailURL)
        revision += 1
    }

    func showInFinder(for gameID: Game.ID) {
        let folder = directory(for: gameID)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    private func directory(for gameID: Game.ID) -> URL {
        root.appendingPathComponent(gameID.uuidString, isDirectory: true)
    }
}
