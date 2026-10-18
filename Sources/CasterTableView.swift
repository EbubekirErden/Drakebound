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
                EditorGroup(title:"Spell allowances · by class") {
                    ForEach(draft.resultingClasses) { record in
                        let allowance=GuideRules.spellAllowance(record,entry:reference(record),hero:draft.result)
                        let base=ClassProfile.named(record.name)?.name ?? record.name
                        let selected=draft.hero.spells.filter { spell in spell.sourceClassID == record.id || (draft.resultingClasses.count == 1 && spell.sourceClassID == nil) || spell.sourceClassName.map { (ClassProfile.named($0)?.name ?? $0) == base } == true }
                        VStack(alignment:.leading,spacing:6) {
                            Text("\(record.name) \(record.level)").font(.system(size:12,weight:.semibold))
                            Text("Cantrips: \(selected.filter { $0.level == 0 && $0.exemptFromClassLimit != true }.count) / \(allowance.cantrips.map(String.init) ?? "check reference")").font(.caption).foregroundStyle(sky)
                            Text("Prepared level 1+: \(selected.filter { $0.level > 0 && $0.prepared && $0.exemptFromClassLimit != true }.count) / \(allowance.prepared.map(String.init) ?? "check reference")").font(.caption)
                            if let count=allowance.known { Text(allowance.knownLabel+": \(count)").font(.caption) }
                            else if ["Cleric","Druid","Paladin"].contains(base) { Text("Access: class spell list").font(.caption) }
                            if let maximum=allowance.maximumLevel { Text("Choose any mix across spell levels 1–\(maximum)").font(.caption2).foregroundStyle(.secondary) }
                        }.padding(.vertical,5)
                    }
                    Text("These are per-class totals, not counts at each spell level. Extra/always-prepared spells can be marked exempt in the spell editor.").font(.caption2).foregroundStyle(.secondary)
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
        }.padding(18).frame(width:460).background(surface).foregroundStyle(ink).tint(sky)
    }
    func reference(_ record:CharacterClassLevel) -> CompendiumEntry? {
        if record.id == draft.selectedClassID,let entry = draft.classTemplate { return entry }
        return record.referenceID.flatMap { catalog.entries[$0] } ?? catalog.classReference(record.name,edition:draft.hero.edition)
    }
}
