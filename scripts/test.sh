#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir="${APPMIXER_TEST_DIR:-$PWD/.build/Tests}"
mkdir -p "$test_output_dir"
xcrun clang -std=c11 -fsanitize=address,undefined -g \
  Tests/AudioKernelTests.c AppMixer/AudioKernel.c -framework CoreAudio \
  -o "$test_output_dir/AudioKernelTests"
"$test_output_dir/AudioKernelTests"
xcrun clang -std=c11 -c AppMixer/AudioKernel.c -o "$test_output_dir/AudioKernel.o"
for test_name in ProcessIdentityTests LanguageAndDeviceTests; do
  xcrun swiftc -module-cache-path "$test_output_dir/ModuleCache" \
    -import-objc-header AppMixer/BridgingHeader.h \
    AppMixer/Localization.swift AppMixer/AudioSystem.swift "Tests/${test_name}.swift" \
    "$test_output_dir/AudioKernel.o" \
    -framework AppKit -framework CoreAudio -framework AudioToolbox \
    -o "$test_output_dir/$test_name"
  "$test_output_dir/$test_name"
done
