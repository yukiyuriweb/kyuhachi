import CNP2kai
import CoreGraphics
import Foundation
import Synchronization

/// Runs the NP2kai core on its own thread at the PC-98's frame rate.
///
/// The core is not thread-safe, so everything that touches it (disk changes,
/// key presses, resets) is queued with `perform` and runs on the core thread
/// between frames. Frames and audio leave through `onFrame` and `audio`.
final class CoreRunner: @unchecked Sendable {
    static let shared = CoreRunner()

    /// PC-98 display refresh rate, as the libretro port reports it.
    static let framesPerSecond = 56.4
    static let sampleRate = 44_100.0

    let audio = AudioRing(capacityFrames: Int(sampleRate / 2))

    /// Called on the core thread with each finished frame.
    nonisolated(unsafe) var onFrame: (@Sendable (CGImage) -> Void)?

    private let jobs = Mutex<[@Sendable () -> Void]>([])
    /// Core options that differ from NP2kai's defaults, and whether the
    /// core has yet to read them.
    private let options = Mutex<(values: [String: String], changed: Bool)>(([:], false))
    private let mouseInput = Mutex(MouseState())

    // Core-thread state.
    private var started = false
    private var pixelFormat = RETRO_PIXEL_FORMAT_RGB565
    private var polledMouse = MouseState()
    private var systemDirectory: UnsafeMutablePointer<CChar>?

    struct MouseState {
        var dx = 0
        var dy = 0
        var left = false
        var right = false
    }

