#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/android-startup-evidence
capture() {
  adb logcat -d -v threadtime > build/android-startup-evidence/integration-logcat.txt || true
  adb exec-out screencap -p > build/android-startup-evidence/integration.png || true
}
trap capture EXIT
sha256sum build/startup-apk/app-debug.apk > build/android-startup-evidence/apk-sha256.txt
adb shell getprop ro.build.version.release
adb shell getprop ro.product.cpu.abi
bash tool/android_startup_probe.sh build/startup-apk/app-debug.apk
# Keep the shipped APK separate: flutter drive builds a test-entry APK.
timeout 12m flutter drive -d emulator-5554 --driver=test_driver/integration_test.dart --target=integration_test/app_startup_test.dart 2>&1 | tee build/android-startup-evidence/integration-test.txt
# Restore the original production APK without clearing the smoke-test data.
# This verifies an APK update and cold process start retain the same database.
adb shell am force-stop com.timesand.timesand
export TIMESAND_EXPECT_BOTTLE=__timesand_android_startup_smoke__
bash tool/android_startup_probe.sh build/startup-apk/app-debug.apk
adb shell run-as com.timesand.timesand test -s files/timesand.db
