#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/android-startup-evidence
capture() {
  adb logcat -d -v threadtime > build/android-startup-evidence/last-logcat.txt || true
  adb exec-out screencap -p > build/android-startup-evidence/last-frame.png || true
}
trap capture EXIT
sha256sum build/startup-apk/app-debug.apk > build/android-startup-evidence/apk-sha256.txt
adb shell getprop ro.build.version.release
adb shell getprop ro.product.cpu.abi
bash tool/android_startup_probe.sh build/startup-apk/app-debug.apk
mkdir -p build/android-startup-evidence/production-initial
cp build/android-startup-evidence/{logcat.txt,startup.png,window.xml} build/android-startup-evidence/production-initial/
# Keep the shipped APK separate: flutter drive builds a test-entry APK.
timeout 12m flutter drive -d emulator-5554 --driver=test_driver/integration_test.dart --target=integration_test/app_startup_test.dart 2>&1 | tee build/android-startup-evidence/integration-test.txt
adb logcat -d -v threadtime > build/android-startup-evidence/integration-logcat.txt
# Restore the production APK using the same runner's debug signing key.
adb shell am force-stop com.timesand.timesand
bash tool/android_startup_probe.sh build/startup-apk/app-debug.apk
mkdir -p build/android-startup-evidence/production-restored
cp build/android-startup-evidence/{logcat.txt,startup.png,window.xml} build/android-startup-evidence/production-restored/
# Check the fixture after a real process stop and APK replacement. Copy SQLite
# sidecars together while the process is stopped, then remove these test copies.
adb shell am force-stop com.timesand.timesand
adb exec-out run-as com.timesand.timesand cat files/timesand.db > build/android-startup-evidence/restored.db
for suffix in -wal -shm -journal; do
  if adb shell run-as com.timesand.timesand test -f "files/timesand.db$suffix"; then
    adb exec-out run-as com.timesand.timesand cat "files/timesand.db$suffix" > "build/android-startup-evidence/restored.db$suffix"
  fi
done
python3 - <<'PY'
import sqlite3
from pathlib import Path
path = Path('build/android-startup-evidence/restored.db')
try:
    with sqlite3.connect(path) as db:
        rows = db.execute("SELECT b.id, e.started_at, e.ended_at FROM bottles b JOIN time_entries e ON e.bottle_id = b.id WHERE b.name = ?", ('__timesand_android_startup_smoke__',)).fetchall()
        assert len(rows) == 1, 'Expected the persisted smoke-test record after production APK replacement'
        assert rows[0][1] < rows[0][2], 'The saved interval must remain complete'
        assert db.execute('SELECT count(*) FROM time_entries WHERE ended_at IS NULL').fetchone()[0] == 0
    print('Verified the bottle and completed interval survived production APK replacement and cold startup.')
finally:
    for file in path.parent.glob('restored.db*'):
        file.unlink()
PY
