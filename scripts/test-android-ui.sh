#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_PATH="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$SDK_PATH/platform-tools/adb"
export ANDROID_SERIAL="${DRAKEBOUND_ANDROID_TEST_SERIAL:-emulator-5554}"
case "$ANDROID_SERIAL" in emulator-*) ;; *) echo "Use a local emulator for disposable UI fixtures"; exit 1;; esac
VERIFICATION_PACKAGE=com.drakebound.android.draft.verification
test "$VERIFICATION_PACKAGE" != com.drakebound.android.draft
mkdir -p "$PROJECT_ROOT/output/android-ui"
python3 - <<'PY'
from pathlib import Path
import hashlib,json
live=Path.home()/'Library/Application Support/Fellowship5e'
for name,digest in json.loads(Path('/tmp/drakebound-ui-live-hashes.json').read_text()).items():
 assert hashlib.sha256((live/name).read_bytes()).hexdigest()==digest,name
print('Live-save baseline verified. UI fixtures require a separate application sandbox.')
PY
test "$("$ADB" -s "$ANDROID_SERIAL" shell getprop sys.boot_completed | tr -d '\r')" = 1
if "$ADB" -s "$ANDROID_SERIAL" shell pm path "$VERIFICATION_PACKAGE" | tr -d '\r' | rg -q '^package:'; then
    echo "A verification install already exists. Refusing to overwrite its data."
    exit 1
fi
cleanup() {
    "$ADB" -s "$ANDROID_SERIAL" uninstall "$VERIFICATION_PACKAGE.test" >/dev/null 2>&1 || true
    "$ADB" -s "$ANDROID_SERIAL" uninstall "$VERIFICATION_PACKAGE" >/dev/null 2>&1 || true
    python3 - <<'PY'
from pathlib import Path
import hashlib,json
live=Path.home()/'Library/Application Support/Fellowship5e'
for name,digest in json.loads(Path('/tmp/drakebound-ui-live-hashes.json').read_text()).items():
 assert hashlib.sha256((live/name).read_bytes()).hexdigest()==digest,name
print('Verification install removed; live characters, compendium and activity unchanged.')
PY
}
trap cleanup EXIT
set +e
bash "$PROJECT_ROOT/scripts/build-android.sh" :app:connectedDebugAndroidTest -PdrakeboundVerification=true -Pandroid.injected.device.serial="$ANDROID_SERIAL" -Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true --offline
TEST_STATUS=$?
set -e
"$ADB" -s "$ANDROID_SERIAL" pull "/sdcard/Android/data/$VERIFICATION_PACKAGE/files/screenshots" "$PROJECT_ROOT/output/android-ui/" || true
"$ADB" -s "$ANDROID_SERIAL" shell am force-stop "$VERIFICATION_PACKAGE"
"$ADB" -s "$ANDROID_SERIAL" shell am start -W -n "$VERIFICATION_PACKAGE/com.drakebound.android.draft.MainActivity"
"$ADB" -s "$ANDROID_SERIAL" shell uiautomator dump /sdcard/drakebound-verification-window.xml >/dev/null 2>&1 || true
"$ADB" -s "$ANDROID_SERIAL" exec-out screencap -p > "$PROJECT_ROOT/output/android-ui/home.png"
# Restore the deliverable's normal app ID after building the disposable test package.
bash "$PROJECT_ROOT/scripts/build-android.sh" :app:assembleDebug --offline
exit "$TEST_STATUS"
