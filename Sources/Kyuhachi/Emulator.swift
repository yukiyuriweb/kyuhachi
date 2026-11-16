import CNP2kai
import Foundation
import Observation
import QuartzCore
import Synchronization

/// The one emulated PC-98 in this app (NP2kai keeps its machine in globals,
/// so there can only be one per process).
@MainActor @Observable
final class Emulator {
    static let shared = Emulator()

    /// The game whose disks were last put in, if any.
    private(set) var currentGameID: Game.ID?
    /// The disk image in each floppy drive.
    private(set) var drives: [URL?] = [nil, nil]
    /// The hard disk image on the first IDE drive.
    private(set) var hardDisk: URL?
    /// Whether the Mac's mouse is captured: hidden, held in place, and its
    /// movement and clicks sent to the PC-98.
    var mouseCaptured = false

    /// A short message shown over the screen for a moment.
    struct Notice: Equatable {
        let id = UUID()
        let text: String
    }
    private(set) var notice: Notice?

    /// Shows the latest frame; screen views host this layer.
    @ObservationIgnored let screenLayer: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = CGColor.black
        layer.contentsGravity = .resizeAspect
        layer.magnificationFilter = .nearest
        return layer
    }()

    @ObservationIgnored private var started = false
    @ObservationIgnored private var audio: AudioOutput?
    @ObservationIgnored private let mailbox = FrameMailbox()
    private var runner: CoreRunner { .shared }

    static let supportDirectory: URL = {
        let url = URL.applicationSupportDirectory.appendingPathComponent("Kyuhachi", isDirectory: true)
        // NP2kai keeps its settings and generated font ROM in <system dir>/np2kai.
        try? FileManager.default.createDirectory(at: url.appendingPathComponent("np2kai"), withIntermediateDirectories: true)
        return url
    }()

    /// Connects the game's hard disk (if any), puts its first two floppies
    /// in the drives and restarts the machine.
    func play(_ game: Game) {
        startIfNeeded()
        currentGameID = game.id
        let floppies = Array(game.floppies.prefix(2))
        drives = [floppies.first, floppies.count > 1 ? floppies[1] : nil]
        hardDisk = game.hardDisk
        let paths = drives.map { $0?.path }
        let hardDiskPath = hardDisk?.path
        runner.perform {
            // The hard disk is attached by the reset below.
            kyuhachi_set_hdd(0, hardDiskPath)
            for (drive, path) in paths.enumerated() {
                if let path {
                    kyuhachi_ready_fdd(UInt32(drive), path)
                } else {
                    kyuhachi_eject_fdd(UInt32(drive))
                }
            }
            retro_reset()
        }
    }

    func insert(_ url: URL, into drive: Int) {
        drives[drive] = url
        let path = url.path
        runner.perform { kyuhachi_set_fdd(UInt32(drive), path) }
    }

    func eject(_ drive: Int) {
        drives[drive] = nil
        runner.perform { kyuhachi_eject_fdd(UInt32(drive)) }
    }

    func reset() {
        runner.perform { retro_reset() }
    }

    func showNotice(_ text: String) {
        notice = Notice(text: text)
    }

    /// The frame on screen now.
    var currentFrame: CGImage? {
        screenLayer.contents.map { $0 as! CGImage }
    }

    /// Saves the machine state to `url`; calls `completion` with the result.
    func saveState(to url: URL, completion: @escaping @MainActor (Bool) -> Void) {
        let path = url.path
        runner.perform {
            let ok = kyuhachi_save_state(path) == 1
            Task { @MainActor in completion(ok) }
        }
    }

    /// Restores a state of `game`, including the disks it had in its drives.
    func loadState(from url: URL, game: Game, completion: @escaping @MainActor (Bool) -> Void) {
        startIfNeeded()
        currentGameID = game.id
        let path = url.path
        runner.perform {
            let ok = kyuhachi_load_state(path) == 1
            let floppies = (0..<2).map { kyuhachi_fdd_path(UInt32($0)).map { String(cString: $0) } }
            let hardDisk = kyuhachi_hdd_path(0).map { String(cString: $0) }
            Task { @MainActor in
                let emulator = Emulator.shared
                emulator.drives = floppies.map { $0.map { URL(fileURLWithPath: $0) } }
                emulator.hardDisk = hardDisk.map { URL(fileURLWithPath: $0) }
                completion(ok)
            }
        }
    }

    func key(_ code: UInt8, down: Bool) {
        runner.perform {
            if down {
                kyuhachi_key_down(code)
            } else {
                kyuhachi_key_up(code)
            }
        }
    }

    func moveMouse(dx: Int, dy: Int) {
        runner.moveMouse(dx: dx, dy: dy)
    }

    func setMouseButton(left: Bool? = nil, right: Bool? = nil) {
        runner.setMouseButton(left: left, right: right)
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true

        let mailbox = mailbox
        runner.onFrame = { image in
            // Only one frame waits for the main thread at a time; newer ones replace it.
            if mailbox.put(image) {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { Emulator.shared.presentFrame() }
                }
            }
        }
        // NP2kai caches the font ROM it builds from the TrueType font in
        // font.tmp; rebuild it each launch so it always matches the font.
        try? FileManager.default.removeItem(at: Self.supportDirectory.appendingPathComponent("np2kai/font.tmp"))
        let font = Bundle.main.url(forResource: "JF-Dot-ShinonomeMin16", withExtension: "ttf")
        runner.start(systemDirectory: Self.supportDirectory, font: font)

        let audio = AudioOutput(ring: runner.audio)
        audio.start()
        self.audio = audio
    }

    private func presentFrame() {
        guard let image = mailbox.take() else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        screenLayer.contents = image
        CATransaction.commit()
    }
}

/// Holds at most one frame on its way to the main thread.
final class FrameMailbox: Sendable {
    private let slot = Mutex<CGImage?>(nil)

    /// Stores the frame; returns true if the slot was empty (so the main
    /// thread needs to be told).
    func put(_ image: CGImage) -> Bool {
        slot.withLock { slot in
            defer { slot = image }
            return slot == nil
        }
    }

    func take() -> CGImage? {
        slot.withLock { slot in
            defer { slot = nil }
            return slot
        }
    }
}
