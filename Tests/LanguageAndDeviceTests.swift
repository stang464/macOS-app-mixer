import Foundation
import CoreAudio

@main
struct LanguageAndDeviceTests {
    static func main() {
        for (key, english) in L10n.english {
            precondition(!english.isEmpty && english != key)
            precondition(L10n.text(key, language: .thai) == key)
            precondition(L10n.text(key, language: .english) == english)
            if key.contains("%d") { precondition(english.contains("%d")) }
        }
        precondition(String(format: L10n.text("%d แอป", language: .english), 3) == "3 apps")
        precondition(L10n.text("1 แอป", language: .english) == "1 app")
        // Hardware failures must keep the app name and OSStatus in either language.
        let failure = AudioFailure(message: "เริ่มรับเสียงแอปไม่ได้", detail: "Google Chrome", status: -50, captureHint: true)
        precondition(failure.localizedDescription.contains("Google Chrome"))
        precondition(failure.localizedDescription.contains("-50"))
        // Invalid IDs must be rejected before any attempt to modify system devices.
        for direction in [AudioDeviceDirection.input, .output] {
            do {
                try AudioDevices.select(0, direction: direction)
                fatalError("An invalid device ID was accepted")
            } catch let error as AudioFailure {
                precondition(error.message == "อุปกรณ์นี้ไม่พร้อมใช้งานแล้ว")
            } catch { fatalError("Unexpected error: \(error)") }
        }
        print("PASS: \(L10n.english.count) Thai/English translations, app counts, error details, invalid input/output rejection")
    }
}
