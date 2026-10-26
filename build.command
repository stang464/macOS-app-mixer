#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
xcodebuild -project AppMixer.xcodeproj -scheme AppMixer -configuration Release -destination 'platform=macOS' -derivedDataPath .build build CODE_SIGN_IDENTITY=-
print "Built app: ${PWD}/.build/Build/Products/Release/AppMixer.app"
