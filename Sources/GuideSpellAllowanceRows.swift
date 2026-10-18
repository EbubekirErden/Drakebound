import SwiftUI

struct GuideSpellAllowanceRows:View {
    var draft:CharacterBuildDraft
    var catalog:GuideCatalog
    var body:some View {
        let hero=draft.result
        let classes=draft.resultingClasses
        VStack(alignment:.leading,spacing:10) {
            ForEach(classes.filter { $0.casting != .none || !GuideLoadoutSummary.spells(hero.spells,for:$0,classes:classes).isEmpty }) { record in
                let entry=record.id == draft.selectedClassID ? draft.classTemplate:record.referenceID.flatMap { catalog.entries[$0] } ?? catalog.classReference(record.name,edition:hero.edition)
                let allowance=GuideRules.spellAllowance(record,entry:entry,hero:hero)
                let selected=GuideLoadoutSummary.spells(hero.spells,for:record,classes:classes)
                let counted=selected.filter { $0.exemptFromClassLimit != true }
                VStack(alignment:.leading,spacing:8) {
                    Text(record.name+" · level \(record.level)").font(.system(size:12,weight:.semibold))
                    count("Cantrips",counted.filter { $0.level == 0 }.count,allowance.cantrips)
                    count("Prepared level 1+",counted.filter { $0.level > 0 && $0.prepared }.count,allowance.prepared)
                    if let known=allowance.known { count(allowance.knownLabel,counted.filter { $0.level > 0 }.count,known) }
                    let extra=selected.filter { $0.exemptFromClassLimit == true }.count
                    if extra > 0 { Text("\(extra) extra / always-prepared · excluded from counts above").font(.system(size:11)).foregroundStyle(.secondary) }
                    if let maximum=allowance.maximumLevel { Text("Class spell levels: 1–\(maximum)").font(.system(size:11)).foregroundStyle(.secondary) }
                }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(paper.opacity(0.5),in:RoundedRectangle(cornerRadius:7))
            }
            let unassigned=GuideLoadoutSummary.unassignedSpells(hero.spells,classes:classes)
            if unassigned > 0 { Text("\(unassigned) spells have no matching casting class. Review their Cast as class setting in the spell editor.").font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
            Text("Counts are per class. Unknown allowances need a reference check; these summaries do not restrict your choices.").font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
    private func count(_ label:String,_ selected:Int,_ allowance:Int?)->some View {
        HStack { Text(label).foregroundStyle(.secondary);Spacer();Text(allowance.map { "\(selected) / \($0)" } ?? "\(selected) · check reference").monospacedDigit() }.font(.system(size:12))
    }
}
