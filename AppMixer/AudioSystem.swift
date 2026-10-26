import AppKit
import CoreAudio
import AudioToolbox

struct AudioFailure: LocalizedError {
    let message: String
    var detail: String? = nil
    var status: OSStatus? = nil
    var captureHint = false
    var errorDescription: String? {
        var text = L10n.text(message)
        if let detail { text += " · " + detail }
        if let status { text += " (Core Audio \(status))" }
        if captureHint { text += ". " + L10n.text("หากเกี่ยวกับสิทธิ์ ให้ตรวจ System Settings → Privacy & Security → Screen & System Audio Recording") }
        return text
    }
}

enum HAL {
    static let system = AudioObjectID(kAudioObjectSystemObject)
    static func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
    static func check(_ status: OSStatus, _ action: String, detail: String? = nil) throws {
        guard status == noErr else { throw AudioFailure(message: action, detail: detail, status: status, captureHint: true) }
    }
    static func value<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, initial: T, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> T {
        var result = initial, a = address(selector, scope), size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutableBytes(of: &result) { AudioObjectGetPropertyData(id, &a, 0, nil, &size, $0.baseAddress!) }
        try check(status, "อ่านข้อมูลเสียงไม่ได้")
        return result
    }
    static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String {
        var result: Unmanaged<CFString>?, a = address(selector), size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(id, &a, 0, nil, &size, &result), "อ่านชื่ออุปกรณ์ไม่ได้")
        return result?.takeRetainedValue() as String? ?? ""
    }
    static func objects(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> [AudioObjectID] {
        var a = address(selector, scope), size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size), "อ่านรายการเสียงไม่ได้")
        guard size > 0 else { return [] }
        var result = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let status = result.withUnsafeMutableBytes { AudioObjectGetPropertyData(id, &a, 0, nil, &size, $0.baseAddress!) }
        try check(status, "อ่านรายการเสียงไม่ได้")
        return Array(result.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }
    static func defaultOutput() throws -> AudioObjectID {
        try value(system, kAudioHardwarePropertyDefaultOutputDevice, initial: AudioObjectID(0))
    }
}

enum AudioDeviceDirection {
    case input, output
    var scope: AudioObjectPropertyScope { self == .input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput }
    var defaultSelector: AudioObjectPropertySelector { self == .input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice }
}

struct AudioDeviceInfo: Identifiable, Equatable {
    let id: AudioObjectID
    let uid: String
    let name: String
}

