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
    @ViewBuilder var originChoices:some View {
        EditorColumns {
            GuideSection("Ancestry / species",summary:draft.hero.ancestry.isEmpty ? "Choose an origin":draft.hero.ancestry,expanded:true) {
                GuideReferencePicker(title:"Ancestries",options:catalog.ancestries,selection:$draft.ancestryReference,onPreview:{ referencePreview = $0 },edition:draft.hero.edition)
                if let entry=draft.ancestryTemplate { Text("\(GuideRules.originFeatures(entry).count) granted traits · \(entry.value("speed")) ft").font(.system(size:11)).foregroundStyle(.secondary) }
                Button("Custom ancestry…") { customOrigin=CompendiumCreation(category:.race) }.buttonStyle(PageButtonStyle())
            }
        } trailing: {
            GuideSection("Background",summary:draft.hero.background.isEmpty ? "Choose a background":draft.hero.background,expanded:true) {
                GuideReferencePicker(title:"Backgrounds",options:catalog.backgrounds,selection:$draft.backgroundReference,onPreview:{ referencePreview = $0 })
                if let entry=draft.backgroundTemplate { Text("\(GuideRules.originFeatures(entry).count) granted traits").font(.system(size:11)).foregroundStyle(.secondary) }
                Button("Custom background…") { customOrigin=CompendiumCreation(category:.background) }.buttonStyle(PageButtonStyle())
            }
        }
        Text("Origin traits and structured training are included automatically. Use Custom for your own origin rules.").font(.system(size:11)).foregroundStyle(.secondary)
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
        GuideTable {
            if !draft.isLevelUp {
                GuideSection("Class skill choices",summary:"\(draft.classSkillChoices.count) / \(draft.startingSkillCount) selected",expanded:true) {
                    Text("Choose \(draft.startingSkillCount) class skills. Origin and feature grants are listed separately.").font(.system(size:11)).foregroundStyle(.secondary)
                    LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],alignment:.leading,spacing:1) {
                        ForEach(Array(classSkillOptions.enumerated()),id:\.element) { index,name in Toggle(name,isOn:Binding(get:{ draft.classSkillChoices.contains(name) },set:{ value in if value { draft.classSkillChoices.insert(name) } else { draft.classSkillChoices.remove(name) } })).toggleStyle(.checkbox).font(.system(size:12)).modifier(GuideTableRow(index:index/2)) }
                    }
                }
            }
            GuideSection(draft.isLevelUp ? "Existing training":"Starting saving throws",summary:"\((0..<6).filter { draft.result.isSaveProficient($0) }.count) saves",expanded:!draft.isLevelUp) {
                Text((0..<6).filter { draft.result.isSaveProficient($0) }.map { abilities[$0] }.joined(separator:" · ")).font(.system(size:12))
                if draft.isLevelUp {
                    Text("Prior training stays preserved. Additional grants appear by source below.").font(.system(size:11)).foregroundStyle(.secondary)
                    ForEach(Array(skills.filter { draft.result.effectiveSkillRank($0.0) > 0 }.enumerated()),id:\.element.0) { index,skill in HStack { Text(skill.0);Spacer();Text(draft.result.effectiveSkillRank(skill.0) == 2 ? "Expertise":"Proficient").foregroundStyle(sky) }.font(.system(size:12)).help(draft.result.trainingSources("skill."+skill.0).joined(separator:" · ")).modifier(GuideTableRow(index:index)) }
                } else { Text("Granted by your starting class.").font(.system(size:11)).foregroundStyle(.secondary) }
            }
            GuideSection("Weapon & armor training",summary:"Granted and additional proficiencies") {
                EquipmentTrainingRoster(hero:draft.result)
                Text("Additional training").font(.system(size:11,weight:.semibold)).foregroundStyle(.secondary)
                EquipmentTrainingEditor(grants:Binding(get:{ draft.trainingAdditions },set:{ draft.trainingAdditions=$0 ?? [] }),source:"Character creation / advancement",expanded:true)
            }
            GuideSection("Additional skills & expertise",summary:"\(draft.trainingAdditions.filter { $0.target.hasPrefix("skill.") || $0.target.hasPrefix("save.") }.count) recorded") {
                TrainingGrantEditor(grants:Binding(get:{ draft.trainingAdditions },set:{ draft.trainingAdditions=$0 ?? [] }),source:"\(draft.chosenClass.name) · level \(draft.classLevel)",expanded:true,includeEquipment:false)
            }
            GuideSection("Languages, tools & other training",summary:draft.trainingNotes.isEmpty ? "Optional":"Notes recorded") {
                BorderedTextEditor(text:$draft.trainingNotes,height:75,markdown:true)
                Text("Saved as a separate Languages & training feature.").font(.system(size:11)).foregroundStyle(.secondary)
            }
            GuideSection("Training sources",summary:"\(draft.result.allTraining.count) grants") {
                if draft.result.allTraining.isEmpty { Text("No extra training grants.").font(.system(size:12)).foregroundStyle(.secondary) }
                ForEach(Array(draft.result.allTraining.enumerated()),id:\.offset) { index,grant in HStack(alignment:.top) { VStack(alignment:.leading,spacing:3) { Text(trainingTargetName(grant.target));Text(grant.source).font(.system(size:10)).foregroundStyle(.secondary) };Spacer();Text(grant.rank == 2 ? "Expertise":"Proficient").foregroundStyle(sky) }.font(.system(size:12)).modifier(GuideTableRow(index:index)) }
                Text("Proficiency applies once; expertise doubles it once. Independent numeric bonuses still add.").font(.system(size:11)).foregroundStyle(.secondary)
            }
        }
    }
}
