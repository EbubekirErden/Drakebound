import SwiftUI

struct GuideReferencePicker:View {
    var title:String
    var options:[CompendiumEntry]
    @Binding var selection:UUID?
    var onPreview:(CompendiumEntry)->Void
    var edition:String? = nil
    @State private var browsing = false
    @State private var query = ""
    @State private var equipmentType = "All types"
    @State private var equipmentSource = CompendiumScope.all
    var selected:CompendiumEntry? { options.first { $0.id == selection } }
    var matches:[CompendiumEntry] { options.filter { CompendiumSearch.matches($0,query:query) && ($0.category != .item || ((equipmentType == "All types" || $0.subcategory == equipmentType) && equipmentSource.includes($0))) } }
    func summary(_ entry:CompendiumEntry) -> String {
        if edition == "2024" && entry.category == .race {
            return (entry.value("speed").isEmpty ? "":entry.value("speed")+" ft · ")+"Ability increases from background"
        }
        return entry.summary
    }
    var body:some View {
        HStack(spacing:8) {
            Button { browsing = true } label: { HStack { Image(systemName:"books.vertical").foregroundStyle(sky); Text(selected?.name ?? "Browse \(title.lowercased())").lineLimit(1); Spacer(minLength:4); Image(systemName:"chevron.down").font(.system(size:9)) }.font(.system(size:12)).padding(.horizontal,10).frame(height:PageControl.height).background(surface).clipShape(RoundedRectangle(cornerRadius:6)).overlay(RoundedRectangle(cornerRadius:6).stroke(ink.opacity(0.1))) }.buttonStyle(.plain).disabled(options.isEmpty)
            if let selected { Button { onPreview(selected) } label: { Image(systemName:"eye") }.buttonStyle(PageButtonStyle()).help("Preview \(selected.name)"); Button { selection = nil } label: { Image(systemName:"xmark") }.buttonStyle(PageButtonStyle()).help("Clear \(title.lowercased()) reference") }
        }
        .popover(isPresented:$browsing) {
            VStack(alignment:.leading,spacing:12) {
                HStack { Text(title).font(.headline); Spacer(); Button("Done") { browsing = false } }
                PageSearchField(title:"Search \(title.lowercased())",query:$query)
                if options.first?.category == .item {
                    HStack(spacing:10) { PagePicker(title:"Type",selectionTitle:equipmentType,selection:$equipmentType) { Text("All types").tag("All types");ForEach(Array(Set(options.map(\.subcategory))).sorted(),id:\.self) { Text($0).tag($0) } }; PagePicker(title:"Source",selectionTitle:equipmentSource.rawValue,selection:$equipmentSource) { ForEach(CompendiumScope.allCases,id:\.self) { Text($0.rawValue).tag($0) } } }.font(.caption)
                }
                GeometryReader { geometry in ScrollView { LazyVStack(spacing:4) {
                    ForEach(matches.prefix(80)) { entry in
                        HStack(spacing:6) { Button { selection = entry.id; browsing = false } label: { VStack(alignment:.leading,spacing:4) { Text(entry.name).font(.system(size:12,weight:.medium)); Text(summary(entry)).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1) }.frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,9).frame(height:56).background(selection == entry.id ? accent.opacity(0.12):surface).clipShape(RoundedRectangle(cornerRadius:6)) }.buttonStyle(.plain); Button { browsing = false; onPreview(entry) } label: { Image(systemName:"eye").frame(width:36,height:56).background(surface).clipShape(RoundedRectangle(cornerRadius:6)) }.buttonStyle(.plain).accessibilityLabel("Preview "+entry.name).help("Preview \(entry.name)") }
                    }
                    if matches.isEmpty { CenteredEmptyState("No matching entries",systemImage:"magnifyingglass",description:Text("Try another search or filter.")).frame(width:geometry.size.width,height:geometry.size.height) }
                    if matches.count > 80 { Text("\(matches.count) matches · narrow your search").font(.caption).foregroundStyle(.secondary) }
                } } }
            }.padding(16).frame(width:400,height:410).background(paper).foregroundStyle(ink).tint(accent)
        }
    }
}
struct GuideReferencePreview:View {
    var entry:CompendiumEntry
    @Environment(\.dismiss) var dismiss
    var body:some View { VStack(alignment:.leading,spacing:14) { HStack { Text(entry.name).font(.title2.bold()); Spacer(); Button("Done") { dismiss() } }; Text(entry.summary).font(.caption).foregroundStyle(sky); ScrollView { ReferenceBody(entry:entry) } }.padding(22).frame(width:660,height:580).background(surface).foregroundStyle(ink) }
}
struct GuideSpellBrowser:View {
    var catalog:GuideCatalog
    var className:String
    var alreadyKnown:[Spell]
    var hero:Hero
    var onAdd:(Spell)->Void
    var buildDraft:CharacterBuildDraft? = nil
    var onSlots:(([Int])->Void)? = nil
    var onCustom:(()->Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    @State private var level = 0
    @State private var onlyLevel = false
    @State private var classOnly = true
    @State private var featuresOpen = false
    @State private var casterOpen = false
    @State private var casterLevel = 1
    @State private var preview:Spell?
    @State private var levelReview:CompendiumEntry?
    var baseClass:String { ClassProfile.named(className)?.name ?? className }
    var spellOptions:[Spell] {
        let revised=Set(catalog.spells.filter { $0.name.contains("[2024]") }.map { GuideRules.spellNameKey($0.name) })
        let legacy=Set(catalog.spells.filter { !$0.name.contains("[2024]") }.map { GuideRules.spellNameKey($0.name) })
        return catalog.spells.filter { spell in hero.edition == "2024" ? spell.name.contains("[2024]") || !revised.contains(GuideRules.spellNameKey(spell.name)):!spell.name.contains("[2024]") || !legacy.contains(GuideRules.spellNameKey(spell.name)) }
    }
    var matches:[Spell] { spellOptions.filter { spell in
        (!onlyLevel || spell.level == level) && CompendiumSearch.matches(name:spell.name,summary:spell.school,classes:spell.classes ?? "",source:"",query:search) && (!classOnly || GuideRules.spellBelongs(spell,to:baseClass))
    } }
    var referenceMatches:[CompendiumEntry] { catalog.unleveledSpells.filter { entry in (search.isEmpty || entry.name.localizedCaseInsensitiveContains(search)) && (!classOnly || entry.value("classes").localizedCaseInsensitiveContains(baseClass)) } }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            PageToolbar(title:"Choose spells",subtitle:"Adding to \(className)",color:sky,searchTitle:"Search spells…",query:$search) {
                GuideActionMenu(title:"Spell browser options") {
                    if let onCustom { Button("Custom spell…") { dismiss();onCustom() } }
                    Button("Features & traits") { featuresOpen=true }
                    if buildDraft != nil { Button("Caster table…") { casterLevel=min(20,buildDraft!.resultingClasses.reduce(0) { $0+$1.casting.contribution($1.level,edition:hero.edition) });casterOpen=true } }
                }
                Button("Done") { dismiss() }.buttonStyle(PageButtonStyle())
            }
            ScrollViewReader { scroll in
                HStack(spacing:12) {
                    PagePicker(title:"Level",selectionTitle:level == -1 ? "Needs review":level == 0 ? "Cantrips":"Level \(level)",selection:$level) { Text("Cantrips").tag(0); ForEach(1...9,id:\.self) { Text("Level \($0)").tag($0) }; Text("Needs review").tag(-1) }.frame(width:140)
                    Toggle("Only this level",isOn:$onlyLevel).font(.caption).disabled(level == -1)
                    Toggle("Class list",isOn:$classOnly).font(.caption).help("Only \(baseClass) spells")
                }
                .onChange(of:level) { _,value in if value >= 0 { withAnimation(.easeInOut(duration:0.2)) { scroll.scrollTo(value,anchor:.top) } } }
                Text("Scroll through spell levels, or jump with the level menu. Class levels determine which spells you can learn; multiclass slot levels do not.").font(.caption2).foregroundStyle(.secondary)
                if !catalog.unleveledSpells.isEmpty { Button(level == -1 ? "Showing XML entries without a level":"Missing cantrips? Review entries without an XML level…") { level = -1 }.font(.caption).buttonStyle(.plain).foregroundStyle(sky) }
                GeometryReader { geometry in ScrollView { LazyVStack(alignment:.leading,spacing:6,pinnedViews:[.sectionHeaders]) {
                    if level == -1 {
                        Text("These references omit their level. Preview and confirm that each is a spell before adding it.").font(.caption).foregroundStyle(gold)
                        ForEach(referenceMatches.prefix(120)) { entry in HStack { Text(entry.name).font(.system(size:12)).frame(maxWidth:.infinity,alignment:.leading); Button("Review level…") { levelReview = entry }.accessibilityLabel("Review level for \(entry.name)").disabled(alreadyKnown.contains { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame }) }.padding(10).background(paper).clipShape(RoundedRectangle(cornerRadius:7)) }
                        if referenceMatches.isEmpty { Text("No matching references").font(.caption).foregroundStyle(.secondary) }
                        if referenceMatches.count > 120 { Text("\(referenceMatches.count) matches · search to narrow the list").font(.caption2).foregroundStyle(.secondary) }
                    } else {
                        ForEach(0...9,id:\.self) { tier in
                            let spells = matches.filter { $0.level == tier }
                            if !spells.isEmpty { Section {
                                ForEach(spells) { spell in spellRow(spell) }
                            } header: {
                                HStack { Text(tier == 0 ? "CANTRIPS":"LEVEL \(tier)"); Spacer(); Text("\(spells.count)") }.font(.system(size:10,weight:.semibold)).foregroundStyle(sky).padding(.vertical,9).background(surface).id(tier)
                            } }
                        }
                        if matches.isEmpty { CenteredEmptyState("No matching spells",systemImage:"sparkles",description:Text("Try another level, search, or turn off the class filter.")).frame(width:geometry.size.width,height:geometry.size.height) }
                    }
                } } }
            }
        }.padding(20).frame(width:660,height:580).background(surface).foregroundStyle(ink).tint(sky)
        .popover(isPresented:$casterOpen) { if let buildDraft { CasterTableView(draft:buildDraft,catalog:catalog,level:$casterLevel) { slots in onSlots?(slots);casterOpen=false } } }
        .popover(isPresented:$featuresOpen) { LoadoutFeatureReference(features:hero.featureEntries ?? []) }
        .sheet(item:$preview) { spell in VStack(alignment:.leading,spacing:14) { HStack { Text(spell.name).font(.title2.bold()); Spacer(); Button("Done") { preview = nil } }; Text("\(spell.school) · \(spell.range) · \(spell.duration)").font(.caption).foregroundStyle(sky); ScrollView { Text(DescriptionMarkdown.attributed(spell.text)).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) } }.padding(22).frame(width:600,height:520).background(surface) }
        .sheet(item:$levelReview) { entry in GuideSpellLevelReview(entry:entry,hero:hero,onAdd:onAdd) }
    }
    func spellRow(_ spell:Spell) -> some View {
        let known = alreadyKnown.contains { GuideRules.spellNameKey($0.name) == GuideRules.spellNameKey(spell.name) }
        return HStack {
            Button { preview = spell } label: { VStack(alignment:.leading,spacing:4) { Text(spell.name).font(.system(size:12,weight:.medium)); Text("\(spell.school) · \(spell.time) · \(spell.range)").font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1) }.frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain)
            Button(known ? "Added":"Add") { onAdd(spell) }.accessibilityLabel("\(known ? "Added":"Add") \(spell.name)").disabled(known)
        }.padding(10).background(paper).clipShape(RoundedRectangle(cornerRadius:7))
    }
}
struct GuideSpellLevelReview:View {
    var entry:CompendiumEntry
    var hero:Hero
    var onAdd:(Spell)->Void
    @State private var level = -1
    @Environment(\.dismiss) var dismiss
    var body:some View { VStack(alignment:.leading,spacing:14) {
        HStack { Text(entry.name).font(.title2.bold()); Spacer(); Button("Cancel") { dismiss() } }
        Text("This XML entry has no spell level. Confirm that it is a spell and select its level from your rules.").font(.caption).foregroundStyle(gold)
        Picker("Confirmed level",selection:$level) { Text("Choose a level…").tag(-1); Text("Cantrip").tag(0); ForEach(1...9,id:\.self) { Text("Level \($0)").tag($0) } }
        ScrollView { ReferenceBody(entry:entry) }
        HStack { Spacer(); Button(level == 0 ? "Add cantrip":"Add spell") { if let spell = try? GuideRules.reviewedSpell(entry,level:level,hero:hero) { onAdd(spell); dismiss() } }.buttonStyle(.borderedProminent).disabled(level < 0) }
    }.padding(22).frame(width:640,height:580).background(surface).foregroundStyle(ink) }
}