enum AudioDevices {
    static func current(_ direction: AudioDeviceDirection) throws -> AudioObjectID {
        try HAL.value(HAL.system, direction.defaultSelector, initial: AudioObjectID(0))
    }
    static func available(_ direction: AudioDeviceDirection) throws -> [AudioDeviceInfo] {
        let devices = try HAL.objects(HAL.system, kAudioHardwarePropertyDevices)
        return devices.compactMap { device in
            guard let uid = try? HAL.string(device, kAudioDevicePropertyDeviceUID), !uid.hasPrefix("appmixer."),
                  let name = try? HAL.string(device, kAudioObjectPropertyName),
                  let streams = try? HAL.objects(device, kAudioDevicePropertyStreams, scope: direction.scope), !streams.isEmpty else { return nil }
            if let alive = try? HAL.value(device, kAudioDevicePropertyDeviceIsAlive, initial: UInt32(1)), alive == 0 { return nil }
            if let allowed = try? HAL.value(device, kAudioDevicePropertyDeviceCanBeDefaultDevice, initial: UInt32(1), scope: direction.scope), allowed == 0 { return nil }
            return AudioDeviceInfo(id: device, uid: uid, name: name)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    static func select(_ id: AudioObjectID, direction: AudioDeviceDirection) throws {
        guard id != 0 else { throw AudioFailure(message: "อุปกรณ์นี้ไม่พร้อมใช้งานแล้ว") }
        guard try available(direction).contains(where: { $0.id == id }) else {
            throw AudioFailure(message: "อุปกรณ์นี้ไม่พร้อมใช้งานแล้ว")
        }
        var address = HAL.address(direction.defaultSelector), settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(HAL.system, &address, &settable) == noErr, settable.boolValue else {
            throw AudioFailure(message: "ไม่สามารถใช้อุปกรณ์นี้เป็นอุปกรณ์หลักได้")
        }
        var device = id
        let status = AudioObjectSetPropertyData(HAL.system, &address, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &device)
        guard status == noErr else { throw AudioFailure(message: "เปลี่ยนอุปกรณ์เสียงไม่ได้", status: status) }
    }
}

struct MasterVolumeState {
    var volume: Double?
    var muted = false
    var canSetVolume = false
    var canMute = false
    var silent: Bool { muted || volume == 0 }
}

enum SystemMaster {
    private static func volumeAddress(_ device: AudioObjectID) -> AudioObjectPropertyAddress? {
        // The virtual main control preserves the device's relative channel balance.
        for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyVolumeScalar] {
            var address = HAL.address(selector, kAudioObjectPropertyScopeOutput)
            if AudioObjectHasProperty(device, &address) { return address }
        }
        return nil
    }
    private static func writable(_ device: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address, settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }
    static func read(_ device: AudioObjectID) throws -> MasterVolumeState {
        var state = MasterVolumeState()
        if var address = volumeAddress(device) {
            var value: Float32 = 0, size = UInt32(MemoryLayout<Float32>.size)
            try check(AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value))
            guard value.isFinite else { throw AudioFailure(message: "อ่านระดับเสียง Master ไม่ได้") }
            state.volume = Double(min(1, max(0, value)))
            state.canSetVolume = writable(device, address)
        }
        var muteAddress = HAL.address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput)
        if AudioObjectHasProperty(device, &muteAddress) {
            var muted: UInt32 = 0, size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &muted) == noErr {
                state.muted = muted != 0
                state.canMute = writable(device, muteAddress)
            }
        }
        return state
    }
    static func setVolume(_ device: AudioObjectID, _ volume: Double) throws {
        guard var address = volumeAddress(device), writable(device, address) else {
            throw AudioFailure(message: "อุปกรณ์นี้ไม่รองรับการปรับเสียงรวมผ่าน macOS")
        }
        var value = Float32(min(1, max(0, volume)))
        try check(AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value))
    }
    static func setMute(_ device: AudioObjectID, _ muted: Bool) throws {
        var address = HAL.address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput)
        guard writable(device, address) else {
            throw AudioFailure(message: "อุปกรณ์นี้ไม่รองรับปุ่มปิดเสียงของระบบ")
        }
        var value: UInt32 = muted ? 1 : 0
        try check(AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value))
    }
    private static func check(_ status: OSStatus) throws {
        guard status == noErr else {
            throw AudioFailure(message: "อ่านหรือปรับเสียง Master ไม่สำเร็จ กรุณาลองอีกครั้ง", status: status)
        }
    }
}

struct AudioApplication {
    let key: String
    let name: String
    let icon: NSImage?
    var processes: [AudioObjectID]
    var active: Bool
}

enum ApplicationIdentity {
    struct Identity {
        let key: String
        let name: String
        let icon: NSImage
    }
    private static var cache: [URL: Identity] = [:]

