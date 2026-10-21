#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PREVIEW_ROOT=$(mktemp -d /private/tmp/drakebound-play-ux-XXXXXX)
python3 - "$PREVIEW_ROOT" <<'PY'
from pathlib import Path
import sys,hashlib,json,shutil,plistlib
root=Path(sys.argv[1]);live=Path.home()/'Library/Application Support/Fellowship5e'
names=['characters.json','compendium.json','activity.json']
(root/'live-hashes.json').write_text(json.dumps({n:hashlib.sha256((live/n).read_bytes()).hexdigest() if (live/n).exists() else None for n in names}))
shutil.copytree('Sources',root/'Sources')
shutil.copy2('Tests/PlayUXTests.swift',root/'PlayUXTests.swift')
app_source=root/'Sources/App.swift'
app_source.write_text(app_source.read_text().replace('@main struct DrakeboundApp','struct DrakeboundApp'))
probes={
    'ConditionViews.swift': [('.toggleStyle(.checkbox).font(.system(size:12)).frame(maxWidth:.infinity,alignment:.leading)','.toggleStyle(.checkbox).font(.system(size:12)).frame(maxWidth:.infinity,alignment:.leading).background(UXProbe(name:"condition-toggle-"+condition.name))')],
    'AttackViews.swift': [('.accessibilityLabel("Adjust resource "+choice.counter.name)','.accessibilityLabel("Adjust resource "+choice.counter.name).background(UXProbe(name:"resource-chip-"+choice.ref.key))'),('.accessibilityLabel("Spend resource "+counter.name)','.accessibilityLabel("Spend resource "+counter.name).background(UXProbe(name:"resource-spend"))'),('Button("Done") { detail=nil }','Button("Done") { detail=nil }.background(UXProbe(name:"resource-done"))')],
    'ActionViews.swift': [('.accessibilityLabel(feature.name+" details")','.accessibilityLabel(feature.name+" details").background(UXProbe(name:"feature-toggle-"+feature.id.uuidString))'),('Text(DescriptionMarkdown.attributed(feature.text)).font(.system(size:12)).textSelection(.enabled)','Text(DescriptionMarkdown.attributed(feature.text)).font(.system(size:12)).textSelection(.enabled).background(UXProbe(name:"feature-description"))'),('.accessibilityLabel("Casting options for "+spell.name)','.accessibilityLabel("Casting options for "+spell.name).background(UXProbe(name:"casting-options-"+spell.name))'),('Text("Casting options").font(.caption).foregroundStyle(.secondary)','Text("Casting options").font(.caption).foregroundStyle(.secondary).background(UXProbe(name:"casting-popover"))')],
    'CombatActionRow.swift': [('Text("Hit "+signed(hero.attackBonus(attack)+hero.testPenalty))','Text("Hit "+signed(hero.attackBonus(attack)+hero.testPenalty)).background(UXProbe(name:"attack-hit"))')],
    'SpellSlotGrid.swift': [(r'.accessibilityLabel("Spend level \(index+1) spell slot")',r'.accessibilityLabel("Spend level \(index+1) spell slot").background(UXProbe(name:"slot-spend-"+String(index+1)))')],
    'GlobalSearchViews.swift': [('.help("Search character and references · ⌘K").accessibilityLabel("Search everything")','.help("Search character and references · ⌘K").accessibilityLabel("Search everything").background(UXProbe(name:"global-search"))'),
        ('.buttonStyle(.plain).accessibilityLabel(result.name+', '.buttonStyle(.plain).background(UXProbe(name:"search-result-"+result.id)).accessibilityLabel(result.name+')]
}
for name,replacements in probes.items():
    path=root/'Sources'/name
    source=path.read_text()
    for needle,replacement in replacements:
        assert source.count(needle)==1,(name,needle)
        source=source.replace(needle,replacement)
    path.write_text(source)
app=root/'PlayUX.app/Contents';(app/'MacOS').mkdir(parents=True)
shutil.copytree('Resources/SRD',app/'Resources/SRD')
for name in ['DrakeboundSidebarMark.png','DrakeboundD20.png']:
    shutil.copy2(Path('build/products.noindex/Drakebound.app/Contents/Resources')/name,app/'Resources'/name)
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.drakebound.play-ux-check','CFBundleName':'PlayUX','CFBundleExecutable':'check','CFBundlePackageType':'APPL','NSHighResolutionCapable':True}))
PY
verify_live() {
python3 - "$PREVIEW_ROOT" <<'PY'
from pathlib import Path
import sys,json,hashlib
root=Path(sys.argv[1]);live=Path.home()/'Library/Application Support/Fellowship5e'
for n,expected in json.loads((root/'live-hashes.json').read_text()).items():
    actual=hashlib.sha256((live/n).read_bytes()).hexdigest() if (live/n).exists() else None
    assert actual==expected,'Live save changed: '+n
print('Verified live character, compendium and activity hashes unchanged.')
PY
}
trap verify_live EXIT
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache -target arm64-apple-macosx14.0 "$PREVIEW_ROOT"/Sources/*.swift "$PREVIEW_ROOT/PlayUXTests.swift" -o "$PREVIEW_ROOT/PlayUX.app/Contents/MacOS/check" -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers
codesign --force --deep --sign - "$PREVIEW_ROOT/PlayUX.app"
"$PREVIEW_ROOT/PlayUX.app/Contents/MacOS/check" "$PREVIEW_ROOT"
echo "Visual checks: $PREVIEW_ROOT"
