import AppKit

@main
struct ProcessIdentityTests {
    static func main() {
        // Nested Electron helper bundles belong to the visible parent application.
        let chromeHelper = URL(fileURLWithPath: "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper")
        precondition(ApplicationIdentity.outerApplicationURL(chromeHelper)?.path == "/Applications/Google Chrome.app")
        precondition(ApplicationIdentity.outerApplicationURL(URL(fileURLWithPath: "/usr/bin/afplay")) == nil)
        precondition(ApplicationIdentity.outerApplicationURL(nil) == nil)
        // Similar app names must not silently redirect controls to a different app.
        precondition(ApplicationIdentity.owningBundleID("com.example.player.beta.helper", candidates: ["com.example.player", "com.example.player.beta"]) == "com.example.player.beta")
        precondition(ApplicationIdentity.owningBundleID("com.example.player2.helper", candidates: ["com.example.player"]) == nil)
        precondition(ApplicationIdentity.owningBundleID("com.apple.WebKit.WebContent", candidates: ["com.apple.Safari"]) == nil)
        precondition(ApplicationIdentity.owningBundleID("", candidates: ["com.example.player"]) == nil)
        // Hide the observed macOS thumbnail service, while retaining unrelated WebKit and app audio.
        precondition(ProcessDiscovery.isSystemThumbnailHelper(bundleID: "com.apple.WebKit.GPU", name: "WebThumbnailExtension Graphics and Media", executableURL: nil))
        precondition(ProcessDiscovery.isSystemThumbnailHelper(bundleID: "com.apple.quicklook.thumbnail.WebExtension", name: "Web", executableURL: nil))
        precondition(ProcessDiscovery.isSystemThumbnailHelper(bundleID: "", name: "WebThumbnailExtension Web Content", executableURL: nil))
        precondition(ProcessDiscovery.isSystemThumbnailHelper(bundleID: "", name: "Office", executableURL: URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions/OfficeThumbnailExtension.appex/Contents/MacOS/OfficeThumbnailExtension")))
        precondition(!ProcessDiscovery.isSystemThumbnailHelper(bundleID: "com.apple.WebKit.GPU", name: "Safari Graphics and Media", executableURL: nil))
        precondition(!ProcessDiscovery.isSystemThumbnailHelper(bundleID: "com.google.Chrome.helper", name: "Google Chrome", executableURL: chromeHelper))
        precondition(!ProcessDiscovery.isSystemThumbnailHelper(bundleID: "com.hnc.Discord", name: "Discord", executableURL: nil))
        precondition(!ProcessDiscovery.isSystemThumbnailHelper(bundleID: "com.example.WebThumbnailExtension", name: "WebThumbnailExtension", executableURL: nil))
        // Read the installed app's actual name and icon, rather than a mock image asset.
        let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        if FileManager.default.fileExists(atPath: chrome.path) {
            guard let identity = ApplicationIdentity.identity(at: chrome) else { fatalError("Chrome identity missing") }
            precondition(identity.key == "com.google.Chrome")
            precondition(identity.name == "Google Chrome")
            precondition(identity.icon.isValid && identity.icon.size.width > 0)
            print("PASS: installed Google Chrome display name and native app icon")
        }
        print("PASS: nested helper grouping, app isolation, thumbnail filtering, retained Safari/Chrome/Discord audio")
    }
}
