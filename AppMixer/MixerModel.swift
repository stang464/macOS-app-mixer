import AppKit
import SwiftUI

struct AppSetting: Codable {
    var volume: Double = 1
    var muted = false
    var gain: Float { muted ? 0 : Float(volume) }
}

struct MixerRow: Identifiable {
    var id: String { app.key }
    let app: AudioApplication
    var setting: AppSetting
    var controlling: Bool
    var error: Error?
}

@MainActor
final class MixerModel: ObservableObject {
    @Published var outputDevices: [AudioDeviceInfo] = []
    @Published var inputDevices: [AudioDeviceInfo] = []
    @Published var selectedOutput: AudioObjectID = 0
    @Published var selectedInput: AudioObjectID = 0
    @Published var deviceError: Error?
    @Published var deviceReadError: Error?
    @Published var rows: [MixerRow] = []
    @Published var enabled = false
    @Published var outputName = "กำลังค้นหาอุปกรณ์เสียง…"
    @Published var error: Error?
    @Published var master = MasterVolumeState()
    @Published var masterError: Error?
    private var lastAudibleVolumes: [AudioObjectID: Double] = [:]
    private var settings: [String: AppSetting] = [:]
    private var routes: [String: AppAudioRoute] = [:]
    private var failures: [String: Error] = [:]
    private var output: AudioObjectID = 0
    private var outputRate: Double = 0
    private var timer: Timer?
    private let defaultsKey = "AppMixer.applicationLevels.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([String: AppSetting].self, from: data) {
            settings = saved.mapValues { value in
                var clean = value
                clean.volume = value.volume.isFinite ? min(1, max(0, value.volume)) : 1
                return clean
            }
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func toggleEnabled() {
        enabled.toggle()
        failures.removeAll()
        if !enabled { stopRoutes() }
        refresh()
    }
    func stopRoutes() {
        routes.values.forEach { $0.stop() }
        routes.removeAll()
    }
    func update(_ key: String, volume: Double? = nil, mute: Bool? = nil) {
        var setting = settings[key] ?? AppSetting()
        if let volume { setting.volume = min(1, max(0, volume)) }
        if let mute { setting.muted = mute }
        settings[key] = setting
        if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: defaultsKey) }
        // A failed route is retried explicitly, not every tick or slider event.
        refresh()
    }
    func retry() { failures.removeAll(); deviceError = nil; refresh() }
    func selectDevice(_ id: AudioObjectID, direction: AudioDeviceDirection) {
        do {
            // Changing a Bluetooth microphone can also change the output stream format.
            stopRoutes()
            try AudioDevices.select(id, direction: direction)
            failures.removeAll()
            deviceError = nil
        } catch {
            deviceError = error
        }
        refresh()
    }
    private func refreshDevices() {
        do {
            outputDevices = try AudioDevices.available(.output)
            inputDevices = try AudioDevices.available(.input)
            selectedOutput = (try? AudioDevices.current(.output)) ?? 0
            selectedInput = (try? AudioDevices.current(.input)) ?? 0
            deviceReadError = nil
        } catch {
            outputDevices = []
            inputDevices = []
            selectedOutput = 0
            selectedInput = 0
            deviceReadError = error
        }
    }
    // Master changes the system output, independently of per-app processing.
    func setMasterVolume(_ volume: Double) {
        do {
            let device = try HAL.defaultOutput()
            let state = try SystemMaster.read(device)
            try SystemMaster.setVolume(device, volume)
            if volume > 0, state.muted, state.canMute { try SystemMaster.setMute(device, false) }
            refreshMaster(device)
        } catch {
            masterError = error
        }
    }
    func toggleMasterMute() {
        do {
            let device = try HAL.defaultOutput()
            let state = try SystemMaster.read(device)
            if let volume = state.volume, volume > 0 { lastAudibleVolumes[device] = volume }
            if state.canMute {
                // At zero volume, unmute also restores the last audible level.
                if state.silent, state.volume == 0, state.canSetVolume {
                    try SystemMaster.setVolume(device, lastAudibleVolumes[device] ?? 0.25)
                }
                try SystemMaster.setMute(device, !state.silent)
            } else if state.canSetVolume {
                try SystemMaster.setVolume(device, state.silent ? (lastAudibleVolumes[device] ?? 0.25) : 0)
            }
            refreshMaster(device)
        } catch {
            masterError = error
        }
    }
    private func refreshMaster(_ device: AudioObjectID) {
        do {
            master = try SystemMaster.read(device)
            if let volume = master.volume, volume > 0 { lastAudibleVolumes[device] = volume }
            masterError = nil
        } catch {
            master = MasterVolumeState()
            masterError = error
        }
    }
    func reset() {
        settings.removeAll()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        failures.removeAll()
        stopRoutes()
        refresh()
    }
    func refresh() {
        refreshDevices()
        do {
            let newOutput = try HAL.defaultOutput()
            guard newOutput != 0 else { throw AudioFailure(message: "ไม่พบอุปกรณ์เสียงออก") }
            let newRate = (try? HAL.value(newOutput, kAudioDevicePropertyNominalSampleRate, initial: Float64(0))) ?? 0
            if newOutput != output || newRate != outputRate {
                stopRoutes()
                output = newOutput
                outputRate = newRate
                failures.removeAll()
            }
            outputName = (try? HAL.string(output, kAudioObjectPropertyName)) ?? "System output"
            refreshMaster(output)
            let applications = try ProcessDiscovery.applications()
            let live = Set(applications.map(\.key))
            for key in Array(routes.keys) where !live.contains(key) {
                routes.removeValue(forKey: key)?.stop()
            }
            for key in Array(failures.keys) where !live.contains(key) { failures.removeValue(forKey: key) }
            for app in applications {
                let setting = settings[app.key] ?? AppSetting()
                let needsRoute = enabled && setting.gain < 0.9999
                if !needsRoute {
                    routes.removeValue(forKey: app.key)?.stop()
                    failures.removeValue(forKey: app.key)
                    continue
                }
                if let route = routes[app.key], route.processes != app.processes.sorted() {
                    routes.removeValue(forKey: app.key)?.stop()
                }
                if let route = routes[app.key] {
                    route.setGain(setting.gain)
                } else if app.active && failures[app.key] == nil {
                    do { routes[app.key] = try AppAudioRoute(app: app, output: output, gain: setting.gain) }
                    catch { failures[app.key] = error }
                }
            }
            rows = applications.filter { $0.active || routes[$0.key] != nil || settings[$0.key] != nil }.map {
                MixerRow(app: $0, setting: settings[$0.key] ?? AppSetting(), controlling: routes[$0.key] != nil, error: failures[$0.key])
            }
            error = nil
        } catch {
            stopRoutes()
            master = MasterVolumeState()
            self.error = error
        }
    }
}
