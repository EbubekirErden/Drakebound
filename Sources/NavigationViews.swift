import SwiftUI

struct SpellPresentation {
    var heroID:UUID
    var spell:Spell
    var library = false
    var ids:[UUID]
}
struct CompendiumView:View {
    @ObservedObject var store:Store
    @FocusState private var searchFocused:Bool
    @State private var category = CompendiumCategory.spell
    @State private var query = ""
    @State private var matches:[CompendiumEntry] = []
    @State private var sourceEntries:[CompendiumEntry] = []
    @State private var sourceCounts:[CompendiumCategory:Int] = [:]
    @State private var sourceRevision = 0
    @State private var limit = 100
    @State private var selected:CompendiumEntry?
    @State private var browserWidth:CGFloat = 0
    @State private var expandedDetail = false
    @AppStorage("compendiumInspectorWidth") private var inspectorWidth:Double = 360
    private var fittedInspectorWidth:CGFloat { min(max(300,inspectorWidth),min(540,max(300,browserWidth-560))) }
    @State private var spellClass = "All classes"
    @AppStorage("compendiumInspectorEnabled") private var inspectorEnabled = false
    @AppStorage("compendiumSearchDescriptions") private var searchDescriptions = false
    private var canInspect:Bool { inspectorEnabled && browserWidth >= 950 }
    @State private var conditionsReference=false
    @State private var message = ""
    @State private var selectionMode = false
    @State private var picks:[CompendiumPick] = []
    @State private var creation:CompendiumCreation?
    @State private var subgroup = "All"
    @State private var school = "All schools"
    @State private var throughLevel = 1
    @AppStorage("compendiumSourceScope") private var sourceScope = CompendiumScope.all
    @AppStorage("compendiumIncludeUA") private var includeUA = false
    @AppStorage("compendiumIncludeHomebrew") private var includeHomebrew = false
    var subgroups:[String] { Array(Set(sourceEntries.filter { $0.category == category }.map(\.subcategory))).sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    var schools:[String] { Array(Set(sourceEntries.filter { $0.category == .spell }.map { FightClubImport.school($0.value("school")) }.filter { !$0.isEmpty })).sorted() }
    var extraSpells:[Spell] {
        let ids = Set(store.compendium.filter { $0.category == .spell }.map(\.id))
        return store.library.filter { [.all,.curated,.custom].contains(sourceScope) && !ids.contains($0.id) && (subgroup == "All" || ($0.level == 0 ? "Cantrips":"Level \($0.level)") == subgroup) && (school == "All schools" || $0.school == school) && (spellClass == "All classes" || ($0.classes ?? "").components(separatedBy:",").contains { CompendiumSearch.normalized($0) == CompendiumSearch.normalized(spellClass) }) && CompendiumSearch.matches(name:$0.name,summary:$0.school,classes:$0.classes ?? "",source:"Custom",description:$0.text,query:query,includeDescription:searchDescriptions) }
    }
    var body:some View {
        GeometryReader { viewport in
            HStack(spacing:0) {
                libraryContent.frame(maxWidth:.infinity,maxHeight:.infinity)
                if canInspect {
                    InspectorResizeHandle(width:$inspectorWidth,maximum:min(540,max(300,browserWidth-560)))
                    Group {
                        if let selected { referenceDetails(selected) }
                        else { ContentUnavailableView("Select a reference",systemImage:"sidebar.right",description:Text("Preview an entry here while keeping your search and filters visible.")) }
                    }.frame(width:fittedInspectorWidth).frame(maxHeight:.infinity).background(surface.opacity(0.5))
                }
            }
            .overlay {
                if let selected, !canInspect || expandedDetail {
                    DismissibleDetail(dismiss:{ if !canInspect { self.selected = nil }; expandedDetail = false; message = "" }) { referenceDetails(selected) }
                }
            }
            .coordinateSpace(name:"compendiumViewport")
            .onAppear { browserWidth = viewport.size.width }
            .onChange(of:viewport.size.width) { _,width in browserWidth = width }
        }
        .onReceive(store.$commandRequest) { request in if let request,request.action == .search && store.showCompendium && store.consume(request) { searchFocused = true } }
        .task(id:sourceScope.rawValue+String(includeUA)+String(includeHomebrew)+String(store.compendium.count)+String(store.compendiumRevision)) {
            let all = store.compendium; let scope = sourceScope; let ua = includeUA; let hb = includeHomebrew
            let scoped = await Task.detached { all.filter { scope.includes($0,ua:ua,homebrew:hb) } }.value
            guard !Task.isCancelled else { return }
            sourceEntries = scoped
            sourceCounts = Dictionary(grouping:scoped,by:\.category).mapValues(\.count)
            subgroup = "All"; school = "All schools"; spellClass = "All classes"; sourceRevision += 1
        }
        .task(id:category.rawValue+query+subgroup+school+spellClass+String(searchDescriptions)+String(sourceRevision)) {
            let all = sourceEntries; let type = category; let group = subgroup; let chosenSchool = school; let chosenClass = spellClass; let fullText = searchDescriptions; let search = query.trimmingCharacters(in:.whitespacesAndNewlines)
            let found = await Task.detached { all.filter { $0.category == type && (group == "All" || $0.subcategory == group) && (chosenSchool == "All schools" || FightClubImport.school($0.value("school")) == chosenSchool) && (chosenClass == "All classes" || CompendiumSearch.classNames($0).contains { CompendiumSearch.normalized($0) == CompendiumSearch.normalized(chosenClass) }) && CompendiumSearch.matches($0,query:search,includeDescription:fullText) }.sorted { CompendiumSearch.precedes($0,$1,query:search) } }.value
            guard !Task.isCancelled else { return }; matches = found; limit = 100
        }
        .sheet(isPresented:$conditionsReference) { ConditionsReference() }
        .sheet(item:$creation) { session in CompendiumCreator(session:session,classOptions:store.compendium.filter { $0.category == .classEntry }.map(\.name),hero:store.heroes.first(where:{ $0.id == store.selected }) ?? Hero(),save:{ store.upsertTemplate($0); selected = nil }) }
    }
    private var libraryContent:some View {
        VStack(alignment:.leading,spacing:14) {
            PageToolbar(title:"Compendium",subtitle:"\(store.compendium.count.formatted()) reference entries",searchTitle:"Search compendium…",query:$query,focus:$searchFocused) {
                Button { creation = CompendiumCreation(category:category) } label: { Label("New \(category.singular.lowercased())",systemImage:"plus") }.buttonStyle(PageButtonStyle(prominent:true))
                Button { if inspectorEnabled { selected = nil; message = "" }; inspectorEnabled.toggle(); expandedDetail = false } label: { Label("Preview",systemImage:"rectangle.split.2x1") }
                    .buttonStyle(PageButtonStyle(prominent:canInspect)).disabled(browserWidth < 950)
                    .help(browserWidth < 950 ? "Widen the window to preview beside results":"Show or hide preview beside results")
                    .accessibilityLabel("Preview beside results").accessibilityValue(inspectorEnabled ? "On":"Off")
                Button("Conditions",systemImage:"waveform.path.ecg") { conditionsReference=true }.buttonStyle(PageButtonStyle())
                Menu {
                    Button(selectionMode ? "Cancel selection":"Select multiple") { selectionMode.toggle(); if !selectionMode { picks = [] } }
                    Button("Import XML…") { store.importBackup() }.disabled(store.importingCompendium)
                    Divider()
                    Toggle("Search descriptions too",isOn:$searchDescriptions)
                    Button("Clear search and category filters") { clearCategoryFilters() }
                    Button("Clear all filters") { clearAllFilters() }
                } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .frame(width:34,height:34).background(surface,in:RoundedRectangle(cornerRadius:8)).help("Compendium options").accessibilityLabel("Compendium options")
            }
            ScrollView(.horizontal,showsIndicators:false) { HStack(spacing:6) {
                ForEach(CompendiumCategory.allCases,id:\.self) { type in
                    Button { category = type; limit = 100; subgroup = "All"; school = "All schools"; spellClass = "All classes" } label: { VStack(spacing:5) { Text(type.rawValue).font(.system(size:11,weight:.medium)); Text("\(type == .spell && store.compendium.isEmpty ? store.library.count:sourceCounts[type,default:0])").font(.system(size:9)).foregroundStyle(.secondary) }.frame(minWidth:86).padding(.horizontal,8).padding(.vertical,8).background((type == category ? accent:ink).opacity(type == category ? 0.13:0.025)).clipShape(RoundedRectangle(cornerRadius:8)) }.buttonStyle(.plain).accessibilityAddTraits(type == category ? .isSelected:[])
                }
            } }
            categoryFilters
            if selectionMode {
                HStack(spacing:10) {
                    Text("\(picks.count) selected").font(.caption).foregroundStyle(accent)
                    Button("Select shown") { for entry in matches.prefix(limit) where picks.count < 200 { choose(CompendiumPick(entry),selectOnly:true) }; if category == .spell { for spell in extraSpells where picks.count < 200 { choose(CompendiumPick(spell:spell),selectOnly:true) } } }.font(.caption)
                    Button("Clear") { picks = [] }.font(.caption).disabled(picks.isEmpty)
                    Spacer()
                    Button("Add selected…") { store.compendiumAdd = CompendiumAddRequest(picks:picks) }.buttonStyle(PageButtonStyle(prominent:true)).disabled(picks.isEmpty)
                }
            }
            if store.compendium.isEmpty && category == .spell {
                ScrollView { customSpells }
            } else if matches.isEmpty && (category != .spell || extraSpells.isEmpty) { CenteredEmptyState("No matching entries",systemImage:"books.vertical",description:Text(store.compendium.isEmpty ? "Import a Fight Club compendium to browse this category.":"Try a different search or remove a filter above.")) }
            else {
                ScrollView {
                    if category == .spell && !extraSpells.isEmpty { Text("Custom & starter spells").font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading); customSpells.padding(.bottom,16); if !matches.isEmpty { Text("Imported references").font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading) } }
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:280),spacing:10)],spacing:10) {
                        ForEach(matches.prefix(limit)) { entry in
                            Button { if selectionMode { choose(CompendiumPick(entry)) } else { open(entry) } } label: { HStack(spacing:6) { if selectionMode { Image(systemName:picks.contains { $0.id == entry.id } ? "checkmark.circle.fill":"circle").foregroundStyle(accent) }; entryLabel(entry.name,entry.summary,source:entry.sourceMark.rawValue).help(entry.sourceDescription) } }.buttonStyle(.plain)
                        }
                    }
                    if matches.count > limit { Button("Show next \(min(100,matches.count-limit)) entries") { limit += 100 }.padding() }
                }.id(category.rawValue+query)
            }
        }.padding(22).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
    }
    private var classChoices:[String] {
        Array(Set(sourceEntries.filter { $0.category == .spell }.flatMap(CompendiumSearch.classNames) + store.library.flatMap { ($0.classes ?? "").components(separatedBy:",").map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }.filter { !$0.isEmpty } })).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    private var hasActiveFilters:Bool { !query.isEmpty || subgroup != "All" || school != "All schools" || spellClass != "All classes" || sourceScope != .all || includeUA || includeHomebrew }
    private func clearAllFilters() { sourceScope = .all; includeUA = false; includeHomebrew = false; clearCategoryFilters() }
    private func clearCategoryFilters() { query = ""; subgroup = "All"; school = "All schools"; spellClass = "All classes" }
    var categoryFilters:some View {
        VStack(alignment:.leading,spacing:8) {
            ControlFlowLayout {
                    PagePicker(title:"Sources",selectionTitle:sourceScope.rawValue,selection:$sourceScope) {
                        ForEach(CompendiumScope.allCases,id:\.self) { Text($0.rawValue).tag($0) }
                    }.frame(width:160)
                    if subgroups.count > 1 {
                        PagePicker(title:category == .spell ? "Level":category == .item ? "Type":"Category",selectionTitle:subgroup == "All" ? (category == .spell ? "All levels":"All types"):subgroup,selection:$subgroup) {
                            Text("All").tag("All"); ForEach(subgroups,id:\.self) { Text($0).tag($0) }
                        }.frame(width:110)
                    }
                    if category == .spell {
                        PagePicker(title:"School",selectionTitle:school,selection:$school) { Text("All schools").tag("All schools"); ForEach(schools,id:\.self) { Text($0).tag($0) } }.frame(width:150)
                        PagePicker(title:"Class list",selectionTitle:spellClass,selection:$spellClass) { Text("All classes").tag("All classes"); ForEach(classChoices,id:\.self) { Text($0).tag($0) } }.frame(width:140)
                    }

            }
            ControlFlowLayout {
                if sourceScope == .curated { Toggle("Include UA",isOn:$includeUA).toggleStyle(.checkbox); Toggle("Include homebrew",isOn:$includeHomebrew).toggleStyle(.checkbox) }
                Text("\((matches.count+(category == .spell ? extraSpells.count:0)).formatted()) results"+(matches.count > limit ? " · \(limit) imported shown":"")+(searchDescriptions ? " · includes descriptions":"")).foregroundStyle(.secondary)
                Button("Clear all filters") { clearAllFilters() }.buttonStyle(.plain).foregroundStyle(accent).disabled(!hasActiveFilters)
            }.font(.system(size:11))
            if hasActiveFilters {
                ControlFlowLayout(spacing:6) {
                    if !query.isEmpty { ActiveFilterChip(title:"Search: "+query) { query="" } }
                    if sourceScope != .all { ActiveFilterChip(title:sourceScope.rawValue) { sourceScope = .all } }
                    if subgroup != "All" { ActiveFilterChip(title:subgroup) { subgroup="All" } }
                    if school != "All schools" { ActiveFilterChip(title:school) { school="All schools" } }
                    if spellClass != "All classes" { ActiveFilterChip(title:spellClass) { spellClass="All classes" } }
                    if sourceScope == .curated && includeUA { ActiveFilterChip(title:"Include UA") { includeUA=false } }
                    if sourceScope == .curated && includeHomebrew { ActiveFilterChip(title:"Include homebrew") { includeHomebrew=false } }
                }
            }
        }
    }
    var customSpells:some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:280))],spacing:10) {
            ForEach(extraSpells) { spell in Button { if selectionMode { choose(CompendiumPick(spell:spell)) } else { var entry=TemplateFactory.spell(spell);entry.id=spell.id;open(entry) } } label: { HStack(spacing:6) { if selectionMode { Image(systemName:picks.contains { $0.id == spell.id } ? "checkmark.circle.fill":"circle").foregroundStyle(accent) }; entryLabel(spell.name,"\(spell.level == 0 ? "Cantrip":"Level \(spell.level)") · \(spell.school)") } }.buttonStyle(.plain).accessibilityLabel("Preview "+spell.name) }
        }
    }
    func entryLabel(_ name:String,_ subtitle:String,source:String? = nil) -> some View {
        HStack(spacing:10) { Image(systemName:category == .monster ? "pawprint":category == .spell ? "sparkles":category == .item ? "backpack":"book.closed").foregroundStyle(category == .item ? gold:sky); VStack(alignment:.leading,spacing:6) { Text(name).font(.system(size:13,weight:.medium)).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading); Text(subtitle.isEmpty ? "Reference":subtitle).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(2) }; if let source { Text(source).font(.system(size:8,weight:.semibold)).foregroundStyle(gold).padding(.horizontal,5).padding(.vertical,4).background(gold.opacity(0.08)).clipShape(Capsule()) }; if !selectionMode { Image(systemName:"chevron.right").font(.system(size:9)).foregroundStyle(.secondary) } }.padding(13).frame(maxWidth:.infinity,minHeight:72,alignment:.leading).background(surface).clipShape(RoundedRectangle(cornerRadius:9))
    }
    func open(_ entry:CompendiumEntry) {
        if canInspect { selected = entry; expandedDetail = false; message = ""; throughLevel = min(20,max(1,store.heroes.first(where:{ $0.id == store.selected })?.level ?? 1)) }
        else { openExpanded(entry) }
    }
    func openExpanded(_ entry:CompendiumEntry) {
        if entry.category == .spell, let spell = store.library.first(where:{ $0.id == entry.id }), let hero = store.heroes.first(where:{ $0.id == store.selected }) {
            expandedDetail = false
            let known = Set(store.library.map(\.id)); let ids=matches.filter { known.contains($0.id) }.map(\.id)+extraSpells.map(\.id); store.openSpell(spell,hero:hero,library:true,ids:ids)
        } else { expandedDetail = true; selected = entry; message = ""; throughLevel = min(20,max(1,store.heroes.first(where:{ $0.id == store.selected })?.level ?? 1)) }
    }
    func referenceDetails(_ entry:CompendiumEntry) -> some View {
        return VStack(alignment:.leading,spacing:16) {
            HStack(alignment:.top,spacing:12) {
                Text(entry.name).font(.system(size:20,weight:.semibold)).lineLimit(3).frame(maxWidth:.infinity,alignment:.leading)
                Button { if !expandedDetail || !canInspect { selected = nil }; expandedDetail = false; message = "" } label: { Image(systemName:"xmark") }.buttonStyle(PageButtonStyle()).help("Close details").accessibilityLabel("Close details")
            }
            Text(entry.category.rawValue+" · "+entry.summary).font(.caption).foregroundStyle(sky)
            HStack(spacing:8) {
                Button(entry.custom == true ? "Edit":"Edit copy") { creation = CompendiumCreation(category:entry.category,original:entry) }.buttonStyle(PageButtonStyle())
                Spacer(minLength:0)
                if canInspect && !expandedDetail {
                    Button { openExpanded(entry) } label: { Label("Larger view",systemImage:"arrow.up.left.and.arrow.down.right") }.buttonStyle(PageButtonStyle()).help("Open larger details").accessibilityLabel("Open larger details")
                } else {
                    Button { inspectorEnabled = true; expandedDetail = false } label: { Label("Beside results",systemImage:"rectangle.split.2x1") }.buttonStyle(PageButtonStyle()).disabled(browserWidth < 950).help(browserWidth < 950 ? "Widen the window to preview beside results":"Dock this preview beside the compendium results").accessibilityLabel("Preview beside results")
                }
            }
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    ReferenceBody(entry:entry)
                    DisclosureGroup("Sources") {
                        Text(entry.sourceDescription).font(.system(size:11)).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal:false,vertical:true).padding(.top,6)
                    }.font(.caption).foregroundStyle(.secondary)
                }.padding(.trailing,4)
            }.frame(maxHeight:.infinity)
            Divider()
            if entry.category == .classEntry { VStack(alignment:.leading,spacing:6) { Stepper("Features through level \(throughLevel)",value:$throughLevel,in:1...20); Text("\(entry.featureCopies(through:throughLevel).count) separate entries").font(.caption).foregroundStyle(.secondary) } }
            HStack { Spacer(); Button("Add to character…") { add(entry) }.buttonStyle(PageButtonStyle(prominent:true)).disabled(store.heroes.isEmpty) }
            if !message.isEmpty { Text(message).font(.caption).foregroundStyle(accent) }
        }.padding(22).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
    }
    func choose(_ pick:CompendiumPick,selectOnly:Bool = false) {
        if picks.contains(where:{ $0.id == pick.id }) { if !selectOnly { picks.removeAll { $0.id == pick.id } } }
        else if picks.count < 200 { picks.append(pick) }
    }
    func add(_ entry:CompendiumEntry) {
        store.compendiumAdd = CompendiumAddRequest(picks:[CompendiumPick(entry)],throughLevel:entry.category == .classEntry ? throughLevel:nil)
    }
}
