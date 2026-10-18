import SwiftUI

struct EquipmentTrainingEditor:View {
    @Binding var grants:[TrainingGrant]?
    var source:String
    var expanded=false
    @State private var weapon="Longsword"
    var body:some View {
        if expanded { controls } else { DisclosureGroup("Weapon & armor training") { controls } }
    }
    var controls:some View {
        VStack(alignment:.leading,spacing:8) {
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],alignment:.leading,spacing:8) {
                ForEach(equipmentTrainingOptions,id:\.0) { key,title in Toggle(title,isOn:Binding(get:{ (grants ?? []).contains { $0.target == key } },set:{ enabled in set(key,enabled) })).toggleStyle(.checkbox).font(.caption) }
            }.padding(.vertical,8)
            HStack { Picker("Specific weapon",selection:$weapon) { ForEach(specificWeaponOptions,id:\.self) { Text($0).tag($0) } }; Button("Add") { set("weapon."+weapon,true) } }
            ForEach((grants ?? []).filter { $0.target.hasPrefix("weapon.") && !["weapon.simple","weapon.martial"].contains($0.target) }) { grant in HStack { Text(trainingTargetName(grant.target)); Spacer(); Button { set(grant.target,false) } label: { Image(systemName:"minus.circle") } }.font(.caption) }
        }.font(.caption)
    }
    func set(_ key:String,_ enabled:Bool) { var list=grants ?? [];list.removeAll { $0.target == key };if enabled { list.append(TrainingGrant(target:key,source:source)) };grants=list }
}
struct LoadoutFeatureReference:View {
    var features:[CharacterFeature]
    var body:some View { VStack(alignment:.leading,spacing:12) { Text("Features & traits").font(.headline); ScrollView { VStack(alignment:.leading,spacing:9) { ForEach(FeatureCategory.allCases,id:\.self) { category in let entries=features.filter { ($0.category ?? .other) == category }; if !entries.isEmpty { Text(category.rawValue).font(.caption.bold()).foregroundStyle(sky); ForEach(SelectionRules.outline(entries)) { row in DisclosureGroup(row.feature.name) { Text(row.feature.text).font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,7) }.padding(.leading,CGFloat(row.depth)*14) } } } } } }.padding(18).frame(width:420,height:440) }
}
struct GuidedImprovementEditor:View {
    var feature:CharacterFeature
    var draft:CharacterBuildDraft
    var feats:[CompendiumEntry]
    var onSave:(AbilityImprovementChoice)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var choice=AbilityImprovementChoice()
    @State private var otherFeat=false
    @State private var featID:UUID?
    @State private var preview:CompendiumEntry?
    init(feature:CharacterFeature,draft:CharacterBuildDraft,feats:[CompendiumEntry],onSave:@escaping(AbilityImprovementChoice)->Void) {
        self.feature=feature;self.draft=draft;self.feats=feats;self.onSave=onSave
        let prior=draft.abilityImprovements[feature.id] ?? AbilityImprovementChoice()
        _choice=State(initialValue:prior);_otherFeat=State(initialValue:prior.feat != nil)
    }
    var problem:String? { otherFeat && choice.feat == nil ? "Choose a feat.":draft.improvementProblem(choice,for:feature.id) }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Ability improvement choice").font(.title2.bold()); Spacer(); Button("Cancel") { dismiss() } }
            Text(feature.source ?? feature.name).font(.caption).foregroundStyle(sky)
            Picker("Choice",selection:$otherFeat) { Text("Ability Score Improvement").tag(false);Text("Another feat").tag(true) }.pickerStyle(.segmented).onChange(of:otherFeat) { _,_ in choice=AbilityImprovementChoice();featID=nil }
            if otherFeat { if let feat=choice.feat { Text("Selected: "+feat.name).font(.caption) }; GuideReferencePicker(title:"Feats",options:feats,selection:$featID,onPreview:{ preview=$0 }).onChange(of:featID) { _,id in if let entry=feats.first(where:{ $0.id == id }),var f=entry.featureCopies().first { f.id=guideID(feature.id.uuidString+"-chosen-feat");choice.feat=f } else { choice.feat=nil } }; Text("Record an ability increase below only if the selected feat grants it.").font(.caption).foregroundStyle(.secondary) }
            ForEach(0..<6,id:\.self) { i in HStack { Text(abilities[i]); Spacer(); Picker(abilities[i],selection:$choice.increases[i]) { ForEach(0...(otherFeat ? 1:2),id:\.self) { Text(signed($0)).tag($0) } }.labelsHidden().frame(width:90) }.font(.system(size:12)) }
            if let problem { Text(problem).font(.caption).foregroundStyle(gold) }
            HStack { Text("\(choice.increases.reduce(0,+)) / \(otherFeat ? 1:2) ability points").font(.caption); Spacer(); Button("Apply choice") { onSave(choice);dismiss() }.buttonStyle(.borderedProminent).disabled(problem != nil) }
        }.padding(22).frame(width:480).sheet(item:$preview) { GuideReferencePreview(entry:$0) }
    }
}
extension CharacterGuide {
    func openFeatureChoice(_ feature:CharacterFeature) {
        if CharacterBuildDraft.isAbilityImprovement(feature) {
            if !draft.selectedFeatures.contains(where:{ $0.id == feature.id }) { draft.selectedFeatures.append(feature) }
            improvementFeature=feature
        } else { featurePreview=feature }
    }
    var starterEquipmentChoices:some View {
        GuideSection("Starting equipment & packs",summary:"Choose a pack or starting wealth",expanded:true) {
            let kits=catalog.startingKits(classEntry:classReference,background:draft.backgroundTemplate,edition:draft.hero.edition)
            ForEach(kits) { kit in DisclosureGroup(kit.name) {
                VStack(alignment:.leading,spacing:10) {
                    Text(kit.items.map { "\($0.1) × \($0.0)" }.joined(separator:" · ")+(kit.gold > 0 ? " · \(kit.gold) gp":""))
                        .font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                    Button(draft.appliedStarterKits.contains(kit.id) ? "Added":"Add equipment") { draft.applyStarterKit(kit,catalog:catalog) }
                        .buttonStyle(PageButtonStyle())
                        .disabled(draft.appliedStarterKits.contains(kit.id) || (kit.groupID.map { draft.appliedStarterKits.contains("group:"+$0) } ?? false))
                    if !kit.source.isEmpty { Text(kit.source).font(.system(size:10)).foregroundStyle(.secondary).textSelection(.enabled) }
                }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,8)
            }.font(.caption) }
            if kits.isEmpty { Button("View starting equipment reference") { if let classReference { referencePreview=classReference } }.disabled(classReference == nil) }
        }
    }
}

struct EquipmentTrainingRoster:View {
    var hero:Hero
    var body:some View {
        let grants=hero.equipmentTrainingGrants
        if grants.isEmpty { Text("No weapon or armor training recorded").font(.caption).foregroundStyle(.secondary) }
        ForEach(Array(Set(grants.map(\.target))).sorted(),id:\.self) { target in
            HStack(alignment:.top) { Text(trainingTargetName(target));Spacer();Text(Array(Set(grants.filter { $0.target == target }.map(\.source))).sorted().joined(separator:" · ")).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }.font(.caption)
        }
    }
}
