#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/android-startup-evidence
capture() {
  adb logcat -d -v threadtime > build/android-startup-evidence/logcat.txt || true
  adb exec-out screencap -p > build/android-startup-evidence/startup.png || true
  adb shell uiautomator dump /sdcard/timesand-window.xml || true
  adb pull /sdcard/timesand-window.xml build/android-startup-evidence/window.xml || true
  python3 - <<'PY'
from pathlib import Path
log = Path('build/android-startup-evidence/logcat.txt')
if log.exists():
    for line in log.read_text(errors='replace').splitlines():
        if any(word in line for word in ('E/flutter', 'Unhandled Exception', 'FATAL EXCEPTION', 'DatabaseException', 'FileSystemException')):
            print(line)
PY
}
trap capture EXIT
adb install -r "$1"
adb logcat -c
adb shell am start -W -n com.timesand.timesand/.MainActivity
sleep 30
adb shell uiautomator dump /sdcard/timesand-window.xml
adb pull /sdcard/timesand-window.xml build/android-startup-evidence/window.xml
python3 - <<'PY'
from pathlib import Path
window = Path('build/android-startup-evidence/window.xml').read_text()
assert '今日' in window or '今天' in window or '时间之瓶' in window, 'TimeSand homepage did not become visible after 30 seconds; see startup log and screenshot.'
print('Verified a visible TimeSand homepage from the shipped APK.')
PY