struct GuidePreview:View {
    var draft:CharacterBuildDraft
    var expanded = false
    @ViewBuilder var body:some View { if draft.isLevelUp && !expanded { GuideLevelPreview(draft:draft) } else { fullBody } }
    @ViewBuilder var fullBody:some View {
        let hero = draft.result
        VStack(alignment:.leading,spacing:14) {
            ZStack(alignment:.bottomLeading) { Rectangle().fill(surface.gradient); CroppedImage(data:hero.portrait,crop:hero.bannerCrop ?? BannerCrop()); LinearGradient(colors:[.clear,.black.opacity(0.8)],startPoint:.top,endPoint:.bottom); VStack(alignment:.leading,spacing:5) { Text(hero.name.isEmpty ? "Your adventurer":hero.name).font(.system(size:expanded ? 24:18,weight:.semibold)); Text("Level \(hero.level) · \(hero.edition)").font(.caption).foregroundStyle(sky) }.padding(14) }.frame(height:expanded ? 140:105).clipShape(RoundedRectangle(cornerRadius:9))
            Text(hero.characterClass).font(.system(size:12,weight:.medium)); Text([hero.ancestry,hero.background].filter { !$0.isEmpty }.joined(separator:" · ")).font(.caption).foregroundStyle(.secondary)
            ForEach(hero.progressionClasses.filter { !$0.subclass.isEmpty }) { record in Text(record.subclass).font(.caption2).foregroundStyle(accent) }
            HStack { metric("HP","\(hero.maximumHP)",leaf); metric("AC","\(hero.armorClass)",sky); metric("PROF",signed(hero.proficiency),gold) }
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:3),spacing:6) { ForEach(0..<6,id:\.self) { i in VStack(spacing:4) { Text(String(abilities[i].prefix(3)).uppercased()).font(.system(size:9)).foregroundStyle(.secondary); Text("\(hero.effectiveScore(i))").font(.system(size:18,weight:.medium,design:.rounded)); Text(signed(hero.modifier(i))).font(.system(size:10)).foregroundStyle(sky) }.frame(maxWidth:.infinity).padding(8).background(surface).clipShape(RoundedRectangle(cornerRadius:6)) } }
            HStack { Text("Speed"); Spacer(); Text("\(hero.movement) ft") }.font(.caption)
            HStack { Text("Hit dice"); Spacer(); Text((hero.hitDicePools ?? []).map { "\($0.total)d\($0.sides)" }.joined(separator:" + ")) }.font(.caption)
            Divider()
            Text("SPELLCASTING").font(.system(size:9,weight:.semibold)).foregroundStyle(sky)
            HStack { Text("DC \(hero.spellDC)"); Spacer(); Text("Attack \(signed(hero.spellAttack))") }.font(.caption)
            Text(hero.slots.enumerated().filter { $0.element > 0 }.map { "L\($0.offset+1): \($0.element)" }.joined(separator:"  ·  ").isEmpty ? "No spell slots":hero.slots.enumerated().filter { $0.element > 0 }.map { "L\($0.offset+1): \($0.element)" }.joined(separator:"  ·  ")).font(.caption2).foregroundStyle(.secondary)
            Text("\(hero.spells.count) spells · \(hero.items.count) items · \((hero.featureEntries ?? []).count) features").font(.caption).foregroundStyle(.secondary)
            if draft.isLevelUp || expanded { Divider(); Text("CHANGES").font(.system(size:9,weight:.semibold)).foregroundStyle(accent); ForEach(Array(draft.changeSummary.enumerated()),id:\.offset) { _,line in Text(line).font(.system(size:11)).frame(maxWidth:.infinity,alignment:.leading) } }
            if expanded {
                Divider(); Text("TRAINING").font(.caption.bold()); Text(hero.skillRanks.filter { $0.value > 0 }.sorted { $0.key < $1.key }.map { "\($0.key)\($0.value == 2 ? " (expertise)":"")" }.joined(separator:", ")).font(.caption)
                Text("FEATURES").font(.caption.bold()); ForEach(hero.featureEntries ?? []) { feature in DisclosureGroup(feature.name) { Text(DescriptionMarkdown.attributed(feature.text)).font(.caption).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,6) } }
                Text("SPELLS").font(.caption.bold()); ForEach(hero.spells) { spell in Text("\(spell.name) · \(spell.prepared ? "Prepared":"Unprepared")").font(.caption) }
                Text("EQUIPMENT").font(.caption.bold()); ForEach(hero.items) { item in Text("\(item.name) ×\(item.quantity)\(item.equipped ? " · Equipped":"")").font(.caption) }
            }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    func metric(_ title:String,_ value:String,_ color:Color) -> some View { VStack(spacing:5) { Text(title).font(.system(size:9,weight:.semibold)).foregroundStyle(.secondary); Text(value).font(.system(size:22,weight:.semibold,design:.rounded)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.5) }.frame(maxWidth:.infinity).padding(.vertical,10).background(color.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius:7)) }
}
