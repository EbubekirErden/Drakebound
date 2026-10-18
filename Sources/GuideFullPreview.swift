import SwiftUI

struct GuideFullPreview:View {
    var draft:CharacterBuildDraft
    @State private var page = "Sheet"
    @Environment(\.dismiss) private var dismiss
    var hero:Hero { draft.result }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { VStack(alignment:.leading,spacing:4) { Text(hero.name.isEmpty ? "Character preview":hero.name).font(.title2.bold()); Text("Draft · \(hero.characterClass)").font(.caption).foregroundStyle(sky) }; Spacer(); Button("Done") { dismiss() } }
            Picker("Preview section",selection:$page) { ForEach(["Sheet","Features & training","Changes"],id:\.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    switch page { case "Features & training":choices; case "Changes":changes; default:sheet }
                }.padding(2).frame(maxWidth:.infinity,alignment:.leading)
            }
        }.padding(22).frame(width:780,height:610).background(paper).foregroundStyle(ink).tint(accent)
    }
    var sheet:some View {
        VStack(spacing:14) {
            HStack(spacing:12) { metric("HP","\(hero.hp) / \(hero.maximumHP)",leaf); metric("Armor class","\(hero.armorClass)",sky); metric("Proficiency",signed(hero.proficiency),gold); metric("Speed","\(hero.movement) ft",accent) }
            LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:6),spacing:8) { ForEach(0..<6,id:\.self) { i in VStack(spacing:5) { Text(String(abilities[i].prefix(3)).uppercased()).font(.caption2).foregroundStyle(.secondary); Text("\(hero.effectiveScore(i))").font(.title2.monospacedDigit()); Text(signed(hero.modifier(i))).foregroundStyle(sky) }.padding(10).frame(maxWidth:.infinity).background(surface).clipShape(RoundedRectangle(cornerRadius:7)) } }
            EditorGroup(title:"Attacks") {
                if hero.attacks.isEmpty { Text("No attacks configured").font(.caption).foregroundStyle(.secondary) }
                ForEach(hero.attacks) { attack in HStack { VStack(alignment:.leading,spacing:3) { Text(attack.name); if let reason = hero.attackUnavailableReason(attack) { Text(reason).font(.caption2).foregroundStyle(gold) } }; Spacer(); Text(signed(hero.attackBonus(attack))).foregroundStyle(sky).frame(width:55); Text(hero.expression(attack.damage,bonus:hero.damageBonus(attack),targets:hero.attackTargets(attack,damage:true))).foregroundStyle(coral).frame(width:130,alignment:.trailing) }.font(.system(size:12)) }
            }
            HStack(alignment:.top,spacing:14) {
                EditorGroup(title:"Saving throws") { ForEach(0..<6,id:\.self) { i in HStack { Text(abilities[i]); Spacer(); Text(signed(hero.saveBonus(i))).foregroundStyle(hero.isSaveProficient(i) ? sky:ink) }.font(.caption) } }
                EditorGroup(title:"Trained skills") { ForEach(skills.filter { hero.effectiveSkillRank($0.0) > 0 },id:\.0) { name,ability in HStack { Text(name); Spacer(); Text(signed(hero.skillBonus(name,ability))).foregroundStyle(sky) }.font(.caption) } }
            }
            EditorGroup(title:"Spellbook · \(hero.spells.count)") {
                ForEach(hero.spells) { spell in HStack { Image(systemName:spell.prepared ? "checkmark.circle.fill":"circle").foregroundStyle(spell.prepared ? accent:Color.secondary); Text(spell.name); Spacer(); Text(spell.sourceClassName ?? "Default casting").foregroundStyle(.secondary); Text(spell.level == 0 ? "Cantrip":"Level \(spell.level)").foregroundStyle(sky).frame(width:58,alignment:.trailing) }.font(.caption) }
            }
            EditorGroup(title:"Equipment · \(hero.items.count)") { ForEach(hero.items) { item in HStack { Text(item.name); Spacer(); Text("×\(item.quantity)").monospacedDigit(); Text(item.equipped ? "Equipped":"Carried").foregroundStyle(item.equipped ? accent:Color.secondary).frame(width:70,alignment:.trailing) }.font(.caption) } }
            EditorGroup(title:"Resources") { ForEach(hero.counters ?? []) { counter in HStack { Text(counter.name); Spacer(); Text("\(counter.current) / \(counter.maximum)"); Text(counter.resetSummary).foregroundStyle(.secondary) }.font(.caption) } }
        }
    }
    var choices:some View {
        VStack(alignment:.leading,spacing:14) {
            ForEach(hero.progressionClasses) { record in EditorGroup(title:record.name) { Text("Class level \(record.level) · d\(record.hitDie) · \(record.casting.rawValue)").font(.caption); if !record.subclass.isEmpty { Text(record.subclass).font(.caption).foregroundStyle(sky) } } }
            EditorGroup(title:"\(hero.ancestry) · \(hero.background)") {
                let facts = (hero.ancestryFacts ?? [])+(hero.backgroundFacts ?? [])
                if !facts.isEmpty { ReferenceMetadataTable(fields:facts) }
            }
            EditorGroup(title:"Features & traits") { ForEach(hero.featureEntries ?? []) { feature in DisclosureGroup { Text(feature.text).font(.system(size:12)).lineSpacing(4).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,8); if let counter = feature.counter { Text("Uses \(counter.current)/\(counter.maximum) · \(counter.resetSummary)").font(.caption).foregroundStyle(gold) } } label: { VStack(alignment:.leading,spacing:3) { Text(feature.name).font(.system(size:12,weight:.medium)); Text(feature.source ?? feature.category?.rawValue ?? "Custom").font(.caption2).foregroundStyle(.secondary) } } } }
            EditorGroup(title:"Training sources") { ForEach(Array(hero.allTraining.enumerated()),id:\.offset) { _,grant in HStack { Text(trainingName(grant.target)); Spacer(); Text(grant.source).foregroundStyle(.secondary); Text(grant.rank == 2 ? "Expertise":"Proficient").foregroundStyle(sky).frame(width:65,alignment:.trailing) }.font(.caption) }; Text("Multiple sources are retained; proficiency applies once and expertise doubles it once.").font(.caption2).foregroundStyle(.secondary) }
        }
    }
    var changes:some View {
        VStack(alignment:.leading,spacing:12) {
            Text(draft.isLevelUp ? "Before → after":"Creation choices").font(.headline)
            ForEach(Array(draft.changeSummary.enumerated()),id:\.offset) { _,line in Text(line).font(.system(size:12)).frame(maxWidth:.infinity,alignment:.leading).padding(10).background(surface).clipShape(RoundedRectangle(cornerRadius:6)) }
            if !draft.problems.isEmpty { EditorGroup(title:"Still needed") { ForEach(draft.problems,id:\.self) { Text($0).font(.caption).foregroundStyle(gold) } } }
        }
    }
    func trainingName(_ target:String) -> String { if target.hasPrefix("skill.") { return String(target.dropFirst(6)) }; if let i = Int(target.dropFirst(5)),abilities.indices.contains(i) { return abilities[i]+" save" }; return target }
    func metric(_ title:String,_ value:String,_ color:Color) -> some View { VStack(spacing:6) { Text(title.uppercased()).font(.system(size:9,weight:.semibold)).foregroundStyle(.secondary); Text(value).font(.system(size:21,weight:.medium,design:.rounded)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7) }.padding(12).frame(maxWidth:.infinity).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:8)) }
}
