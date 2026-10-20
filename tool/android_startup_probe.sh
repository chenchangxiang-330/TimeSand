#!/usr/bin/env bash
set -euo pipefail
evidence=build/android-startup-evidence
mkdir -p "$evidence"
capture() {
  adb logcat -d -v threadtime > "$evidence/logcat.txt" || true
  adb exec-out screencap -p > "$evidence/startup.png" || true
  adb shell uiautomator dump /sdcard/timesand-window.xml || true
  adb pull /sdcard/timesand-window.xml "$evidence/window.xml" || true
  python3 - <<'PY'
from pathlib import Path
log = Path('build/android-startup-evidence/logcat.txt')
if log.exists():
    for line in log.read_text(errors='replace').splitlines():
        if any(word in line for word in ('E/flutter', 'Unhandled Exception', 'FATAL EXCEPTION', 'DatabaseException', 'FileSystemException', 'TimeSand local data initialization failed')):
            print(line)
PY
}
trap capture EXIT
adb install -r "$1"
adb logcat -c
adb shell am start -W -n com.timesand.timesand/.MainActivity
launcher_dismissed=false
for attempt in $(seq 1 24); do
  sleep 5
  if ! adb shell uiautomator dump /sdcard/timesand-window.xml; then
    continue
  fi
  adb pull /sdcard/timesand-window.xml "$evidence/window.xml"
  state=$(python3 - <<'PY'
import xml.etree.ElementTree as ET
nodes = list(ET.parse('build/android-startup-evidence/window.xml').iter('node'))
texts = [n.get('text', '') for n in nodes]
if "Pixel Launcher isn't responding" in texts:
    print('launcher_anr')
else:
    labels = ' '.join(n.get('text', '') + ' ' + n.get('content-desc', '')
                      for n in nodes if n.get('package') == 'com.timesand.timesand')
    print('home' if '今日 · 时间之瓶' in labels and '新建' in labels else 'waiting')
PY
)
  if [ "$state" = home ]; then
    echo "Verified a visible TimeSand homepage from the shipped APK."
    exit 0
  fi
  if [ "$state" = launcher_anr ] && [ "$launcher_dismissed" = false ]; then
    # Android 35 Google APIs may show a launcher ANR during cold boot.
    # Only dismiss this observed system-launcher failure; never hide a
    # TimeSand error/ANR or disable Android's error reporting.
    cp "$evidence/window.xml" "$evidence/launcher-anr.xml"
    adb exec-out screencap -p > "$evidence/launcher-anr.png"
    echo "Dismissing the unrelated Pixel Launcher ANR; TimeSand remains under test."
    adb shell am force-stop com.google.android.apps.nexuslauncher
    adb shell am start -W -n com.timesand.timesand/.MainActivity
    launcher_dismissed=true
  fi
done
echo "::error::TimeSand homepage did not become visible within the bounded startup probe; see logs, UI hierarchy, and screenshot."
exit 1
