#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Physically isolate the Store before compiling or running any fixture.
PREVIEW_ROOT=$(mktemp -d /private/tmp/drakebound-quick-note-check.XXXXXX)
python3 - "$PREVIEW_ROOT" <<'PYTHON'
from pathlib import Path
import sys,plistlib,json,hashlib,shutil
root=Path(sys.argv[1]);(root/'data').mkdir()
live=Path.home()/'Library/Application Support/Fellowship5e'
names=['characters.json','compendium.json','activity.json']
(root/'live-hashes.json').write_text(json.dumps({name:hashlib.sha256((live/name).read_bytes()).hexdigest() if (live/name).exists() else None for name in names}))
s=Path('Sources/App.swift').read_text()
s=s.replace('@main struct DrakeboundApp','struct DrakeboundApp')
(root/'IsolatedApp.swift').write_text(s)
app=root/'QuickNoteCheck.app/Contents';(app/'MacOS').mkdir(parents=True)
shutil.copytree('Resources/SRD',app/'Resources/SRD')
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.drakebound.quick-note-check','CFBundleName':'QuickNoteCheck','CFBundleExecutable':'check','CFBundlePackageType':'APPL','NSHighResolutionCapable':True}))
PYTHON
SOURCES=()
for FILE in Sources/*.swift; do
    if [ "$FILE" != "Sources/App.swift" ]; then SOURCES+=("$FILE"); fi
done
xcrun swiftc -swift-version 5 -module-cache-path "$PREVIEW_ROOT/cache" -target arm64-apple-macosx14.0 "${SOURCES[@]}" "$PREVIEW_ROOT/IsolatedApp.swift" Tests/QuickNoteInteractionTests.swift -o "$PREVIEW_ROOT/QuickNoteCheck.app/Contents/MacOS/check" -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers
codesign --force --deep --sign - "$PREVIEW_ROOT/QuickNoteCheck.app"
"$PREVIEW_ROOT/QuickNoteCheck.app/Contents/MacOS/check" "$PREVIEW_ROOT/data/characters.json"
python3 - "$PREVIEW_ROOT" <<'PYTHON'
from pathlib import Path
import sys,json,hashlib
root=Path(sys.argv[1]);live=Path.home()/'Library/Application Support/Fellowship5e'
for name,expected in json.loads((root/'live-hashes.json').read_text()).items():
    actual=hashlib.sha256((live/name).read_bytes()).hexdigest() if (live/name).exists() else None
    assert actual == expected, 'Live save changed during quick-note check: '+name
print('Verified live saves unchanged.')
PYTHON
echo "Isolated fixtures and visual checks: $PREVIEW_ROOT/data"
