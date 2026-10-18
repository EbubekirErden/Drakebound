import SwiftUI

struct CasterTableView:View {
    var draft:CharacterBuildDraft
    var catalog:GuideCatalog
    @Binding var level:Int
    var apply:([Int])->Void
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Spellcasting progression").font(.headline)
            ScrollView { VStack(alignment:.leading,spacing:12) {
                EditorGroup(title:"Cantrips · by class") {
                    ForEach(draft.resultingClasses) { record in
                        HStack(alignment:.top) {
                            Text("\(record.name) \(record.level)").font(.caption)
                            Spacer()
                            if let entry = reference(record),let count = GuideRules.importedCantrips(entry,at:record.level) { Text("\(count) cantrips").font(.caption).foregroundStyle(sky) }
                            else { Text("Check class rules").font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                    Text("Counts come from each class’s own table, not combined caster level. Ancestry, feats, and other extra cantrips are separate. Cantrips never use spell slots.").font(.caption2).foregroundStyle(.secondary)
                }
                EditorGroup(title:"Spell slots · combined caster level") {
                    Stepper("Caster level: \(level)",value:$level,in:0...20)
                    let slots = GuideRules.slots(at:level)
                    ForEach(0..<9,id:\.self) { i in if slots[i] > 0 { HStack { Text("Level \(i+1)"); Spacer(); Text("\(slots[i]) slots").foregroundStyle(sky) }.font(.caption) } }
                    if level == 0 { Text("No slots at caster level 0.").font(.caption).foregroundStyle(.secondary) }
                    Text("Pact Magic is separate. Applying this table changes only spell slot totals; it does not add cantrips or change your spellbook.").font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(2) }.frame(maxHeight:430)
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Apply slot totals") { apply(GuideRules.slots(at:level)) }.buttonStyle(.borderedProminent) }
        }.padding(18).frame(width:420).background(surface).foregroundStyle(ink).tint(sky)
    }
    func reference(_ record:CharacterClassLevel) -> CompendiumEntry? {
        if record.id == draft.selectedClassID,let entry = draft.classTemplate { return entry }
        return record.referenceID.flatMap { catalog.entries[$0] } ?? catalog.classReference(record.name,edition:draft.hero.edition)
    }
}
