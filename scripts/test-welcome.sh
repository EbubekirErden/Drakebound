#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Physically isolate the Store before compiling or running any fixture.
PREVIEW_ROOT=$(mktemp -d /private/tmp/drakebound-welcome-check.XXXXXX)
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
w=Path('Sources/WelcomeView.swift').read_text()
needle='.buttonStyle(.plain).accessibilityLabel(title)'
assert w.count(needle)==1
w=w.replace(needle,needle+'.background(WelcomeProbe(name:title))')
needle='Button { path = .start } label: { Label("Back",systemImage:"chevron.left") }.buttonStyle(PageButtonStyle())'
assert needle in w
w=w.replace(needle,needle+'.background(WelcomeProbe(name:"welcome-back"))')
(root/'ProbedWelcomeView.swift').write_text(w)
app=root/'WelcomeCheck.app/Contents';(app/'MacOS').mkdir(parents=True)
shutil.copytree('Resources/SRD',app/'Resources/SRD')
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.drakebound.welcome-check','CFBundleName':'WelcomeCheck','CFBundleExecutable':'check','CFBundlePackageType':'APPL','NSHighResolutionCapable':True}))
PYTHON
SOURCES=()
for FILE in Sources/*.swift; do
    if [ "$FILE" != "Sources/App.swift" ] && [ "$FILE" != "Sources/WelcomeView.swift" ]; then SOURCES+=("$FILE"); fi
done
xcrun swiftc -swift-version 5 -module-cache-path "$PREVIEW_ROOT/cache" -target arm64-apple-macosx14.0 "${SOURCES[@]}" "$PREVIEW_ROOT/IsolatedApp.swift" "$PREVIEW_ROOT/ProbedWelcomeView.swift" Tests/WelcomeInteractionTests.swift -o "$PREVIEW_ROOT/WelcomeCheck.app/Contents/MacOS/check" -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers
codesign --force --deep --sign - "$PREVIEW_ROOT/WelcomeCheck.app"
"$PREVIEW_ROOT/WelcomeCheck.app/Contents/MacOS/check" "$PREVIEW_ROOT/data/characters.json"
python3 - "$PREVIEW_ROOT" <<'PYTHON'
from pathlib import Path
import sys,json,hashlib
root=Path(sys.argv[1]);live=Path.home()/'Library/Application Support/Fellowship5e'
for name,expected in json.loads((root/'live-hashes.json').read_text()).items():
    actual=hashlib.sha256((live/name).read_bytes()).hexdigest() if (live/name).exists() else None
    assert actual == expected, 'Live save changed during welcome check: '+name
print('Verified live saves unchanged.')
PYTHON
echo "Isolated fixtures and visual checks: $PREVIEW_ROOT/data"
