#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

release_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' AppMixer/Info.plist)
release_build_dir="${APPMIXER_DERIVED_DATA:-$PWD/.build/Release}"
release_output_dir="${APPMIXER_RELEASE_DIR:-$PWD/dist}"
release_archive="AppMixer-v${release_version}-macOS-universal.zip"

xcodebuild \
  -project AppMixer.xcodeproj \
  -scheme AppMixer \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$release_build_dir" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- \
  build

release_app="$release_build_dir/Build/Products/Release/AppMixer.app"
release_architectures=$(lipo -archs "$release_app/Contents/MacOS/AppMixer")
for required_arch in arm64 x86_64; do
  case " $release_architectures " in
    *" $required_arch "*) ;;
    *) printf 'Missing required architecture: %s\n' "$required_arch" >&2; exit 1 ;;
  esac
done
codesign --verify --deep --strict "$release_app"
mkdir -p "$release_output_dir"
ditto -c -k --sequesterRsrc --keepParent "$release_app" "$release_output_dir/$release_archive"
unzip -tq "$release_output_dir/$release_archive"
(
  cd "$release_output_dir"
  shasum -a 256 "$release_archive" > SHA256SUMS.txt
)
printf 'Release package: %s\n' "$release_output_dir/$release_archive"
