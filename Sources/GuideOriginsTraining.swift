import SwiftUI

extension CharacterGuide {
    var subclassOptions:[GuideSubclass] { classReference.map(GuideRules.subclasses) ?? [] }
    var subclassPicker:some View {
        VStack(alignment:.leading,spacing:8) {
            if !subclassOptions.isEmpty {
                HStack {
                    Text("Subclass").font(.system(size:12))
                    Menu {
                        Button("Choose when granted") { draft.chooseSubclass("") }
                        ForEach(subclassOptions) { option in Button("\(option.name) · class level \(option.level)") { draft.chooseSubclass(option.name) }.disabled(draft.classLevel < option.level) }
                    } label: { Text(draft.chosenClass.subclass.isEmpty ? "Choose when granted":draft.chosenClass.subclass).frame(maxWidth:.infinity,alignment:.leading) }
                    .help("Subclass choices unlock at their own class level")
                }
                if let choice = subclassOptions.first(where:{ $0.name == draft.chosenClass.subclass }) { HStack { Text("Subclass features follow this choice.").font(.caption2).foregroundStyle(.secondary); Spacer(); Button("Preview subclass") { featurePreview = choice.feature } } }
                else if let level = subclassOptions.map(\.level).min(),draft.classLevel < level { Text("Available at \(draft.chosenClass.name) class level \(level). Browse the class preview to read ahead.").font(.caption2).foregroundStyle(.secondary) }
            } else { Text("No subclass headings are defined in this class reference.").font(.caption2).foregroundStyle(.secondary) }
            DisclosureGroup("Custom or imported subclass") { TextField("Subclass name",text:$draft.chosenClass.subclass); Text("Add its features with Custom feature. Use your table’s class-level requirement.").font(.caption2).foregroundStyle(.secondary) }.font(.caption)
        }
    }
    var originChoices:some View {
        EditorGroup(title:"Ancestry & background") {
            HStack { Text("Ancestry / species").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Custom ancestry…") { customOrigin = CompendiumCreation(category:.race) } }
            GuideReferencePicker(title:"Ancestries",options:catalog.ancestries,selection:$draft.ancestryReference,onPreview:{ referencePreview = $0 },edition:draft.hero.edition)
            if let entry = draft.ancestryTemplate { originSummary(entry) }
            HStack { Text("Background").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Custom background…") { customOrigin = CompendiumCreation(category:.background) } }
            GuideReferencePicker(title:"Backgrounds",options:catalog.backgrounds,selection:$draft.backgroundReference,onPreview:{ referencePreview = $0 })
            if let entry = draft.backgroundTemplate { originSummary(entry) }
            Text("The selected origin’s traits and structured skill training are granted automatically. Custom origins require their rules and features.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    func originSummary(_ entry:CompendiumEntry) -> some View {
        HStack { VStack(alignment:.leading,spacing:4) { Text(entry.name).font(.system(size:12,weight:.semibold)); Text("\(GuideRules.originFeatures(entry).count) granted traits\(entry.category == .race ? " · \(entry.value("speed")) ft":"")").font(.caption2).foregroundStyle(.secondary) }; Spacer(); Button { referencePreview = entry } label: { Image(systemName:"eye") }.help("Preview \(entry.name)") }.padding(10).background(surface).clipShape(RoundedRectangle(cornerRadius:7))
    }
    var classSkillOptions:[String] {
        let values = classReference?.value("proficiency").components(separatedBy:",").map { $0.trimmingCharacters(in:.whitespacesAndNewlines) } ?? []
        let allowed = skills.map(\.0).filter(values.contains)
        return allowed.isEmpty ? skills.map(\.0):allowed
    }
    var guideTraining:some View {
        VStack(spacing:14) {
            EditorGroup(title:draft.isLevelUp ? "Existing training · preserved":"Starting saving throws") {
                Text((0..<6).filter { draft.result.isSaveProficient($0) }.map { abilities[$0] }.joined(separator:" · ")).font(.system(size:12))
                if draft.isLevelUp { Text("Starting saving throws and prior skill training stay unchanged. New grants from features are added by source below.").font(.caption).foregroundStyle(.secondary)
                    ForEach(skills.filter { draft.result.effectiveSkillRank($0.0) > 0 },id:\.0) { name,_ in HStack { Text(name); Spacer(); Text(draft.result.effectiveSkillRank(name) == 2 ? "Expertise":"Proficient").foregroundStyle(sky) }.font(.caption).help(draft.result.trainingSources("skill."+name).joined(separator:" · ")) }
                } else { Text("Granted by your starting class.").font(.caption2).foregroundStyle(.secondary) }
            }
            if !draft.isLevelUp {
                EditorGroup(title:"Class skill choices",badge:"\(draft.classSkillChoices.count) / \(draft.startingSkillCount)") {
                    Text("Choose \(draft.startingSkillCount) skills from your class’s list. Origin and feature grants appear separately.").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],alignment:.leading,spacing:9) {
                        ForEach(classSkillOptions,id:\.self) { name in Toggle(name,isOn:Binding(get:{ draft.classSkillChoices.contains(name) },set:{ value in if value { draft.classSkillChoices.insert(name) } else { draft.classSkillChoices.remove(name) } })).toggleStyle(.checkbox).font(.system(size:12)) }
                    }
                }
            }
            EditorGroup(title:"Weapon & armor proficiency") {
                EquipmentTrainingRoster(hero:draft.result)
                EquipmentTrainingEditor(grants:Binding(get:{ draft.trainingAdditions },set:{ draft.trainingAdditions=$0 ?? [] }),source:"Character creation / advancement",expanded:true)
            }
            EditorGroup(title:"Training sources") {
                let grants = draft.result.allTraining
                if grants.isEmpty { Text("No extra training grants.").font(.caption).foregroundStyle(.secondary) }
                ForEach(Array(grants.enumerated()),id:\.offset) { _,grant in HStack(alignment:.top) { VStack(alignment:.leading,spacing:3) { Text(trainingTargetName(grant.target)).font(.system(size:12)); Text(grant.source).font(.system(size:10)).foregroundStyle(.secondary) }; Spacer(); Text(grant.rank == 2 ? "Expertise":"Proficient").font(.caption).foregroundStyle(sky) } }
                Text("Proficiency is applied once per check; the strongest expertise grant wins. Independent flat or dice bonuses still add.").font(.caption2).foregroundStyle(.secondary)
                TrainingGrantEditor(grants:Binding(get:{ draft.trainingAdditions },set:{ draft.trainingAdditions = $0 ?? [] }),source:"\(draft.chosenClass.name) · level \(draft.classLevel)")
            }
            EditorGroup(title:"Languages, tools & other training") { BorderedTextEditor(text:$draft.trainingNotes,height:65); Text("Saved as a separate Languages & training feature.").font(.caption2).foregroundStyle(.secondary) }
        }
    }
}
