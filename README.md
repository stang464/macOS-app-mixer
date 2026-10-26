# AppMixer

A native macOS menu bar app for master and per-app volume control, built with SwiftUI, AppKit, and Core Audio Process Taps. No additional audio driver is required.

**Current version: 0.4.2.** This version hides WebThumbnailExtension and Quick Look thumbnail services from the app list while keeping unrelated WebKit audio available.

## Download

Download **AppMixer-v0.4.2-macOS-universal.zip** from [GitHub Releases](https://github.com/stang464/macOS-app-mixer/releases/latest), extract it, and move `AppMixer.app` to Applications. Choose the application ZIP attached to the release, rather than GitHub's automatically generated source archives.

- Requires macOS 14.2 or later.
- The universal app contains Apple Silicon (`arm64`) and Intel (`x86_64`) binaries.
- Xcode is not required to use the app.

If no release has been published yet, see [Automated builds and releases](#automated-builds-and-releases).

The app is ad-hoc signed and **not notarized by Apple**. macOS may block the first launch. If you trust the download, follow [Apple's instructions for opening apps](https://support.apple.com/en-us/102445), using **System Settings > Privacy & Security > Open Anyway** when available. Do not disable Gatekeeper.

This is a prototype. The Intel binary has been built and verified, but has not been tested on Intel hardware.

## Getting started

1. Open AppMixer and click the sliders icon in the menu bar.
2. Enable **Per-app** to expand the controls.
3. Play music or a video in an app. Apps connected to the audio system appear automatically when active or when they have saved settings.
4. Adjust an app's slider or click its speaker button to mute it.
5. Grant system audio access when macOS requests it. If capture fails, check **System Settings > Privacy & Security > Screen & System Audio Recording**, then restart AppMixer.

App volume and mute settings are saved by bundle identifier. AppMixer starts with per-app processing paused each time it launches; enable **Per-app** to apply your saved settings. At 100% with mute off, an app uses its original audio output directly.

Disabling **Per-app** stops its audio routes and collapses the panel to the header, switch, and settings menu. Re-enabling it restores the controls and saved levels. The settings menu remains available while collapsed, including language selection, reset, reconnect, and **Quit AppMixer**.

## Output and microphone selection

With the panel expanded, use **Output** and **Microphone** to select a connected device, such as built-in speakers, Bluetooth headphones, a USB audio device, or an HDMI output. The current device has a checkmark.

These menus change the **default macOS devices**. Apps that follow the system default will use your selection. Meeting apps and other programs with their own device settings may need to be changed separately.

Choosing a microphone only changes the system's default input device. AppMixer does not capture or record microphone audio.

Device lists and selections refresh every second, including changes made in System Settings and devices being connected or disconnected. A device that disappears before selection produces an error. Changing the output recreates per-app routes and reads the new device's master volume while preserving per-app levels. Selecting a Bluetooth microphone can also change output quality or format, depending on the device.

Device selections remain in effect after AppMixer quits because they are macOS settings. On launch, AppMixer reads the current system selection rather than forcing a previously selected device.

## Master volume

**Master** adjusts the current output device's overall volume from 0–100% and provides a mute button without changing individual app settings. It does not require system audio capture permission. Its controls are hidden with the rest of the panel when **Per-app** is disabled; the system volume remains unchanged.

The displayed level is read from macOS and refreshed every second, so it follows changes made with the keyboard or Control Center. Switching outputs loads the new device's volume. Quitting AppMixer or resetting per-app levels leaves system volume unchanged.

When supported, the mute button uses the device's native mute control. Otherwise, it sets the volume to zero and remembers the last audible level for the current session. If the device starts at zero and no previous level is available, unmute restores it to 25%.

Some HDMI, DisplayPort, and DAC outputs do not support volume adjustment through macOS. For those devices, the master slider is unavailable and the app directs you to the device's own controls.

## Languages

Open the settings menu and choose **Language > Thai** or **English**. The interface updates immediately and remembers your choice for the next launch. The initial language is Thai.

Labels, menus, status messages, errors, and accessibility labels support both languages. App and device names retain their original names.

## App names and icons

AppMixer reads names and icons from installed apps rather than using a fixed app list or sample images. Helpers nested inside the same app bundle are grouped under their parent app. When process metadata is unavailable, AppMixer attempts to resolve the executable path or bundle identifier.

Display names come from app metadata or Finder, while saved levels remain associated with the app's bundle identifier. Unresolved processes use a process name and fallback icon. WebKit processes are not automatically assigned to Safari because other apps also use WebKit.

Quick Look thumbnail helpers are excluded using their bundle identifiers, process names, or system extension paths. This also hides previously configured thumbnail-service entries without hiding all WebKit audio.

## Build from source

Open `AppMixer.xcodeproj`, select the **AppMixer** scheme and **My Mac**, then run it. No additional packages are required. The project uses ad-hoc signing for local builds.

To build from Terminal:

```sh
./build.command
```

The app is created at `.build/Build/Products/Release/AppMixer.app`.

To run the tests and create a universal release ZIP:

```sh
./scripts/test.sh
./scripts/build-release.sh
```

The ZIP and `SHA256SUMS.txt` are written to `dist/`, which is excluded from Git. The universal app is located at `.build/Release/Build/Products/Release/AppMixer.app`.

## Verification and limitations

- Release builds and universal packaging have passed locally with Xcode 27.1 on macOS 27.0.1, and the GitHub Actions build has passed.
- Universal builds are checked for both architectures, code signature integrity, and ZIP integrity. These checks do not provide Apple notarization or establish runtime compatibility with every device.
- Audio processing tests cover attenuation, mute ramps, planar and interleaved stereo, hardware-input exclusion, mono output, and missing data, using AddressSanitizer and UndefinedBehaviorSanitizer.
- Identity tests cover nested helpers, similarly named bundle IDs, thumbnail filtering, and names and icons from an installed Google Chrome app when available.
- Language and device tests cover Thai/English translations, app counts, error details, and rejection of invalid device IDs before any system change. The tests do not change the real device selection or volume.
- End-to-end audio behavior and actual device switching still require testing, including Bluetooth, conferencing apps, and sleep/wake. The automated tests do not verify the live interface or physical audio output.
- Audio processing supports Float32 mono/stereo on the first stream of the output device. Surround sound, per-app output routing, and levels above 100% are not supported.
- Device and process polling runs every second. Switching devices may briefly restore original app audio while routes are recreated.
- Helpers outside their parent app bundle may appear separately. App identification and DRM-protected audio are not guaranteed to work in every case.
- Routes use Core Audio's `mutedWhenTapped` behavior and destroy their taps and aggregate devices when stopped. Recovery behavior after interruptions still requires real-world testing.
- Audio is processed locally in memory and is not saved or uploaded.

API reference: [Apple — Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps).

## Automated builds and releases

The **Build macOS app** workflow runs on pushes to `main`. It runs the tests, builds the universal app, checks both architectures and the signature, and uploads a ZIP and checksum as workflow artifacts. Artifacts are retained for 30 days. **A successful `main` build alone does not publish a GitHub Release.**

To publish a release:

1. Open [Actions > Build macOS app](https://github.com/stang464/macOS-app-mixer/actions/workflows/build-release.yml).
2. Choose **Run workflow** and select the commit's branch, or the matching version tag if that tag already exists.
3. Enable **Publish this version to GitHub Releases**, then run the workflow.
4. Once it completes successfully, download the app ZIP from [Releases](https://github.com/stang464/macOS-app-mixer/releases).

Alternatively, push a new version tag matching `CFBundleShortVersionString` in `AppMixer/Info.plist`, such as `v0.4.2`. A tag-triggered run builds and publishes that version automatically.

Before releasing different app code, increment both `CFBundleShortVersionString` and `CFBundleVersion`. Existing release files are never overwritten on reruns. Publishing is rejected if an existing version tag points to a different commit; use that tag as the workflow ref to publish the tagged code, or increment the version for a new release.

GitHub Actions must be enabled, and repository policy must allow the workflow to write releases. The ad-hoc build uses the workflow's GitHub token and requires no personal access token or signing certificate. Developer ID signing and Apple notarization require additional setup.
