import SwiftUI

struct GuideReview:View {
    var catalog:GuideCatalog
    var draft:CharacterBuildDraft
    var onEdit:(GuideStep)->Void
    var onPreview:()->Void
    var onLoadoutEdit:((String)->Void)?
    @State private var changesOnly:Bool
    init(draft:CharacterBuildDraft,catalog:GuideCatalog,onEdit:@escaping(GuideStep)->Void,onPreview:@escaping()->Void,onLoadoutEdit:((String)->Void)? = nil) {
        self.catalog=catalog;self.draft=draft;self.onEdit=onEdit;self.onPreview=onPreview;self.onLoadoutEdit=onLoadoutEdit
        _changesOnly=State(initialValue:draft.isLevelUp)
    }
    private var hero:Hero { draft.result }
    private var before:Hero? { draft.original }
    private var shownSpells:[Spell] { hero.spells.filter { spell in !changesOnly || before?.spells.first(where:{ $0.id == spell.id }) != spell } }
    private var shownItems:[Item] { hero.items.filter { item in !changesOnly || before?.items.first(where:{ $0.id == item.id }) != item } }
    private var shownFeatures:[CharacterFeature] { (hero.featureEntries ?? []).filter { feature in !changesOnly || before?.featureEntries?.first(where:{ $0.id == feature.id }) != feature } }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(spacing:12) {
                Portrait(data:hero.portrait,name:hero.name,size:48)
                VStack(alignment:.leading,spacing:4) {
                    Text(hero.name.isEmpty ? "Your adventurer":hero.name).font(.system(size:21,weight:.semibold))
                    Text(hero.characterClass+" · "+hero.edition).font(.system(size:12)).foregroundStyle(sky)
                }
                Spacer(minLength:4)
                Button(action:onPreview) { Image(systemName:"arrow.up.left.and.arrow.down.right") }.buttonStyle(PageButtonStyle()).help("Preview the full character sheet").accessibilityLabel("Preview full sheet")
            }
            if !draft.guideIssues.isEmpty {
                VStack(alignment:.leading,spacing:9) {
                    Label("\(draft.guideIssues.count) required \(draft.guideIssues.count == 1 ? "choice":"choices") to finish",systemImage:"exclamationmark.circle").font(.system(size:13,weight:.semibold))
                    ForEach(draft.guideIssues) { issue in Button { onEdit(issue.step) } label: { HStack(alignment:.top) { Text(issue.message).fixedSize(horizontal:false,vertical:true);Spacer(minLength:8);Text("Fix · "+issue.step.rawValue).foregroundStyle(accent) }.font(.system(size:12)).frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain) }
                }.padding(12).background(gold.opacity(0.07),in:RoundedRectangle(cornerRadius:8)).foregroundStyle(gold)
            } else { Label("Required choices complete",systemImage:"checkmark.circle.fill").font(.system(size:12)).foregroundStyle(leaf) }
            HStack(spacing:10) {
                metric("Level",old:before.map { String($0.level) },value:String(hero.level),color:accent)
                metric("Maximum HP",old:before.map { String($0.maximumHP) },value:String(hero.maximumHP),color:leaf)
                metric("Armor class",old:before.map { String($0.armorClass) },value:String(hero.armorClass),color:sky)
                metric("Proficiency",old:before.map { signed($0.proficiency) },value:signed(hero.proficiency),color:gold)
            }
            if draft.isLevelUp {
                HStack { Text("Review this level").font(.system(size:13,weight:.semibold));Spacer();Toggle("Changes only",isOn:$changesOnly).help("Expanded lists focus on changes; row summaries show final totals.").font(.system(size:11)).toggleStyle(.checkbox) }
                Text("Current HP: \(before!.hp) → \(hero.hp). This advancement does not perform a rest.").font(.system(size:11)).foregroundStyle(.secondary)
            }
            VStack(spacing:0) {
                GuideReviewSection(index:0,title:"Class & origin",summary:[hero.ancestry,hero.background].filter { !$0.isEmpty }.joined(separator:" · "),onEdit:{ onEdit(.origin) }) {
                    ForEach(hero.progressionClasses) { record in GuideSummaryRow(title:record.name,previous:before?.progressionClasses.first(where:{ $0.id == record.id }).map { String($0.level) },value:"Level \(record.level)"+(record.subclass.isEmpty ? "":" · "+record.subclass)) }
                    GuideSummaryRow(title:"Ancestry",value:hero.ancestry.isEmpty ? "Not chosen":hero.ancestry)
                    GuideSummaryRow(title:"Background",value:hero.background.isEmpty ? "Not chosen":hero.background)
                    if !draft.isLevelUp { Button("Edit name, portrait & edition") { onEdit(.identity) }.buttonStyle(.plain).foregroundStyle(accent).font(.system(size:11)) }
                }
                GuideReviewSection(index:1,title:"Abilities & health",summary:(0..<6).map { String(hero.effectiveScore($0)) }.joined(separator:" / "),onEdit:{ onEdit(draft.guideSteps.contains(.abilities) ? .abilities:.vitality) }) {
                    ForEach(0..<6,id:\.self) { i in
                        if !changesOnly || before?.effectiveScore(i) != hero.effectiveScore(i) { GuideSummaryRow(title:abilities[i],previous:before.map { String($0.effectiveScore(i)) },value:"\(hero.effectiveScore(i)) · \(signed(hero.modifier(i))) modifier") }
                    }
                    if !changesOnly || before?.hp != hero.hp { GuideSummaryRow(title:"Current HP",previous:before.map { String($0.hp) },value:String(hero.hp)) }
                    if !changesOnly || before?.maximumHP != hero.maximumHP { GuideSummaryRow(title:"Maximum HP",previous:before.map { String($0.maximumHP) },value:String(hero.maximumHP)) }
                    if !changesOnly || before?.movement != hero.movement { GuideSummaryRow(title:"Speed",previous:before.map { "\($0.movement) ft" },value:"\(hero.movement) ft") }
                    if draft.isLevelUp { Button("Edit HP gain") { onEdit(.vitality) }.buttonStyle(.plain).foregroundStyle(accent).font(.system(size:11)) }
                }
                GuideReviewSection(index:2,title:"Training",summary:"\(skills.filter { hero.effectiveSkillRank($0.0) > 0 }.count) skills · \((0..<6).filter { hero.isSaveProficient($0) }.count) saves",onEdit:{ onEdit(.training) }) {
                    ForEach(skills.filter { hero.effectiveSkillRank($0.0) > 0 },id:\.0) { name,_ in
                        if !changesOnly || before?.effectiveSkillRank(name) != hero.effectiveSkillRank(name) { GuideSummaryRow(title:name,value:hero.effectiveSkillRank(name) == 2 ? "Expertise":"Proficient") }
                    }
                    GuideSummaryRow(title:"Saving throws",value:(0..<6).filter { hero.isSaveProficient($0) }.map { abilities[$0] }.joined(separator:", "))
                    DisclosureGroup("Training sources") { ForEach(Array(hero.allTraining.enumerated()),id:\.offset) { _,grant in GuideSummaryRow(title:trainingTargetName(grant.target),value:grant.source) } }.font(.system(size:11))
                    if !draft.trainingNotes.isEmpty { DescriptionText(text:draft.trainingNotes) }
                }
                GuideReviewSection(index:3,title:"Features & resources",summary:"\(draft.selectedFeatures.count) new · \((hero.counters ?? []).count) counters",expanded:true,onEdit:{ onEdit(.features) }) {
                    if shownFeatures.isEmpty { Text("No feature changes.").font(.system(size:12)).foregroundStyle(.secondary) }
                    ForEach(shownFeatures) { feature in DisclosureGroup { DescriptionText(text:feature.text).padding(.vertical,7) } label: { HStack { Text(feature.name);Spacer();if before?.featureEntries?.contains(where:{ $0.id == feature.id }) != true { Text("New").font(.system(size:10)).foregroundStyle(accent) } } }.font(.system(size:12)) }
                    ForEach(hero.bonuses ?? []) { bonus in GuideSummaryRow(title:bonus.name,value:bonusSummary(bonus,hero:hero)) }
                    ForEach(hero.counters ?? []) { counter in GuideSummaryRow(title:counter.name,value:"\(counter.current)/\(counter.maximum) · \(counter.resetSummary)") }
                }
                GuideReviewSection(index:4,title:"Spellbook & slots",summary:"\(hero.spells.count) spells · \(hero.spells.filter(\.prepared).count) prepared",onEdit:{ if let onLoadoutEdit { onLoadoutEdit("Spells") } else { onEdit(.loadout) } }) {
                    GuideSpellAllowanceRows(draft:draft,catalog:catalog)
                    ForEach(0..<9,id:\.self) { i in if (hero.slots[i] > 0 || (before?.slots[i] ?? 0) > 0) && (!changesOnly || before?.slots[i] != hero.slots[i] || before?.usedSlots[i] != hero.usedSlots[i]) { GuideSummaryRow(title:"Level \(i+1) slots",previous:before.map { String($0.slots[i]) },value:"\(hero.slots[i]) total · \(hero.usedSlots[i]) spent") } }
                    ForEach(shownSpells) { spell in HStack { GuideSummaryRow(title:spell.name,value:(spell.level == 0 ? "Cantrip":"L\(spell.level)")+" · "+(spell.prepared ? "Prepared":"Unprepared"));GuidePreviewButton(name:spell.name) { GuideSpellPreview(spell:spell) } } }
                    ForEach(before?.spells.filter { old in !hero.spells.contains { $0.id == old.id } } ?? []) { spell in GuideSummaryRow(title:spell.name,value:"Removed").foregroundStyle(coral) }
                }
                GuideReviewSection(index:5,title:"Equipment",summary:"\(hero.items.count) entries · \(GuideLoadoutSummary.quantity(hero.items)) total quantity · \(hero.items.filter(\.equipped).count) equipped",onEdit:{ if let onLoadoutEdit { onLoadoutEdit("Equipment") } else { onEdit(.loadout) } }) {
                    GuideSummaryRow(title:"Total weight",value:String(format:"%.1f lb",GuideLoadoutSummary.weight(hero.items)))
                    GuideSummaryRow(title:"Attunement",value:"\(hero.items.filter { $0.requiresAttunement == true && $0.attuned == true }.count) attuned")
                    if hero.items.contains(where:{ $0.weight == 0 }) { Text("Weight uses recorded values; items with no weight entered count as zero.").font(.system(size:11)).foregroundStyle(.secondary) }
                    if hero.items.isEmpty { Text("No equipment selected. You can add it from Spells & gear or later.").font(.system(size:12)).foregroundStyle(.secondary) }
                    ForEach(shownItems) { item in HStack { GuideSummaryRow(title:item.name,value:"×\(item.quantity) · "+(item.equipped ? "Equipped":"Carried"));GuidePreviewButton(name:item.name) { GuideItemPreview(item:item) } } }
                    ForEach(before?.items.filter { old in !hero.items.contains { $0.id == old.id } } ?? []) { item in GuideSummaryRow(title:item.name,value:"Removed").foregroundStyle(coral) }
                }
            }.clipShape(RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(ink.opacity(0.09)))
            DisclosureGroup("Full change log · \(draft.changeSummary.count) entries") { ForEach(Array(draft.changeSummary.enumerated()),id:\.offset) { _,line in Text(line).font(.system(size:11)).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,3) } }.font(.system(size:11)).foregroundStyle(.secondary)
            if draft.isLevelUp { Text("Applying saves a pre-level-up backup and a Journal entry. Spent slots, hit dice, and existing play state stay preserved.").font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
        }
    }
    private func metric(_ title:String,old:String?,value:String,color:Color) -> some View {
        VStack(alignment:.leading,spacing:6) {
            Text(title).font(.system(size:10)).foregroundStyle(.secondary)
            HStack(spacing:5) { if let old,old != value { Text(old+" →").font(.system(size:12)).foregroundStyle(.secondary) };Text(value).font(.system(size:21,weight:.semibold,design:.rounded)).foregroundStyle(color) }.lineLimit(1).minimumScaleFactor(0.7)
        }.padding(11).frame(maxWidth:.infinity,alignment:.leading).background(color.opacity(0.06),in:RoundedRectangle(cornerRadius:8))
    }
}
private struct GuideReviewSection<Content:View>:View {
    var index:Int
    var title:String
    var summary:String
    var onEdit:()->Void
    @ViewBuilder var content:()->Content
    @State private var expanded:Bool
    init(index:Int,title:String,summary:String,expanded:Bool=false,onEdit:@escaping()->Void,@ViewBuilder content:@escaping()->Content) {
        self.index=index;self.title=title;self.summary=summary;self.onEdit=onEdit;self.content=content;_expanded=State(initialValue:expanded)
    }
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(spacing:12) {
                Button { withAnimation(.easeOut(duration:0.12)) { expanded.toggle() } } label: {
                    HStack(spacing:9) { Image(systemName:expanded ? "chevron.down":"chevron.right").font(.system(size:10));VStack(alignment:.leading,spacing:4) { Text(title).font(.system(size:13,weight:.medium));Text(summary).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(2) };Spacer(minLength:0) }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(expanded ? "Expanded":"Collapsed")
                Button(action:onEdit) { Image(systemName:"pencil") }.buttonStyle(.plain).foregroundStyle(accent).frame(width:28,height:28).help("Edit "+title.lowercased()).accessibilityLabel("Edit "+title.lowercased())
            }.padding(12)
            if expanded { VStack(alignment:.leading,spacing:10,content:content).padding(.horizontal,14).padding(.bottom,14) }
            if index < 5 { Divider().opacity(0.45) }
        }.background(index.isMultiple(of:2) ? surface:surface.opacity(0.4))
    }
}
private struct GuideSummaryRow:View {
    var title:String
    var previous:String? = nil
    var value:String
    var body:some View { HStack(alignment:.top,spacing:12) { Text(title).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading);if let previous { Text(previous+" →").foregroundStyle(.secondary) };Text(value).frame(maxWidth:.infinity,alignment:.trailing) }.font(.system(size:12)).fixedSize(horizontal:false,vertical:true) }
}
