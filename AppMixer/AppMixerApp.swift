import SwiftUI
import AppKit
import CoreAudio

@main
struct AppMixerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = MixerModel()
    var body: some Scene {
        MenuBarExtra("AppMixer", systemImage: "slider.horizontal.3") {
            MixerView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

struct MixerView: View {
    @ObservedObject var model: MixerModel
    @AppStorage(L10n.preferenceKey) private var languageCode = AppLanguage.thai.rawValue
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if model.enabled { expandedControls }
        }
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    private var header: some View {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2).foregroundStyle(.tint)
                    .frame(width: 42, height: 42)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("AppMixer").font(.system(size: 18, weight: .semibold))
                    Text(tr("ปรับเสียงแยกแต่ละแอป")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Toggle(tr("แยกแอป"), isOn: Binding(get: { model.enabled }, set: { _ in model.toggleEnabled() }))
                    .font(.caption).foregroundStyle(.secondary).toggleStyle(.switch).controlSize(.small)
                    .accessibilityLabel(tr("เปิดควบคุมแยกแอป"))
                    .fixedSize()
                if !model.enabled { settingsMenu }
            }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, model.enabled ? 16 : 24)
    }
    private var expandedControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                devicePicker(.output, label: tr("เสียงออก"), icon: "speaker.wave.2", devices: model.outputDevices, selected: model.selectedOutput)
                devicePicker(.input, label: tr("ไมโครโฟน"), icon: "mic", devices: model.inputDevices, selected: model.selectedInput)
                Text(tr("อุปกรณ์หลักของ macOS")).font(.caption).foregroundStyle(.secondary)
                if let error = model.deviceError ?? model.deviceReadError { errorView(error) }
            }.padding(.horizontal, 24).padding(.bottom, 16)
            Divider()
            masterControl.padding(.horizontal, 24).padding(.vertical, 20)
            Divider()
            if let error = model.error {
                errorView(error).padding(.horizontal, 24).padding(.top, 14)
            }
            HStack {
                Text(tr("แอปพลิเคชัน"))
                Spacer()
                Text(model.rows.count == 1 ? tr("1 แอป") : String(format: tr("%d แอป"), model.rows.count)).monospacedDigit()
            }.font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 3)
            if model.rows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text(tr("ยังไม่มีแอปที่กำลังเล่นเสียง")).font(.headline)
                    Text(tr("ลองเปิดเพลงหรือวิดีโอ\nแอปจะปรากฏที่นี่โดยอัตโนมัติ"))
                        .multilineTextAlignment(.center).font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 35)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.rows) { row in
                            applicationRow(row).padding(.vertical, 18)
                            if row.id != model.rows.last?.id { Divider() }
                        }
                    }.padding(.horizontal, 24)
                }.frame(height: applicationListHeight)
            }
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                Text(tr("เสียงรวมและระดับเสียงแยกแอป"))
                Spacer(minLength: 8)
                settingsMenu
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 15)
        }
    }
    private var settingsMenu: some View {
                Menu {
                    Picker(tr("ภาษา"), selection: $languageCode) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.name).tag(language.rawValue)
                        }
                    }
                    Divider()
                    Button(tr("ลองเชื่อมต่อเสียงใหม่")) { model.retry() }
                    Button(tr("คืนค่าทุกแอปเป็น 100%")) { model.reset() }
                    Button(tr("เปิดการตั้งค่าสิทธิ์เสียง")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Divider()
                    Button(tr("ออกจาก AppMixer")) {
                        model.stopRoutes()
                        NSApplication.shared.terminate(nil)
                    }
                } label: { Image(systemName: "gearshape") }
                    .menuStyle(.borderlessButton).fixedSize().accessibilityLabel(tr("ตั้งค่า AppMixer"))
                    .font(.caption)
    }
    private func tr(_ key: String) -> String {
        L10n.text(key, language: AppLanguage(rawValue: languageCode) ?? .thai)
    }
    private func devicePicker(_ direction: AudioDeviceDirection, label: String, icon: String,
                              devices: [AudioDeviceInfo], selected: AudioObjectID) -> some View {
        let selectedName = devices.first(where: { $0.id == selected })?.name
            ?? tr(direction == .output ? "ไม่พบอุปกรณ์เสียงออก" : "ไม่พบไมโครโฟน")
        return HStack(spacing: 10) {
            Label(label, systemImage: icon).frame(width: 100, alignment: .leading)
            Menu {
                ForEach(devices) { device in
                    Button { model.selectDevice(device.id, direction: direction) } label: {
                        if device.id == selected { Label(device.name, systemImage: "checkmark") }
                        else { Text(device.name) }
                    }
                }
            } label: {
                HStack {
                    Text(selectedName).lineLimit(1)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }.padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .disabled(devices.isEmpty).accessibilityLabel(label).help(selectedName)
        }.font(.caption).foregroundStyle(.secondary)
    }
    private var applicationListHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        let availableHeight = max(120, min(560, screenHeight - 430))
        return min(CGFloat(model.rows.count) * 120, availableHeight)
    }
    private var masterControl: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Master").font(.system(size: 14, weight: .medium))
                    Text(tr("เสียงรวมของระบบ")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.master.muted { Text(tr("ปิดเสียง")).font(.caption).foregroundStyle(.secondary) }
                Text(model.master.volume.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                    .monospacedDigit().font(.system(size: 14, weight: .medium))
            }
            HStack(spacing: 13) {
                Button { model.toggleMasterMute() } label: {
                    Image(systemName: model.master.silent ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(model.master.silent ? .red : .secondary)
                        .frame(width: 30, height: 30)
                        .background(model.master.silent ? Color.red.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(!model.master.canMute && !model.master.canSetVolume)
                .accessibilityLabel(model.master.silent ? tr("เปิดเสียงรวม") : tr("ปิดเสียงรวม"))
                Slider(value: Binding(get: { model.master.volume ?? 0 }, set: { model.setMasterVolume($0) }), in: 0...1)
                    .disabled(!model.master.canSetVolume)
                    .accessibilityLabel(tr("ระดับเสียง Master รวมทุกแอป"))
            }
            if let error = model.masterError {
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            } else if !model.master.canSetVolume {
                Text(tr("อุปกรณ์นี้ไม่รองรับการปรับเสียงรวมผ่าน macOS ให้ปรับที่ตัวอุปกรณ์"))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private func applicationRow(_ row: MixerRow) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Group {
                    if let icon = row.app.icon {
                        Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
                    } else {
                        Image(systemName: "app.fill").resizable().scaledToFit().foregroundStyle(.secondary).padding(4)
                    }
                }.frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.app.name).font(.system(size: 14, weight: .medium)).lineLimit(1).help(row.app.name)
                    Text(status(for: row)).font(.caption).foregroundStyle(row.error != nil ? .orange : .secondary)
                }
                Spacer(minLength: 8)
                Text("\(Int((row.setting.volume * 100).rounded()))%")
                    .monospacedDigit().font(.system(size: 14, weight: .medium))
                    .frame(minWidth: 44, alignment: .trailing)
            }
            HStack(spacing: 13) {
                Button { model.update(row.id, mute: !row.setting.muted) } label: {
                    Image(systemName: row.setting.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(row.setting.muted ? .red : .secondary)
                        .frame(width: 30, height: 30)
                        .background(row.setting.muted ? Color.red.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain).accessibilityLabel((row.setting.muted ? tr("เปิดเสียง") : tr("ปิดเสียง")) + " " + row.app.name)
                Slider(value: Binding(get: { row.setting.volume }, set: { model.update(row.id, volume: $0) }), in: 0...1)
                    .tint(row.setting.muted ? .gray : .accentColor)
                    .opacity(row.setting.muted ? 0.45 : 1)
                    .accessibilityLabel(tr("ระดับเสียง") + " " + row.app.name)
            }
            if let error = row.error { errorView(error) }
        }
    }
    private func status(for row: MixerRow) -> String {
        if row.error != nil { return tr("เชื่อมต่อไม่สำเร็จ") }
        if !model.enabled { return tr("พักการควบคุม") }
        if row.setting.muted && row.controlling { return tr("ปิดเสียงอยู่") }
        if row.controlling { return tr("กำลังควบคุมเสียง") }
        return row.app.active ? tr("กำลังเล่นเสียง") : tr("รอเล่นเสียง")
    }
    private func errorView(_ error: Error) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(error.localizedDescription).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            Button(tr("ลองอีกครั้ง")) { model.retry() }.font(.caption)
        }
    }
}
