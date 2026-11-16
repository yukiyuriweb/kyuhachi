import SwiftUI

/// The Settings window (⌘,): app-wide defaults.
struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                ForEach(CoreOptions.machine) { option in
                    OptionPicker(option: option, selection: settings.binding(for: option))
                }
            } header: {
                Text("Machine")
            } footer: {
                Text("Takes effect when a game starts or the PC-98 is reset. Games can override these in Game Settings.")
                    .foregroundStyle(.secondary)
            }

            Section("Sound") {
                ForEach(CoreOptions.volumes) { option in
                    OptionSlider(option: option, selection: settings.binding(for: option))
                }
                Toggle(CoreOptions.seekSound.title, isOn: Binding(
                    get: { settings.value(of: CoreOptions.seekSound) == "ON" },
                    set: { settings.binding(for: CoreOptions.seekSound).wrappedValue = $0 ? "ON" : "OFF" }
                ))
                OptionSlider(option: CoreOptions.seekVolume, selection: settings.binding(for: CoreOptions.seekVolume))
                    .disabled(settings.value(of: CoreOptions.seekSound) != "ON")
            }

            Section("Display") {
                Picker("Screen shape", selection: $settings.aspect) {
                    ForEach(ScreenAspect.allCases) { aspect in
                        Text(aspect.title).tag(aspect)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Per-game overrides of the machine options.
struct GameSettingsView: View {
    let game: Game
    let library: Library
    let settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let current = library.game(game.id) ?? game
        let overrides = current.options ?? [:]
        VStack(spacing: 0) {
            Form {
                Section {
                    ForEach(CoreOptions.machine) { option in
                        Picker(option.title, selection: Binding<String?>(
                            get: { overrides[option.key] },
                            set: { library.setOption(option.key, to: $0, for: game.id) }
                        )) {
                            Text("Default (\(option.label(for: settings.value(of: option))))")
                                .tag(String?.none)
                            Divider()
                            ForEach(option.values, id: \.self) { value in
                                Text(option.label(for: value)).tag(String?.some(value))
                            }
                        }
                    }
                } header: {
                    Text(game.name)
                } footer: {
                    Text("Takes effect the next time this game starts or the PC-98 is reset.")
                        .foregroundStyle(.secondary)
                }
                if !current.floppies.isEmpty {
                    Section {
                        ForEach(0..<2, id: \.self) { drive in
                            Picker("FDD\(drive + 1)", selection: Binding<URL?>(
                                get: { current.startFloppies[drive] },
                                set: { library.setStartDisk($0, drive: drive, for: game.id) }
                            )) {
                                Text("None").tag(URL?.none)
                                Divider()
                                ForEach(current.floppies, id: \.self) { disk in
                                    Text(disk.lastPathComponent).tag(URL?.some(disk))
                                }
                            }
                        }
                    } header: {
                        Text("Startup Disks")
                    } footer: {
                        Text("Put in the drives when this game starts.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct OptionPicker: View {
    let option: CoreOption
    let selection: Binding<String>

    var body: some View {
        Picker(option.title, selection: selection) {
            ForEach(option.values, id: \.self) { value in
                Text(option.label(for: value)).tag(value)
            }
        }
    }
}

/// A volume: the core's list of levels as a slider.
private struct OptionSlider: View {
    let option: CoreOption
    let selection: Binding<String>

    var body: some View {
        let values = option.values
        LabeledContent(option.title) {
            HStack {
                Slider(
                    value: Binding(
                        get: { Double(values.firstIndex(of: selection.wrappedValue) ?? 0) },
                        set: { selection.wrappedValue = values[Int($0.rounded())] }
                    ),
                    in: 0...Double(max(values.count - 1, 1)),
                    step: 1
                )
                Text(selection.wrappedValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
            .frame(width: 220)
        }
    }
}
