import SwiftUI

struct SpellPresentation {
    var heroID:UUID
    var spell:Spell
    var library = false
    var ids:[UUID]
}
struct DismissibleDetail<Content:View>:View {
    var dismiss:()->Void
    @ViewBuilder var content:()->Content
    // Content never determines the panel size. Only the viewport or an explicit resize does.
    @State private var requestedSize = CGSize(width:660,height:580)
    @State private var resizeStart:CGSize?
    var body:some View {
        GeometryReader { viewport in
            let size = fitted(requestedSize,in:viewport.size)
            ZStack {
                Button(action:dismiss) { Color.black.opacity(0.48).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel("Close details")
                content().frame(width:size.width,height:size.height)
                    .background(surface).clipShape(RoundedRectangle(cornerRadius:14))
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(ink.opacity(0.12)))
                    .contentShape(Rectangle()).onTapGesture { }
                    .overlay(alignment:.bottomTrailing) {
                        Button { requestedSize = CGSize(width:660,height:580) } label: {
                            Image(systemName:"arrow.up.left.and.arrow.down.right").font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary)
                                .frame(width:24,height:24).background(paper.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius:5)).contentShape(Rectangle())
                        }.buttonStyle(.plain).padding(3)
                            .help("Drag to resize details · click to reset")
                            .accessibilityLabel("Resize details")
                            .accessibilityAdjustableAction { direction in
                                let change:CGFloat = direction == .increment ? 40:-40
                                requestedSize = fitted(CGSize(width:size.width+change,height:size.height+change),in:viewport.size)
                            }
                            .simultaneousGesture(DragGesture(minimumDistance:2,coordinateSpace:.named("detailViewport")).onChanged { value in
                                if resizeStart == nil { resizeStart = size }
                                let start = resizeStart ?? size
                                requestedSize = fitted(CGSize(width:start.width+value.translation.width*2,height:start.height+value.translation.height*2),in:viewport.size)
                            }.onEnded { _ in resizeStart = nil })
                    }
                    .shadow(color:.black.opacity(0.5),radius:28,y:10)
            }.frame(width:viewport.size.width,height:viewport.size.height)
                .coordinateSpace(name:"detailViewport")
        }.onExitCommand(perform:dismiss)
    }
    private func fitted(_ requested:CGSize,in viewport:CGSize) -> CGSize {
        let maximum = CGSize(width:max(1,viewport.width-32),height:max(1,viewport.height-32))
        return CGSize(width:min(maximum.width,max(540,requested.width)),height:min(maximum.height,max(440,requested.height)))
    }
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
        return store.library.filter { [.all,.curated,.custom].contains(sourceScope) && !ids.contains($0.id) && (subgroup == "All" || ($0.level == 0 ? "Cantrips":"Level \($0.level)") == subgroup) && (school == "All schools" || $0.school == school) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
    }
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                VStack(alignment:.leading,spacing:5) { Text("Compendium").font(.system(size:26,weight:.semibold)); Text("Your local reference library · \(store.compendium.count.formatted()) imported entries").font(.caption).foregroundStyle(.secondary) }
                Spacer(); Button(selectionMode ? "Cancel selection":"Select multiple") { selectionMode.toggle(); if !selectionMode { picks = [] } }; Button("New \(category.singular.lowercased())") { creation = CompendiumCreation(category:category) }; Button("Import XML") { store.importBackup() }.disabled(store.importingCompendium)
            }
            sourceControls
            HStack(spacing:6) {
                ForEach(CompendiumCategory.allCases,id:\.self) { type in
                    Button { category = type; limit = 100; subgroup = "All"; school = "All schools" } label: { VStack(spacing:5) { Text(type.rawValue).font(.system(size:11,weight:.medium)); Text("\(type == .spell && store.compendium.isEmpty ? store.library.count:sourceCounts[type,default:0])").font(.system(size:9)).foregroundStyle(.secondary) }.frame(maxWidth:.infinity).padding(.vertical,10).background((type == category ? accent:ink).opacity(type == category ? 0.13:0.025)).clipShape(RoundedRectangle(cornerRadius:8)) }.buttonStyle(.plain)
                }
            }
            categoryFilters
            if selectionMode {
                HStack(spacing:10) {
                    Text("\(picks.count) selected").font(.caption).foregroundStyle(accent)
                    Button("Select shown") { for entry in matches.prefix(limit) where picks.count < 200 { choose(CompendiumPick(entry),selectOnly:true) }; if category == .spell { for spell in extraSpells where picks.count < 200 { choose(CompendiumPick(spell:spell),selectOnly:true) } } }.font(.caption)
                    Button("Clear") { picks = [] }.font(.caption).disabled(picks.isEmpty)
                    Spacer()
                    Button("Add selected…") { store.compendiumAdd = CompendiumAddRequest(picks:picks) }.buttonStyle(.borderedProminent).disabled(picks.isEmpty)
                }
            }
            if store.compendium.isEmpty && category == .spell {
                ScrollView { customSpells }
            } else if matches.isEmpty && (category != .spell || extraSpells.isEmpty) { CenteredEmptyState("No matching entries",systemImage:"books.vertical",description:Text(store.compendium.isEmpty ? "Import a Fight Club compendium to browse this category.":"Try a different name or category.")) }
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
        .onReceive(store.$commandRequest) { request in if let request,request.action == .search && store.showCompendium && store.consume(request) { searchFocused = true } }
        .task(id:sourceScope.rawValue+String(includeUA)+String(includeHomebrew)+String(store.compendium.count)+String(store.compendiumRevision)) {
            let all = store.compendium; let scope = sourceScope; let ua = includeUA; let hb = includeHomebrew
            let scoped = await Task.detached { all.filter { scope.includes($0,ua:ua,homebrew:hb) } }.value
            guard !Task.isCancelled else { return }
            sourceEntries = scoped
            sourceCounts = Dictionary(grouping:scoped,by:\.category).mapValues(\.count)
            subgroup = "All"; school = "All schools"; sourceRevision += 1
        }
        .task(id:category.rawValue+query+subgroup+school+String(sourceRevision)) {
            let all = sourceEntries; let type = category; let group = subgroup; let chosenSchool = school; let search = query.trimmingCharacters(in:.whitespacesAndNewlines)
            let found = await Task.detached { all.filter { $0.category == type && (group == "All" || $0.subcategory == group) && (chosenSchool == "All schools" || FightClubImport.school($0.value("school")) == chosenSchool) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.summary.localizedCaseInsensitiveContains(search)) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }.value
            guard !Task.isCancelled else { return }; matches = found; limit = 100
        }
        .overlay { if let selected { DismissibleDetail(dismiss:{ self.selected = nil; message = "" }) { referenceDetails(selected) } } }
        .sheet(item:$creation) { session in CompendiumCreator(session:session,classOptions:store.compendium.filter { $0.category == .classEntry }.map(\.name),hero:store.heroes.first(where:{ $0.id == store.selected }) ?? Hero(),save:{ store.upsertTemplate($0); selected = nil }) }
    }
    var sourceControls:some View {
        HStack(spacing:12) {
            Picker("Sources",selection:$sourceScope) { ForEach(CompendiumScope.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.frame(width:245).help("Applies to every compendium category and its count. Filters hide records without deleting them; unmarked records have no explicit edition marker. Custom additions remain in the 2024 view.")
            if sourceScope == .curated { Toggle("Include UA",isOn:$includeUA); Toggle("Include homebrew",isOn:$includeHomebrew) }
            Spacer(minLength:0)
            if sourceScope != .all { Button("All sources") { sourceScope = .all }.font(.caption) }
        }.font(.system(size:11))
    }
    var categoryFilters:some View {
        HStack(spacing:12) {
            HStack(spacing:8) { Image(systemName:"magnifyingglass").foregroundStyle(.secondary); TextField("Search \(category.rawValue.lowercased())",text:$query).focused($searchFocused).textFieldStyle(.plain); Text("\(matches.count.formatted()) results").font(.caption2).foregroundStyle(.secondary).fixedSize() }.padding(.horizontal,10).frame(minWidth:160,maxWidth:.infinity).frame(height:PageControl.height).background(surface).clipShape(RoundedRectangle(cornerRadius:8))
            if subgroups.count > 1 { PagePicker(title:category == .spell ? "Level":category == .item ? "Type":"Category",selectionTitle:subgroup,selection:$subgroup) { Text("All").tag("All"); ForEach(subgroups,id:\.self) { Text($0).tag($0) } }.frame(width:150) }
            if category == .spell { PagePicker(title:"School",selectionTitle:school,selection:$school) { Text("All schools").tag("All schools"); ForEach(schools,id:\.self) { Text($0).tag($0) } }.frame(width:190) }
            if !query.isEmpty || subgroup != "All" || school != "All schools" { Button { query = ""; subgroup = "All"; school = "All schools" } label: { Image(systemName:"xmark.circle") }.buttonStyle(.plain).help("Clear category search and filters") }
        }.font(.system(size:11))
    }
    var customSpells:some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:280))],spacing:10) {
            ForEach(extraSpells) { spell in Button { if selectionMode { choose(CompendiumPick(spell:spell)) } else if let hero = store.heroes.first(where:{ $0.id == store.selected }) { store.openSpell(spell,hero:hero,library:true,ids:extraSpells.map(\.id)) } } label: { HStack(spacing:6) { if selectionMode { Image(systemName:picks.contains { $0.id == spell.id } ? "checkmark.circle.fill":"circle").foregroundStyle(accent) }; entryLabel(spell.name,"\(spell.level == 0 ? "Cantrip":"Level \(spell.level)") · \(spell.school)") } }.buttonStyle(.plain) }
        }
    }
    func entryLabel(_ name:String,_ subtitle:String,source:String? = nil) -> some View {
        HStack(spacing:10) { Image(systemName:category == .monster ? "pawprint":category == .spell ? "sparkles":category == .item ? "backpack":"book.closed").foregroundStyle(category == .item ? gold:sky); VStack(alignment:.leading,spacing:6) { Text(name).font(.system(size:13,weight:.medium)).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading); Text(subtitle.isEmpty ? "Reference":subtitle).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(2) }; if let source { Text(source).font(.system(size:8,weight:.semibold)).foregroundStyle(gold).padding(.horizontal,5).padding(.vertical,4).background(gold.opacity(0.08)).clipShape(Capsule()) }; if !selectionMode { Image(systemName:"chevron.right").font(.system(size:9)).foregroundStyle(.secondary) } }.padding(13).frame(maxWidth:.infinity,minHeight:72,alignment:.leading).background(surface).clipShape(RoundedRectangle(cornerRadius:9))
    }
    func open(_ entry:CompendiumEntry) {
        if entry.category == .spell, let spell = store.library.first(where:{ $0.id == entry.id }), let hero = store.heroes.first(where:{ $0.id == store.selected }) {
            let known = Set(store.library.map(\.id)); store.openSpell(spell,hero:hero,library:true,ids:matches.filter { known.contains($0.id) }.map(\.id))
        } else { selected = entry; message = ""; throughLevel = min(20,max(1,store.heroes.first(where:{ $0.id == store.selected })?.level ?? 1)) }
    }
    func referenceDetails(_ entry:CompendiumEntry) -> some View {
        return VStack(alignment:.leading,spacing:16) {
            HStack { Text(entry.name).font(.system(size:22,weight:.semibold)); Spacer(); Button(entry.custom == true ? "Edit":"Edit copy") { creation = CompendiumCreation(category:entry.category,original:entry) }; Button("Done") { selected = nil; message = "" } }
            Text(entry.category.rawValue+" · "+entry.summary).font(.caption).foregroundStyle(sky)
            Text(entry.sourceDescription).font(.caption2).foregroundStyle(gold)
            ScrollView { ReferenceBody(entry:entry).padding(.trailing,4) }.frame(maxHeight:.infinity)
            Divider()
            if entry.category == .classEntry { HStack { Stepper("Features through level \(throughLevel)",value:$throughLevel,in:1...20); Text("\(entry.featureCopies(through:throughLevel).count) separate entries").font(.caption).foregroundStyle(.secondary) } }
            HStack { Spacer(); Button("Add to character…") { add(entry) }.buttonStyle(.borderedProminent).disabled(store.heroes.isEmpty) }
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
