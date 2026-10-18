import SwiftUI

extension CharacterGuide {
    var featuresStep:some View {
        VStack(alignment:.leading,spacing:12) {
            PageToolbar(title:"Features",subtitle:"\(draft.selectedFeatures.count) selected · \(draft.improvementProblems.count) choices left",searchTitle:"Search features…",query:$featureSearch) {
                Button("Custom feature") { featureEditor=CharacterFeature(name:"",category:.classFeature,source:"\(draft.chosenClass.name) · Level \(draft.classLevel)") }.buttonStyle(PageButtonStyle(prominent:true))
            }
            Picker("Feature list",selection:$featureListMode) { Text("Available").tag("Available");Text("Selected").tag("Selected");Text("Needs choice").tag("Needs choice") }.pickerStyle(.segmented).labelsHidden().frame(maxWidth:.infinity).frame(height:PageControl.height)
            if !draft.isLevelUp || draft.featChoiceAvailable { GuideReferencePicker(title:"Feats",options:eligibleFeats,selection:$featChoice,onPreview:{ referencePreview=$0 }) }
            if featureListMode == "Available" {
                PagePicker(title:"Feature source",selectionTitle:featureGroup,selection:$featureGroup) { ForEach(["Class","Ancestry","Background"],id:\.self) { Text($0).tag($0) } }.frame(width:180)
                if let entry=classReference,entry.fields.contains(where:{ $0.name == "autolevel" && Int($0.attributes["level"] ?? "0") == draft.classLevel && $0.attributes["scoreImprovement"]?.uppercased() == "YES" }) { Label("Ability improvement milestone · configure the selected improvement or choose a feat.",systemImage:"sparkles").font(.system(size:11)).foregroundStyle(gold) }
                GuideTable {
                    if candidates.isEmpty { Text("No matching choices. Choose a reference in Class & origin, or add a custom feature.").font(.system(size:12)).foregroundStyle(.secondary).padding(18).frame(maxWidth:.infinity,alignment:.leading) }
                    ForEach(Array(candidates.enumerated()),id:\.element.id) { index,feature in guideFeatureRow(feature,index:index,selectable:true) }
                }
                Text("Origin traits are granted automatically. Core class features start selected; optional and subclass choices stay separate.").font(.system(size:11)).foregroundStyle(.secondary)
            } else if featureListMode == "Needs choice" {
                GuideTable {
                    let choices=draft.improvementFeatures.filter { draft.abilityImprovements[$0.id] == nil && featureMatches($0) }
                    if choices.isEmpty { Text("No unconfigured ability improvement choices match this search.").font(.system(size:12)).foregroundStyle(.secondary).padding(18).frame(maxWidth:.infinity,alignment:.leading) }
                    ForEach(Array(choices.enumerated()),id:\.element.id) { index,feature in guideFeatureRow(feature,index:index,selectable:false) }
                }
            } else {
                GuideTable {
                    if draft.selectedFeatures.filter(featureMatches).isEmpty { Text("No selected features match this search.").font(.system(size:12)).foregroundStyle(.secondary).padding(18).frame(maxWidth:.infinity,alignment:.leading) }
                    ForEach(FeatureCategory.allCases,id:\.self) { category in
                        let entries=draft.selectedFeatures.filter { ($0.category ?? .other) == category && featureMatches($0) }
                        if !entries.isEmpty {
                            Text(category.rawValue+" · \(entries.count)").font(.system(size:10,weight:.semibold)).foregroundStyle(sky).padding(10).frame(maxWidth:.infinity,alignment:.leading).background(surface)
                            ForEach(Array(SelectionRules.outline(entries).enumerated()),id:\.element.id) { index,row in guideFeatureRow(row.feature,index:index,selectable:false).padding(.leading,CGFloat(row.depth)*14) }
                        }
                    }
                }
            }
            GuideSection("Effects & resources",summary:"\((draft.hero.bonuses ?? []).count) bonuses · \((draft.hero.counters ?? []).count) counters") {
                Text("Configure numeric bonuses and usage limits explicitly. Counters keep their independent rest recovery choices.").font(.system(size:11)).foregroundStyle(.secondary)
                ForEach(Array((draft.hero.bonuses ?? []).enumerated()),id:\.element.id) { index,bonus in Button { bonusEditor=bonus } label: { HStack { Text(bonus.name);Spacer();Text(bonusSummary(bonus,hero:draft.result)).foregroundStyle(gold);Image(systemName:"pencil") }.font(.system(size:12)).modifier(GuideTableRow(index:index)) }.buttonStyle(.plain) }
                ForEach(Array((draft.hero.counters ?? []).enumerated()),id:\.element.id) { index,counter in Button { counterEditor=counter } label: { HStack { Text(counter.name);Spacer();Text("\(counter.current)/\(counter.maximum) · \(counter.resetSummary)").foregroundStyle(gold);Image(systemName:"pencil") }.font(.system(size:12)).modifier(GuideTableRow(index:index)) }.buttonStyle(.plain) }
                HStack { Button("Add bonus") { bonusEditor=Bonus() }.buttonStyle(PageButtonStyle());Button("Add counter") { counterEditor=ResourceCounter() }.buttonStyle(PageButtonStyle()) }
            }
        }
    }
    func featureMatches(_ feature:CharacterFeature)->Bool { CompendiumSearch.matches(name:feature.name,summary:feature.category?.rawValue ?? "",classes:"",source:feature.source ?? "",query:featureSearch) }
    func guideFeatureRow(_ feature:CharacterFeature,index:Int,selectable:Bool)->some View {
        let selected=draft.selectedFeatures.contains { $0.id == feature.id }
        let required=draft.requiredOriginIDs.contains(feature.id)
        let known=(draft.original?.featureEntries ?? []).contains { $0.name == feature.name && $0.text == feature.text }
        let improvement=CharacterBuildDraft.isAbilityImprovement(feature)
        let needsChoice=selected && improvement && draft.abilityImprovements[feature.id] == nil
        let status=known ? "Already known":required ? "Granted":needsChoice ? "Needs choice":selected ? "Selected":"Optional"
        return GuideExpandableRow(title:feature.name,subtitle:status+(feature.source.map { " · "+$0 } ?? ""),index:index) {
            if selectable {
                Button { if selected { draft.selectedFeatures.removeAll { $0.id == feature.id } } else { draft.selectedFeatures.append(feature);if improvement { improvementFeature=feature } } } label: { Image(systemName:selected || known ? "checkmark.square.fill":"square").foregroundStyle(selected ? accent:Color.secondary) }.disabled(known || required).help(known ? "Already on character":"Select feature").accessibilityLabel("Select "+feature.name)
            }
            if selected || (improvement && !known) {
            Button { if improvement { openFeatureChoice(feature) } else { featureEditor=feature } } label: { Image(systemName:needsChoice ? "slider.horizontal.3":"pencil").foregroundStyle(needsChoice ? gold:accent) }.help(improvement ? "Configure ability increases or feat":"Edit description, rolls, uses & recovery").accessibilityLabel("Edit "+feature.name)
            }
            GuideFeaturePreviewButton(feature:feature)
            if !selectable && !required { Button { draft.selectedFeatures.removeAll { $0.id == feature.id } } label: { Image(systemName:"minus.circle") }.help("Remove selection").accessibilityLabel("Remove "+feature.name) }
        } content: {
            if improvement && selected { Text(draft.improvementSummary(feature)).font(.system(size:12,weight:.medium)).foregroundStyle(needsChoice ? gold:accent) }
            DescriptionText(text:feature.text.isEmpty ? "No description yet.":feature.text)
        }
    }
}

// Keep read-only presentation state local so opening a preview does not rebuild the draft screen.
struct GuideFeaturePreviewButton:View {
    let feature:CharacterFeature
    @State private var presented=false
    var body:some View {
        Button { presented=true } label: { Image(systemName:"eye") }
            .help("Preview "+feature.name).accessibilityLabel("Preview "+feature.name)
            .sheet(isPresented:$presented) { GuideFeaturePreview(feature:feature) }
    }
}
struct GuideFeaturePreview:View {
    let feature:CharacterFeature
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(alignment:.top) { Text(feature.name).font(.title2.bold());Spacer();Button("Done") { dismiss() } }
            ScrollView { Text(DescriptionMarkdown.attributed(feature.text)).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }
            if let source=feature.source,!source.isEmpty { Divider();Text(source).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }
        }.padding(22).frame(width:640,height:580).background(surface).foregroundStyle(ink)
    }
}