    static func outerApplicationURL(_ url: URL?) -> URL? {
        guard let url else { return nil }
        let parts = url.standardizedFileURL.pathComponents
        guard let index = parts.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return URL(fileURLWithPath: NSString.path(withComponents: Array(parts[...index])))
    }
    static func owningBundleID(_ bundleID: String, candidates: [String]) -> String? {
        guard !bundleID.isEmpty else { return nil }
        return candidates.filter { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
            .max { $0.count < $1.count }
    }
    static func identity(at url: URL) -> Identity? {
        if let cached = cache[url] { return cached }
        guard let bundle = Bundle(url: url), let key = bundle.bundleIdentifier else { return nil }
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let fileName = FileManager.default.displayName(atPath: url.path)
        let name = displayName.flatMap { $0.isEmpty ? nil : $0 }
            ?? (fileName as NSString).deletingPathExtension
        var icon: NSImage?
        if let file = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            let iconURL = bundle.url(forResource: file, withExtension: nil)
                ?? bundle.url(forResource: file, withExtension: "icns")
            icon = iconURL.flatMap(NSImage.init(contentsOf:))
        }
        let result = Identity(key: key, name: name, icon: icon ?? NSWorkspace.shared.icon(forFile: url.path))
        cache[url] = result
        return result
    }
    static func executableURL(pid: pid_t) -> URL? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let count = buffer.withUnsafeMutableBufferPointer {
            MixerProcessPath(pid, $0.baseAddress!, UInt32($0.count))
        }
        guard count > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: buffer))
    }
    static func resolve(pid: pid_t, bundleID: String, runningApps: [NSRunningApplication]) -> Identity? {
        let running = NSRunningApplication(processIdentifier: pid)
        if let root = outerApplicationURL(running?.bundleURL), let identity = identity(at: root) { return identity }
        // XPC/audio helpers may not have an NSRunningApplication. Resolve their executable instead.
        if let root = outerApplicationURL(executableURL(pid: pid)), let identity = identity(at: root) { return identity }
        if let owner = owningBundleID(bundleID, candidates: runningApps.compactMap(\.bundleIdentifier)),
           let app = runningApps.first(where: { $0.bundleIdentifier == owner }),
           let root = outerApplicationURL(app.bundleURL), let identity = identity(at: root) { return identity }
        if !bundleID.isEmpty,
           let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let root = outerApplicationURL(installed), let identity = identity(at: root) { return identity }
        return nil
    }
}

