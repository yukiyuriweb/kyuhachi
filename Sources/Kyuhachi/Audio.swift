import AVFoundation
import Synchronization

/// Stereo 16-bit samples handed from the core thread to the audio thread.
final class AudioRing: Sendable {
    private struct State {
        var samples: [Int16]
        var readIndex = 0
        var count = 0  // in frames
    }

    private let capacity: Int
    private let state: Mutex<State>

    init(capacityFrames: Int) {
        capacity = capacityFrames
        state = Mutex(State(samples: [Int16](repeating: 0, count: capacityFrames * 2)))
    }

    var bufferedFrames: Int {
        state.withLock { $0.count }
    }

    /// Appends interleaved stereo frames; the oldest frames are dropped when full.
    func write(_ data: UnsafePointer<Int16>, frames: Int) {
        state.withLock { s in
            for i in 0..<frames {
                if s.count == capacity {
                    s.readIndex = (s.readIndex + 1) % capacity
                    s.count -= 1
                }
                let w = (s.readIndex + s.count) % capacity
                s.samples[w * 2] = data[i * 2]
                s.samples[w * 2 + 1] = data[i * 2 + 1]
                s.count += 1
            }
        }
    }

    /// Fills `left` and `right` with up to `frames` frames, padding with silence.
    func read(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        state.withLock { s in
            for i in 0..<frames {
                if s.count > 0 {
                    left[i] = Float(s.samples[s.readIndex * 2]) / 32768
                    right[i] = Float(s.samples[s.readIndex * 2 + 1]) / 32768
                    s.readIndex = (s.readIndex + 1) % capacity
                    s.count -= 1
                } else {
                    left[i] = 0
                    right[i] = 0
                }
            }
        }
    }
}

/// Plays the core's audio through the default output device.
@MainActor
final class AudioOutput {
    private let engine = AVAudioEngine()

    init(ring: AudioRing) {
        let format = AVAudioFormat(standardFormatWithSampleRate: CoreRunner.sampleRate, channels: 2)!
        let source = AVAudioSourceNode(format: format, renderBlock: Self.renderBlock(reading: ring))
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
    }

    /// Made outside the main actor: the block runs on the audio I/O thread.
    private nonisolated static func renderBlock(reading ring: AudioRing) -> AVAudioSourceNodeRenderBlock {
        { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self)
            else { return noErr }
            ring.read(left: left, right: right, frames: Int(frameCount))
            return noErr
        }
    }

    func start() {
        do {
            try engine.start()
        } catch {
            NSLog("Kyuhachi: could not start audio: \(error)")
        }
    }
}
