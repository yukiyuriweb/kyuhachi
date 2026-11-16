import CNP2kai
import Foundation
import Observation
import SwiftUI

/// One of NP2kai's libretro core options, as shown in settings.
struct CoreOption: Identifiable {
    let key: String
    let title: LocalizedStringKey

    var id: String { key }

    /// The values the core accepts, in the core's order.
    var values: [String] {
        (0..<kyuhachi_option_value_count(key)).compactMap { index in
            kyuhachi_option_value(key, Int32(index)).map { String(cString: $0) }
        }
    }

    /// The core's default, or the middle value when the core's default is
    /// not one of its values (NP2kai's floppy seek volume defaults to "",
    /// which it reads as 0, so the seek sound is silent when switched on).
    var defaultValue: String {
        let values = values
        if let core = kyuhachi_option_default(key).map({ String(cString: $0) }), values.contains(core) {
            return core
        }
        return values.isEmpty ? "" : values[values.count / 2]
    }

    /// Whether the core's own default is unusable (see `defaultValue`).
    var hasBrokenDefault: Bool {
        guard let core = kyuhachi_option_default(key) else { return false }
        return kyuhachi_option_canonical(key, core) == nil
    }

    /// How a value reads in the UI.
    func label(for value: String) -> String {
        switch key {
        case "np2kai_clk_mult": return "×\(value)"
        case "np2kai_ExMemory": return "\(value) MB"
        case "np2kai_Seek_Snd": return value == "ON" ? String(localized: "On") : String(localized: "Off")
        default: return value
        }
    }
}

@MainActor
enum CoreOptions {
    /// Options that shape the emulated machine. They take effect at the
    /// next reset, and a game can override them.
    static let machine: [CoreOption] = [
        CoreOption(key: "np2kai_model", title: "Model"),
        CoreOption(key: "np2kai_clk_base", title: "CPU base clock"),
        CoreOption(key: "np2kai_clk_mult", title: "CPU clock multiplier"),
        CoreOption(key: "np2kai_ExMemory", title: "Memory"),
        CoreOption(key: "np2kai_SNDboard", title: "Sound board"),
    ]

    /// Volumes take effect immediately.
    static let volumes: [CoreOption] = [
        CoreOption(key: "np2kai_volume_M", title: "Master"),
        CoreOption(key: "np2kai_volume_F", title: "FM"),
        CoreOption(key: "np2kai_volume_S", title: "SSG"),
        CoreOption(key: "np2kai_volume_A", title: "ADPCM"),
        CoreOption(key: "np2kai_volume_P", title: "PCM"),
        CoreOption(key: "np2kai_volume_R", title: "Rhythm"),
        CoreOption(key: "np2kai_BEEP_vol", title: "Beep"),
    ]

    static let seekSound = CoreOption(key: "np2kai_Seek_Snd", title: "Floppy seek sound")
    static let seekVolume = CoreOption(key: "np2kai_Seek_Vol", title: "Seek sound volume")

    /// Replacement defaults for options whose core default is unusable.
    static let repairedDefaults: [String: String] = Dictionary(
        uniqueKeysWithValues: (machine + volumes + [seekSound, seekVolume])
            .filter(\.hasBrokenDefault)
            .map { ($0.key, $0.defaultValue) })
}

/// How the 640×400 screen is shaped in the window.
enum ScreenAspect: String, CaseIterable, Identifiable {
    /// Square pixels: 16:10, as the image is.
    case square
    /// Stretched to 4:3, like the CRT monitors PC-98s were used with.
    case monitor

    var id: String { rawValue }

    var ratio: CGFloat {
        switch self {
        case .square: 640.0 / 400.0
        case .monitor: 4.0 / 3.0
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .square: "Square pixels (16:10)"
        case .monitor: "Monitor (4:3)"
        }
    }
}

/// App-wide settings, kept in UserDefaults.
@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()

    /// Core options changed from NP2kai's defaults, by key.
    var coreOptions: [String: String] {
        didSet {
            UserDefaults.standard.set(coreOptions, forKey: "coreOptions")
            Emulator.shared.refreshOptions()
        }
    }

    var aspect: ScreenAspect {
        didSet { UserDefaults.standard.set(aspect.rawValue, forKey: "screenAspect") }
    }

    private init() {
        coreOptions = UserDefaults.standard.dictionary(forKey: "coreOptions") as? [String: String] ?? [:]
        aspect = UserDefaults.standard.string(forKey: "screenAspect").flatMap(ScreenAspect.init) ?? .square
    }

    /// The value in effect app-wide.
    func value(of option: CoreOption) -> String {
        coreOptions[option.key] ?? option.defaultValue
    }

    func binding(for option: CoreOption) -> Binding<String> {
        Binding(
            get: { self.value(of: option) },
            set: { self.coreOptions[option.key] = ($0 == option.defaultValue) ? nil : $0 }
        )
    }
}