enum ProcessDiscovery {
    static func isSystemThumbnailHelper(bundleID: String, name: String, executableURL: URL?) -> Bool {
        if bundleID.hasPrefix("com.apple.quicklook.thumbnail.") || bundleID == "com.apple.quicklook.ThumbnailsAgent" {
            return true
        }
        // WebKit's process name identifies which service owns it. Do not hide all WebKit audio.
        if (bundleID.isEmpty || bundleID.hasPrefix("com.apple.WebKit.")),
           name == "WebThumbnailExtension" || name.hasPrefix("WebThumbnailExtension ") {
            return true
        }
        if let path = executableURL?.standardizedFileURL.path,
           path.hasPrefix("/System/Library/ExtensionKit/Extensions/"),
           executableURL?.pathComponents.contains(where: { $0.hasSuffix("ThumbnailExtension.appex") }) == true {
            return true
        }
        return false
    }
    static func applications() throws -> [AudioApplication] {
        let objects = try HAL.objects(HAL.system, kAudioHardwarePropertyProcessObjectList)
        let runningApps = NSWorkspace.shared.runningApplications
        var grouped: [String: AudioApplication] = [:]
        for object in objects {
            guard let pid = try? HAL.value(object, kAudioProcessPropertyPID, initial: pid_t(0)), pid != getpid(), pid > 0 else { continue }
            let rawID = (try? HAL.string(object, kAudioProcessPropertyBundleID)) ?? ""
            let identity = ApplicationIdentity.resolve(pid: pid, bundleID: rawID, runningApps: runningApps)
            let key = identity?.key ?? (rawID.isEmpty ? "process.\(pid)" : rawID)
            if key == Bundle.main.bundleIdentifier { continue }
            let active = ((try? HAL.value(object, kAudioProcessPropertyIsRunningOutput, initial: UInt32(0))) ?? 0) != 0
            let running = NSRunningApplication(processIdentifier: pid)
            let executableURL = ApplicationIdentity.executableURL(pid: pid)
            let name = identity?.name ?? running?.localizedName ?? executableURL?.lastPathComponent ?? "Process \(pid)"
            guard !isSystemThumbnailHelper(bundleID: rawID, name: name, executableURL: executableURL) else { continue }
            if var app = grouped[key] {
                app.processes.append(object)
                app.active = app.active || active
                grouped[key] = app
            } else {
                grouped[key] = AudioApplication(key: key, name: name,
                    icon: identity?.icon ?? running?.icon, processes: [object], active: active)
            }
        }
        return grouped.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

final class AppAudioRoute {
    let processes: [AudioObjectID]
    let output: AudioObjectID
    private var tap: AudioObjectID = 0
    private var aggregate: AudioObjectID = 0
    private var proc: AudioDeviceIOProcID?
    private var kernel: OpaquePointer?
    var peak: Float { kernel.map(MixerKernelPeak) ?? 0 }
    var cycles: UInt64 { kernel.map(MixerKernelCycles) ?? 0 }

    init(app: AudioApplication, output: AudioObjectID, gain: Float) throws {
        self.processes = app.processes.sorted()
        self.output = output
        do {
            let uid = try HAL.string(output, kAudioDevicePropertyDeviceUID)
            let description = CATapDescription(processes: self.processes, deviceUID: uid, stream: 0)
            description.name = "AppMixer · \(app.name)"
            description.isPrivate = true
            // If this client stops reading or exits, the original audio resumes automatically.
            description.muteBehavior = .mutedWhenTapped
            try HAL.check(AudioHardwareCreateProcessTap(description, &tap), "เริ่มรับเสียงแอปไม่ได้", detail: app.name)
            let format = try HAL.value(tap, kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())
            guard format.mFormatID == kAudioFormatLinearPCM,
                  format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                  format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0,
                  format.mBitsPerChannel == 32,
                  (1...2).contains(format.mChannelsPerFrame), format.mSampleRate > 0 else {
                throw AudioFailure(message: "ต้นแบบรองรับอุปกรณ์ mono/stereo แบบ Float32 เท่านั้น")
            }
            let config: [String: Any] = [
                kAudioAggregateDeviceNameKey: "AppMixer · \(app.name)",
                kAudioAggregateDeviceUIDKey: "appmixer.\(UUID().uuidString)",
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceMainSubDeviceKey: uid,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: uid, kAudioSubDeviceInputChannelsKey: 0]],
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString, kAudioSubTapDriftCompensationKey: true]]
            ]
            try HAL.check(AudioHardwareCreateAggregateDevice(config as CFDictionary, &aggregate), "สร้างช่องส่งเสียงไม่ได้")
            // Verify the IO format before interpreting any audio bytes as Float32.
            for scope in [kAudioObjectPropertyScopeInput, kAudioObjectPropertyScopeOutput] {
                let streams = try HAL.objects(aggregate, kAudioDevicePropertyStreams, scope: scope)
                guard !streams.isEmpty else { throw AudioFailure(message: "อุปกรณ์เสียงยังไม่พร้อม กรุณาลองอีกครั้ง") }
                for stream in streams {
                    let f = try HAL.value(stream, kAudioStreamPropertyVirtualFormat, initial: AudioStreamBasicDescription())
                    guard f.mFormatID == kAudioFormatLinearPCM, f.mBitsPerChannel == 32,
                          f.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                          f.mFormatFlags & kAudioFormatFlagIsBigEndian == 0,
                          abs(f.mSampleRate - format.mSampleRate) < 1 else {
                        throw AudioFailure(message: "รูปแบบเสียงของอุปกรณ์นี้ยังไม่รองรับ ลองใช้อุปกรณ์ stereo อื่น")
                    }
                }
            }
            guard let state = MixerKernelCreate(gain, format.mSampleRate, format.mChannelsPerFrame) else {
                throw AudioFailure(message: "หน่วยความจำไม่พอสำหรับระบบเสียง")
            }
            kernel = state
            try HAL.check(AudioDeviceCreateIOProcID(aggregate, MixerIOProc, UnsafeMutableRawPointer(state), &proc), "สร้างตัวประมวลผลเสียงไม่ได้")
            try HAL.check(AudioDeviceStart(aggregate, proc), "เริ่มเล่นเสียงไม่ได้")
        } catch {
            stop()
            throw error
        }
    }
    func setGain(_ gain: Float) { if let kernel { MixerKernelSetGain(kernel, gain) } }
    func stop() {
        if let proc, aggregate != 0 {
            AudioDeviceStop(aggregate, proc)
            AudioDeviceDestroyIOProcID(aggregate, proc)
        }
        proc = nil
        if aggregate != 0 { AudioHardwareDestroyAggregateDevice(aggregate); aggregate = 0 }
        if tap != 0 { AudioHardwareDestroyProcessTap(tap); tap = 0 }
        if let kernel { MixerKernelDestroy(kernel); self.kernel = nil }
    }
    deinit { stop() }
}