    /// Initialises the core and starts the frame loop. Call once.
    func start(systemDirectory: URL, font: URL?) {
        precondition(!started)
        started = true
        self.systemDirectory = strdup(systemDirectory.path)

        retro_set_environment(coreEnvironment)
        retro_set_video_refresh(coreVideoRefresh)
        retro_set_audio_sample { _, _ in }
        retro_set_audio_sample_batch(coreAudioBatch)
        retro_set_input_poll(coreInputPoll)
        retro_set_input_state(coreInputState)

        if let font {
            fontmng_setdeffontname(font.path)
        }
        retro_init()
        _ = retro_load_game(nil)

        let thread = Thread { [self] in
            // The first frame boots the virtual machine; jobs need it booted.
            retro_run()
            runLoop()
        }
        thread.name = "NP2kai"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// Sets the core options; the core picks them up before its next frame.
    func setOptions(_ values: [String: String]) {
        options.withLock { $0 = (values, true) }
    }

    /// Runs `job` on the core thread before the next frame.
    func perform(_ job: @escaping @Sendable () -> Void) {
        jobs.withLock { $0.append(job) }
    }

    func moveMouse(dx: Int, dy: Int) {
        mouseInput.withLock {
            $0.dx += dx
            $0.dy += dy
        }
    }

    func setMouseButton(left: Bool? = nil, right: Bool? = nil) {
        mouseInput.withLock {
            if let left { $0.left = left }
            if let right { $0.right = right }
        }
    }

    // MARK: Core thread

    private func runLoop() {
        let period = UInt64(1_000_000_000 / Self.framesPerSecond)
        var next = DispatchTime.now().uptimeNanoseconds
        while true {
            let pending = jobs.withLock { queue in
                let pending = queue
                queue.removeAll()
                return pending
            }
            for job in pending {
                job()
            }
            retro_run()

            next += period
            let now = DispatchTime.now().uptimeNanoseconds
            if next > now {
                // Let the audio buffer drain a little if the core runs ahead of it.
                let extra: UInt64 = audio.bufferedFrames > Int(Self.sampleRate / 8) ? 2_000_000 : 0
                Thread.sleep(forTimeInterval: Double(next - now + extra) / 1_000_000_000)
            } else if now - next > period * 5 {
                next = now  // Fell far behind (e.g. the Mac slept); don't try to catch up.
            }
        }
    }

    fileprivate func environment(_ command: UInt32, _ data: UnsafeMutableRawPointer?) -> Bool {
        switch Int32(command) {
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            data?.assumingMemoryBound(to: UnsafePointer<CChar>?.self).pointee = UnsafePointer(systemDirectory)
            return true
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
            guard let data else { return false }
            let format = data.assumingMemoryBound(to: retro_pixel_format.self).pointee
            guard format == RETRO_PIXEL_FORMAT_RGB565 || format == RETRO_PIXEL_FORMAT_XRGB8888 else { return false }
            pixelFormat = format
            return true
        case RETRO_ENVIRONMENT_GET_VARIABLE:
            // Answer with the user's choice, or else the option's default as
            // RetroArch does. (Without an answer the core leaves some features
            // off; the mouse, for one, only works when "np2kai_inputmouse" is ON.)
            guard let variable = data?.assumingMemoryBound(to: retro_variable.self),
                  let key = variable.pointee.key
            else { return false }
            let chosen = options.withLock { $0.values[String(cString: key)] }
            // The core keeps the pointer, so hand it the option table's own string.
            guard let value = chosen.flatMap({ kyuhachi_option_canonical(key, $0) }) ?? kyuhachi_option_default(key)
            else { return false }
            variable.pointee.value = value
            return true
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            guard let data else { return false }
            data.assumingMemoryBound(to: Bool.self).pointee = options.withLock { state in
                defer { state.changed = false }
                return state.changed
            }
            return true
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME, RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE:
            return true
        default:
            return false
        }
    }

    fileprivate func videoRefresh(_ data: UnsafeRawPointer?, _ width: Int, _ height: Int, _ pitch: Int) {
        guard let data, width > 0, height > 0, let onFrame else { return }
        var pixels = [UInt32](repeating: 0, count: width * height)
        pixels.withUnsafeMutableBufferPointer { out in
            if pixelFormat == RETRO_PIXEL_FORMAT_RGB565 {
                for y in 0..<height {
                    let row = (data + y * pitch).assumingMemoryBound(to: UInt16.self)
                    for x in 0..<width {
                        let v = UInt32(row[x])
                        let r = (v >> 11) & 0x1f, g = (v >> 5) & 0x3f, b = v & 0x1f
                        let r8 = r << 3 | r >> 2, g8 = g << 2 | g >> 4, b8 = b << 3 | b >> 2
                        out[y * width + x] = 0xff00_0000 | r8 << 16 | g8 << 8 | b8
                    }
                }
            } else {
                for y in 0..<height {
                    let row = (data + y * pitch).assumingMemoryBound(to: UInt32.self)
                    for x in 0..<width {
                        out[y * width + x] = 0xff00_0000 | row[x]
                    }
                }
            }
        }
        let provider = CGDataProvider(data: Data(bytes: pixels, count: pixels.count * 4) as CFData)!
        let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        if let image {
            onFrame(image)
        }
    }

    fileprivate func pollInput() {
        polledMouse = mouseInput.withLock { state in
            let snapshot = state
            state.dx = 0
            state.dy = 0
            return snapshot
        }
    }

    fileprivate func inputState(device: UInt32, id: UInt32) -> Int16 {
        // The keyboard is fed directly with PC-98 key codes (see KeyMap), so
        // only the mouse goes through libretro.
        guard device == RETRO_DEVICE_MOUSE else { return 0 }
        switch Int32(id) {
        case RETRO_DEVICE_ID_MOUSE_X: return Int16(clamping: polledMouse.dx)
        case RETRO_DEVICE_ID_MOUSE_Y: return Int16(clamping: polledMouse.dy)
        case RETRO_DEVICE_ID_MOUSE_LEFT: return polledMouse.left ? 1 : 0
        case RETRO_DEVICE_ID_MOUSE_RIGHT: return polledMouse.right ? 1 : 0
        default: return 0
        }
    }
}

// libretro takes plain C function pointers, so these forward to the runner.

private func coreEnvironment(_ command: UInt32, _ data: UnsafeMutableRawPointer?) -> Bool {
    CoreRunner.shared.environment(command, data)
}

private func coreVideoRefresh(_ data: UnsafeRawPointer?, _ width: UInt32, _ height: UInt32, _ pitch: Int) {
    CoreRunner.shared.videoRefresh(data, Int(width), Int(height), pitch)
}

private func coreAudioBatch(_ data: UnsafePointer<Int16>?, _ frames: Int) -> Int {
    if let data {
        CoreRunner.shared.audio.write(data, frames: frames)
    }
    return frames
}

private func coreInputPoll() {
    CoreRunner.shared.pollInput()
}

private func coreInputState(_ port: UInt32, _ device: UInt32, _ index: UInt32, _ id: UInt32) -> Int16 {
    port == 0 ? CoreRunner.shared.inputState(device: device, id: id) : 0
}
