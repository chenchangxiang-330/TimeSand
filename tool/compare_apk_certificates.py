import os
import re
import subprocess
from pathlib import Path

evidence = Path('build/android-startup-evidence')
evidence.mkdir(parents=True, exist_ok=True)
tools = Path(os.environ['ANDROID_HOME']) / 'build-tools'
signer = sorted(tools.glob('*/apksigner'))[-1]
fingerprints = []
for label, path in [('previous', 'build/previous-apk/app-debug.apk'), ('updated', 'build/app/outputs/flutter-apk/app-debug.apk')]:
    result = subprocess.run([str(signer), 'verify', '--print-certs', path], check=True, capture_output=True, text=True)
    (evidence / f'{label}-certificate.txt').write_text(result.stdout)
    match = re.search(r'Signer #1 certificate SHA-256 digest: (\w+)', result.stdout)
    assert match, 'APK certificate digest is missing'
    fingerprints.append(match.group(1))
    print(f'{label} APK signing certificate SHA-256: {match.group(1)}')
compatible = fingerprints[0] == fingerprints[1]
(evidence / 'update-compatibility.txt').write_text(f'same_signing_certificate={compatible}\n')
print(f'Previous APK supports an in-place signed update: {compatible}')
