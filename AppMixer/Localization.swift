import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case thai = "th"
    case english = "en"
    var id: String { rawValue }
    var name: String { self == .thai ? "ไทย" : "English" }
}

enum L10n {
    static let preferenceKey = "AppMixer.language"
    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "th") ?? .thai
    }
    static func text(_ key: String, language: AppLanguage? = nil) -> String {
        (language ?? self.language) == .english ? (english[key] ?? key) : key
    }
    static let english: [String: String] = [
        "ปรับเสียงแยกแต่ละแอป": "Per-app volume control",
        "แยกแอป": "Per-app",
        "เปิดควบคุมแยกแอป": "Enable per-app volume control",
        "เสียงออก": "Output",
        "ไมโครโฟน": "Microphone",
        "อุปกรณ์หลักของ macOS": "Default macOS devices",
        "ไม่พบอุปกรณ์เสียงออก": "No output device found",
        "ไม่พบไมโครโฟน": "No microphone found",
        "อุปกรณ์นี้ไม่พร้อมใช้งานแล้ว": "This device is no longer available",
        "เปลี่ยนอุปกรณ์เสียงไม่ได้": "Could not change the audio device",
        "เปลี่ยนอุปกรณ์เสียงไม่สำเร็จ กรุณาลองอีกครั้ง": "The audio device did not switch. Please try again",
        "ไม่สามารถใช้อุปกรณ์นี้เป็นอุปกรณ์หลักได้": "This device cannot be used as the default device",
        "พักการควบคุมแยกแอป": "Per-app control is paused",
        "แอปพลิเคชัน": "Applications",
        "%d แอป": "%d apps",
        "1 แอป": "1 app",
        "ยังไม่มีแอปที่กำลังเล่นเสียง": "No apps are playing audio",
        "ลองเปิดเพลงหรือวิดีโอ\nแอปจะปรากฏที่นี่โดยอัตโนมัติ": "Play some music or a video.\nThe app will appear here automatically",
        "เสียงรวมและระดับเสียงแยกแอป": "Master and per-app volume",
        "ลองเชื่อมต่อเสียงใหม่": "Reconnect audio",
        "คืนค่าทุกแอปเป็น 100%": "Reset all apps to 100%",
        "เปิดการตั้งค่าสิทธิ์เสียง": "Open audio privacy settings",
        "ออกจาก AppMixer": "Quit AppMixer",
        "ตั้งค่า AppMixer": "AppMixer settings",
        "ภาษา": "Language",
        "เสียงรวมของระบบ": "System output volume",
        "ปิดเสียง": "Mute",
        "เปิดเสียง": "Unmute",
        "เปิดเสียงรวม": "Unmute master",
        "ปิดเสียงรวม": "Mute master",
        "ระดับเสียง Master รวมทุกแอป": "Master volume for all apps",
        "ระดับเสียง": "Volume",
        "อุปกรณ์นี้ไม่รองรับการปรับเสียงรวมผ่าน macOS ให้ปรับที่ตัวอุปกรณ์": "This device does not support macOS volume control. Adjust the volume on the device",
        "เชื่อมต่อไม่สำเร็จ": "Connection failed",
        "พักการควบคุม": "Control paused",
        "ปิดเสียงอยู่": "Muted",
        "กำลังควบคุมเสียง": "Volume control active",
        "กำลังเล่นเสียง": "Playing audio",
        "รอเล่นเสียง": "Waiting for audio",
        "ลองอีกครั้ง": "Try again",
        "กำลังค้นหาอุปกรณ์เสียง…": "Finding audio devices…",
        "อ่านข้อมูลเสียงไม่ได้": "Could not read audio properties",
        "อ่านชื่ออุปกรณ์ไม่ได้": "Could not read the device name",
        "อ่านรายการเสียงไม่ได้": "Could not read audio devices or processes",
        "อ่านระดับเสียง Master ไม่ได้": "Could not read master volume",
        "อุปกรณ์นี้ไม่รองรับการปรับเสียงรวมผ่าน macOS": "This device does not support macOS master volume control",
        "อุปกรณ์นี้ไม่รองรับปุ่มปิดเสียงของระบบ": "This device does not support system mute",
        "อ่านหรือปรับเสียง Master ไม่สำเร็จ กรุณาลองอีกครั้ง": "Could not read or change master volume. Please try again",
        "เริ่มรับเสียงแอปไม่ได้": "Could not capture app audio",
        "ต้นแบบรองรับอุปกรณ์ mono/stereo แบบ Float32 เท่านั้น": "This prototype supports Float32 mono/stereo devices only",
        "สร้างช่องส่งเสียงไม่ได้": "Could not create an audio route",
        "อุปกรณ์เสียงยังไม่พร้อม กรุณาลองอีกครั้ง": "The audio device is not ready. Please try again",
        "รูปแบบเสียงของอุปกรณ์นี้ยังไม่รองรับ ลองใช้อุปกรณ์ stereo อื่น": "This audio format is not supported. Try another stereo device",
        "หน่วยความจำไม่พอสำหรับระบบเสียง": "Not enough memory for audio processing",
        "สร้างตัวประมวลผลเสียงไม่ได้": "Could not create the audio processor",
        "เริ่มเล่นเสียงไม่ได้": "Could not start audio playback",
        "หากเกี่ยวกับสิทธิ์ ให้ตรวจ System Settings → Privacy & Security → Screen & System Audio Recording": "For permission issues, check System Settings → Privacy & Security → Screen & System Audio Recording"
    ]
}
