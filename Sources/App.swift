import SwiftUI
import AppKit
import UniformTypeIdentifiers

let ink = Color(red:0.89,green:0.90,blue:0.89)
let accent = Color(red:0.43,green:0.75,blue:0.68)
let paper = Color(red:0.105,green:0.125,blue:0.14)
let surface = Color(red:0.145,green:0.165,blue:0.18)
let gold = Color(red:0.88,green:0.69,blue:0.42)
let sky = Color(red:0.50,green:0.71,blue:0.88)
let coral = Color(red:0.89,green:0.54,blue:0.47)
let leaf = Color(red:0.49,green:0.76,blue:0.52)
let journalTint = Color(red:0.76,green:0.61,blue:0.70)
func tabColor(_ title:String) -> Color {
    switch title {
    case "Actions":return coral
    case "Equipment":return gold
    case "Spells":return sky
    case "Journal":return journalTint
    case "Creatures":return leaf
    default:return accent
    }
}
func sectionColor(_ title: String) -> Color {
    switch title { case "Health": return leaf; case "Attacks": return coral; case "Equipment", "Resources": return gold; case "Checks & saves", "Spell slots", "Library": return sky; default: return accent }
}
func healthColor(_ hp: Int,_ maximum: Int) -> Color { let ratio = Double(hp)/Double(max(1,maximum)); return ratio > 0.5 ? leaf : ratio > 0.25 ? gold : coral }

@MainActor final class Store: ObservableObject {
    @Published var activity = ActivityLedger()
    @Published var showActivity = false
    var activityBaseline:[UUID:CharacterPlayState] = [:]
    var activityReady = false
    var activityContext:ActivityContext?
    @Published var heroes: [Hero] = []
    @Published var library = starterSpells
    @Published var selected: UUID?
    @Published var rolls: [RollResult] = []
    @Published var animatedRoll: RollResult?
    @Published var rollMode = RollMode.normal
    private let dicePresenter = DicePresenter()
    @Published var error: String?
    @Published var compendium:[CompendiumEntry] = []
    @Published var compendiumRevision = 0
    @Published var showPDFExport = false
    @Published var compendiumAdd:CompendiumAddRequest?
    @Published var showHelp = false
    @Published var showCompendium = false
    @Published var activeTab = "Sheet"
    @Published var commandRequest:UICommandRequest?
    var consumedCommandID:UUID?
    @Published var openEditorSheets = 0
    @Published var importingCompendium = false
    @Published var spellDetail:SpellPresentation?
    @Published var itemDetail:ItemPresentation?
    @Published var characterGuide:CharacterGuideSession?
    private var saveTask: Task<Void,Never>?
    let file: URL
    init() {
        file = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Fellowship5e/characters.json")
        if FileManager.default.fileExists(atPath:file.path) {
            do { let a = try JSONDecoder().decode(Archive.self,from:Data(contentsOf:file)); try validate(a); heroes = a.heroes; library = a.library }
            catch { self.error = "Your saved file could not be read. It has been left untouched. Import a backup before making changes.\n\(error.localizedDescription)" }
        } else { heroes = [.sample] }
        for i in heroes.indices { heroes[i].migrateContent(); heroes[i].reconcileConcentration() }
        let compendiumFile = file.deletingLastPathComponent().appendingPathComponent("compendium.json")
        if FileManager.default.fileExists(atPath:compendiumFile.path) {
            do { compendium = try JSONDecoder().decode([CompendiumEntry].self,from:Data(contentsOf:compendiumFile)) }
            catch { self.error = "The compendium could not be read. Its file was left untouched.\n\(error.localizedDescription)" }
        }
        let lists = Dictionary(compendium.filter { $0.category == .spell }.map { ($0.id,$0.value("classes")) },uniquingKeysWith:{ first,_ in first })
        for i in library.indices where library[i].classes == nil { library[i].classes = lists[library[i].id] }
        for i in heroes.indices { heroes[i].synchronizeWeaponAttacks(compendium:compendium) }
        selected = heroes.first?.id
        loadActivity()
    }
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds:350_000_000) } catch { return }
            self?.save()
        }
    }
    func saveTaskCancellationForGuide() { saveTask?.cancel() }
    func save() {
        guard !heroes.isEmpty else { return }
        do {
            for i in heroes.indices { heroes[i].synchronizeWeaponAttacks(compendium:compendium);heroes[i].reconcileConcentration() }
            captureActivity()
            let archive = Archive(heroes:heroes,library:library); try validate(archive)
            try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
            try encoder.encode(archive).write(to:file,options:.atomic)
        } catch { self.error = "Could not save: \(error.localizedDescription)" }
    }
    func roll(_ expression: String, _ label: String, mode:RollMode? = nil) {
        do { record(try Dice.d20(expression,label:label,mode:mode ?? rollMode)) }
        catch { self.error = "Use dice notation such as 1d20+5 or 2d6+3. Up to 100 dice per term, with 2–1000 sides." }
    }
    func rollTyped(_ expression:String,_ label:String,hero:Hero,kind:D20Kind,ability:Int? = nil,mode:RollMode? = nil) {
        do { record(try hero.performD20(expression,label:label,kind:kind,ability:ability,manual:mode ?? rollMode)) } catch { self.error = error.localizedDescription }
    }
    func record(_ result: RollResult) {
        if let selected { activityContext = ActivityContext(heroID:selected,title:result.label) }
        rolls.insert(result,at:0); rolls = Array(rolls.prefix(50))
        if !result.event { animatedRoll = result; dicePresenter.show(result) { [weak self] in self?.animatedRoll = nil } }
    }
    func addHero() { guard characterGuide == nil else { return }; characterGuide = CharacterGuideSession() }
    func openSpell(_ spell:Spell,hero:Hero,library:Bool = false,ids:[UUID]) { spellDetail = SpellPresentation(heroID:hero.id,spell:spell,library:library,ids:ids) }
    func importCompendium(_ data:Data) {
        guard !importingCompendium else { return }; importingCompendium = true
        Task { @MainActor in
            do {
                let result = try await Task.detached { try CompendiumImport.read(data) }.value
                let before = compendium.count; compendium = CompendiumImport.merged(compendium,result.entries)
                let existingIDs = Set(library.map(\.id))
                for entry in compendium where entry.category == .spell && !existingIDs.contains(entry.id) { if let spell = entry.spell() { library.append(spell) } }
                try saveCompendium(); save(); showCompendium = true
                error = "Imported \(compendium.count-before) new compendium entries across \(Set(result.entries.map(\.category)).count) categories.\(result.repairedAmpersands > 0 ? " Repaired \(result.repairedAmpersands) unescaped ampersand during parsing; your original file is unchanged.":"") Exact duplicate records are kept once; distinct versions with the same name are retained. Reference descriptions do not activate rules automatically."
            } catch { self.error = "Compendium import failed.\n\(error.localizedDescription)" }
            importingCompendium = false
        }
    }
    func saveCompendium() throws {
        let directory = file.deletingLastPathComponent(); try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        try JSONEncoder().encode(compendium).write(to:directory.appendingPathComponent("compendium.json"),options:.atomic)
    }
    func exportBackup() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Drakebound-backup.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted]; try encoder.encode(Archive(heroes:heroes,library:library,compendium:compendium)).write(to:url,options:.atomic) }
        catch { self.error = error.localizedDescription }
    }
    func importBackup() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json,.xml]; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf:url)
            if url.pathExtension.lowercased() == "xml" {
                if String(data:data.prefix(4096),encoding:.utf8)?.contains("<compendium") == true { importCompendium(data); return }
                var imported = try FightClubImport.read(data)
                imported.heroes = try imported.heroes.map { original in
                    var hero = original
                    if let portrait = hero.portrait { hero.portrait = try LocalImage.normalize(portrait) }
                    if hero.creatures != nil { for i in hero.creatures!.indices { if let image = hero.creatures![i].image { hero.creatures![i].image = try LocalImage.normalize(image) } } }
                    return hero
                }
                if !imported.heroes.isEmpty {
                    save()
                    if FileManager.default.fileExists(atPath:file.path) {
                        let backup = file.deletingLastPathComponent().appendingPathComponent("before-import-\(UUID().uuidString).json")
                        try Data(contentsOf:file).write(to:backup,options:.atomic)
                    }
                    var added = 0
                    for hero in imported.heroes where !heroes.contains(where:{ $0.sourceXML == data && $0.name == hero.name }) { heroes.append(hero); selected = hero.id; added += 1 }
                    save()
                    error = "Imported \(added) character(s). Portraits, spells, equipment, features, counters, and creatures are included. Read ‘Fight Club import review’ in Journal for mappings and fields to verify. Existing characters were backed up before import."
                } else {
                    var added = 0
                    for var spell in imported.spells where !library.contains(where:{ $0.name.caseInsensitiveCompare(spell.name) == .orderedSame }) { spell.id = UUID(); library.append(spell); added += 1 }
                    save(); error = "Imported \(added) spells, including their custom roll formulas."
                }
            } else {
                let archive = try JSONDecoder().decode(Archive.self,from:data); try validate(archive)
                for var hero in archive.heroes { hero.id = UUID(); hero.migrateContent(); heroes.append(hero) }
                for var spell in archive.library where !library.contains(where:{ $0.name == spell.name }) { spell.id = UUID(); library.append(spell) }
                if let entries = archive.compendium { compendium = CompendiumImport.merged(compendium,entries); let ids = Set(library.map(\.id)); for entry in compendium where !ids.contains(entry.id) { if let spell = entry.spell() { library.append(spell) } }; try saveCompendium() }
                selected = heroes.last?.id; save()
            }
        } catch { self.error = "Import failed. Choose a Drakebound JSON backup, Fight Club character XML, or compendium XML.\n\(error.localizedDescription)" }
    }
}

enum AppBrand {
    static var sidebarMark:NSImage? {
        guard let url = Bundle.main.url(forResource:"DrakeboundSidebarMark",withExtension:"png") else { return nil }
        return NSImage(contentsOf:url)
    }
    static var icon:NSImage? {
        guard let url = Bundle.main.url(forResource:"DrakeboundD20",withExtension:"png"),let data = try? Data(contentsOf:url) else { return nil }
        return NSImage(data:data)
    }
    static func showAbout() {
        var options:[NSApplication.AboutPanelOptionKey:Any] = [:]
        if let icon { options[.applicationIcon] = icon }
        NSApplication.shared.orderFrontStandardAboutPanel(options:options)
    }
}
final class DrakeboundAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = AppBrand.icon { NSApplication.shared.applicationIconImage = icon }
    }
}

@main struct DrakeboundApp: App {
    @NSApplicationDelegateAdaptor(DrakeboundAppDelegate.self) private var appDelegate
    @StateObject var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView(store:store).environment(\.templateSaveAction,{ store.upsertTemplate($0) }).frame(minWidth:900,maxWidth:.infinity,minHeight:620,maxHeight:.infinity).preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for:NSWindow.willBeginSheetNotification)) { _ in store.openEditorSheets += 1 }
                .onReceive(NotificationCenter.default.publisher(for:NSWindow.didEndSheetNotification)) { _ in store.openEditorSheets = max(0,store.openEditorSheets-1) }
                .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)) { _ in store.save() }
        }.defaultSize(width:1260,height:840).windowResizability(.contentMinSize)
        .commands { DrakeboundCommands(store:store) }
    }
}

struct RootView: View {
    @ObservedObject var store: Store
    var tab:String { store.activeTab }
    @Namespace var tabs
    @AppStorage("sidebarCompact") private var sidebarCompact = false
    @AppStorage("sidebarWidth") private var sidebarWidth = 248.0
    @State private var resizeStart: Double?
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let sections = [("Sheet","person.text.rectangle"),("Actions","bolt.fill"),("Equipment","backpack"),("Spells","sparkles"),("Journal","book.closed"),("Creatures","pawprint")]
    var body: some View {
        GeometryReader { viewport in
            let maximumWidth = min(320.0,max(220.0,Double(viewport.size.width)-660.0))
            let width = min(maximumWidth,max(220.0,sidebarWidth))
            HStack(spacing:0) {
                PartySidebar(store:store,compact:$sidebarCompact).frame(width:sidebarCompact ? 76:width)
                Rectangle().fill(ink.opacity(0.07)).frame(width:5).contentShape(Rectangle())
                    .overlay { Capsule().fill(ink.opacity(0.2)).frame(width:2,height:28) }
                    .onHover { over in if !sidebarCompact { if over { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } } }
                    .gesture(DragGesture(minimumDistance:1,coordinateSpace:.global).onChanged { value in
                        guard !sidebarCompact else { return }
                        if resizeStart == nil { resizeStart = width }
                        sidebarWidth = min(maximumWidth,max(220,(resizeStart ?? width)+Double(value.translation.width)))
                    }.onEnded { _ in resizeStart = nil })
                    .accessibilityLabel("Sidebar width")
                    .accessibilityValue(sidebarCompact ? "Compact":"\(Int(width)) points")
                    .accessibilityAdjustableAction { direction in
                        guard !sidebarCompact else { return }
                        sidebarWidth = min(maximumWidth,max(220,width+(direction == .increment ? 20:-20)))
                    }.help(sidebarCompact ? "Expand the sidebar to resize":"Drag to resize sidebar")
                VStack(spacing:0) {
                    if !store.showCompendium { ScrollView(.horizontal) { HStack(spacing:4) {
                        ForEach(sections,id:\.0) { title,icon in
                            Button { store.navigate(to:title) } label: {
                                HStack(spacing:7) { Image(systemName:icon).font(.system(size:11)).foregroundStyle(tabColor(title).opacity(tab == title ? 1:0.6)); Text(title).font(.system(size:12,weight:tab == title ? .semibold:.regular)) }.foregroundStyle(tab == title ? ink:ink.opacity(0.52)).padding(.horizontal,15).padding(.vertical,13)
                                    .background { if tab == title { RoundedRectangle(cornerRadius:7).fill(paper).matchedGeometryEffect(id:"tab",in:tabs) } }
                                    .overlay(alignment:.bottom) { if tab == title { Capsule().fill(tabColor(title)).frame(height:2).padding(.horizontal,14) } }
                            }.buttonStyle(.plain)
                        }
                        Spacer(minLength:2)
                        Text("5e").font(.system(size:10,weight:.medium)).foregroundStyle(.secondary).padding(.trailing,14)
                    } }.frame(height:44).scrollIndicators(.hidden).padding(.top,8).padding(.horizontal,10).background(surface.opacity(0.65)).animation(reduceMotion ? nil:.easeInOut(duration:0.2),value:tab)
                    Divider().opacity(0.5) }
                    if store.showCompendium { CompendiumView(store:store) }
                    else if let i = store.heroes.firstIndex(where:{ $0.id == store.selected }) {
                        HeroView(hero:$store.heroes[i],store:store,tab:tab).id(store.selected)
                    } else {
                        CenteredEmptyState("Your next adventure",systemImage:"shield",description:Text("Create a character or import a backup."))
                        Button("Create character") { store.addHero() }
                    }
                    Divider()
                    DiceDock(store:store)
                }
            }
        }.background(paper).foregroundStyle(ink).tint(accent).accessibilityHidden(store.characterGuide != nil)
        .overlay {
            if let detail = store.spellDetail, let i = store.heroes.firstIndex(where:{ $0.id == detail.heroID }) {
                DismissibleDetail(dismiss:{ store.spellDetail = nil }) {
                    SpellDetails(hero:$store.heroes[i],store:store,original:detail.spell,library:detail.library,navigationIDs:detail.ids,onClose:{ store.spellDetail = nil })
                }
            }
        }
        .overlay { if let item = store.itemDetail, let i = store.heroes.firstIndex(where:{ $0.id == item.heroID }) { DismissibleDetail(dismiss:{ store.itemDetail = nil }) { ItemDetails(hero:$store.heroes[i],store:store,presentation:item,close:{ store.itemDetail = nil }) } } }
        .overlay { if store.importingCompendium { ZStack { Color.black.opacity(0.3); VStack(spacing:14) { ProgressView(); Text("Importing compendium…"); Text("Indexing local references across all categories").font(.caption).foregroundStyle(.secondary) }.padding(28).background(surface).clipShape(RoundedRectangle(cornerRadius:12)) } } }
        .overlay { if let session = store.characterGuide { CharacterGuide(session:session,store:store).id(session.id) } }
        .sheet(item:$store.compendiumAdd) { request in CompendiumDestination(store:store,request:request) }
        .sheet(isPresented:$store.showPDFExport) { if let hero = store.heroes.first(where:{ $0.id == store.selected }) { PDFExportView(hero:hero) } }
        .sheet(isPresented:$store.showHelp) { TipsLibrary() }
        .onChange(of:store.heroes) { _,_ in store.captureActivity(); store.scheduleSave() }
        .alert("Drakebound",isPresented:Binding(get:{ store.error != nil },set:{ if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
    }
}

struct RollHistory: View {
    var rolls: [RollResult]
    @State var show = false
    var body: some View {
        Button { show.toggle() } label: { Image(systemName:"clock.arrow.circlepath") }.buttonStyle(.plain).help("Roll history")
            .popover(isPresented:$show) {
                ScrollView { VStack(alignment:.leading,spacing:16) { Text("ROLL HISTORY").font(.headline); if rolls.isEmpty { Text("Roll a check, attack, or die to begin.") }; ForEach(rolls) { r in HStack { VStack(alignment:.leading) { Text(r.label).bold(); Text("\(r.expression) · \(r.detail ?? r.dice.map(String.init).joined(separator:", "))").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(r.event ? "✓":"\(r.total)").font(.title2).bold().foregroundStyle(accent) } } }.padding(22) }.frame(width:340,height:400)
            }
    }
}

struct Card<Content:View>: View {
    var title: String
    var tip:HelpTopic? = nil
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment:.leading,spacing:10) { HStack { Text(title.uppercased()).font(.system(size:10,weight:.bold)).tracking(1.2).foregroundStyle(sectionColor(title)); Spacer(); if let tip { TipButton(topic:tip) } }; content }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(surface).clipShape(RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(ink.opacity(0.08),lineWidth:1)) }
}

struct HeroView: View {
    @Binding var hero: Hero
    @ObservedObject var store: Store
    var tab: String
    @AppStorage("characterBannerExpanded") private var bannerExpanded = false
    @State var edit = false
    @State var adding: String?
    @State private var browsingSpells = false
    @State var rest = false
    @State var delete = false
    @State var hitDice = false
    @State var search = ""
    @State var preparation = PreparationFilter.all
    @State var spellLevel = -1
    @State var itemEditor: Item?
    @State var attackEditor: Attack?
    @State var managingSlots = false
    @FocusState private var searchFocused:Bool
    var body: some View {
        page
        .onReceive(store.$commandRequest) { request in
            guard let request,request.heroID == hero.id else { return }
            if request.action == .diceInput { return }
            if request.action == .search && (store.activeTab != "Spells" || store.showCompendium) { return }
            guard store.consume(request) else { return }
            switch request.action {
            case .edit: edit = true
            case .addItem: itemEditor = Item(name:"",kind:.gear)
            case .addSpell: browsingSpells = true
            case .rest: rest = true
            case .search: searchFocused = true
            case .diceInput: break
            }
        }
        .sheet(isPresented:$edit) { HeroEditor(hero:$hero) }
        .sheet(item:$attackEditor) { a in AttackEditor(attack:a) { edited in if let i = hero.attacks.firstIndex(where:{ $0.id == edited.id }) { hero.attacks[i] = edited } else { hero.attacks.append(edited) } } }
        .sheet(item:$itemEditor) { item in ItemEditor(item:item,hero:hero) { edited in if let i = hero.items.firstIndex(where:{ $0.id == edited.id }) { hero.items[i] = edited } else { hero.items.append(edited) };hero.synchronizeWeaponAttacks(compendium:store.compendium) } }
        .sheet(item:Binding(get:{ adding.map { AddKind(name:$0) } },set:{ adding = $0?.name })) { kind in SpellEditor(spell:Spell(name:"",level:1),hero:hero,isCompendium:kind.name == "Library spell",classOptions:store.compendium.filter { $0.category == .classEntry }.map(\.name)) { spell in if kind.name == "Library spell" { store.library.append(spell); store.save() } else { hero.spells.append(spell) } } }
        .sheet(isPresented:$managingSlots) { SlotManager(hero:$hero) }
        .sheet(isPresented:$rest) { RestEditor(hero:$hero,store:store) }
        .sheet(isPresented:$hitDice) { HitDicePopup(hero:$hero,store:store) }
        .confirmationDialog("Delete \(hero.name)?",isPresented:$delete,titleVisibility:.visible) { Button("Delete character",role:.destructive) { let id = hero.id; store.selected = store.heroes.first(where:{ $0.id != id })?.id; store.heroes.removeAll { $0.id == id }; store.save() } } message: { Text("This removes the character from this Mac. Export a backup first if you want to keep a copy.") }
    }
    @ViewBuilder var page:some View {
        GeometryReader { viewport in
            let bannerHeight = bannerExpanded ? min(380,max(275,(viewport.size.width-36)/3.5)):min(200,max(160,(viewport.size.width-36)/5))
            ScrollView {
                VStack(alignment:.leading,spacing:-24) {
                    GeometryReader { position in
                        let y = position.frame(in:.named("heroScroll")).minY
                        CharacterBanner(hero:$hero,expanded:$bannerExpanded,previewAspectRatio:max(1,(viewport.size.width-36)/bannerHeight),edit:{ edit = true },more:AnyView(Group {
                            if tab == "Sheet" { SheetDisplayMenu();Divider() }
                            Button("Rest & recovery") { rest = true }
                            Button("Hit dice") { hitDice = true }
                            Button("Duplicate character") { var copy = hero; copy.id = UUID(); copy.name += " copy"; store.heroes.append(copy); store.selected = copy.id; store.save() }
                            Divider(); Button("Delete character…",role:.destructive) { delete = true }.disabled(store.heroes.count <= 1)
                        }),levelUp:{ store.beginLevelUp(hero) })
                            .frame(height:bannerHeight).offset(y:max(0,-y*0.65))
                    }.frame(height:bannerHeight).padding(18).zIndex(0)
                    VStack(alignment:.leading,spacing:14) {
                        switch tab {
                        case "Actions":
                            ConcentrationChip(hero:$hero,store:store)
                            QuickActionsPanel(hero:$hero,store:store,fullPage:true)
                        case "Sheet": character
                        case "Equipment": equipment
                        case "Spells": spellbook
                        case "Journal": JournalPanel(hero:$hero)
                        default: CreaturesPanel(hero:$hero,store:store)
                        }
                    }.padding(18).frame(maxWidth:.infinity).background(paper).clipShape(UnevenRoundedRectangle(topLeadingRadius:18,topTrailingRadius:18)).zIndex(1)
                }
            }.coordinateSpace(name:"heroScroll")
        }
    }
    var character: some View {
        VStack(spacing:14) {
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:8),count:5),spacing:8) {
                sheetStat("AC","\(hero.armorClass)","shield").help(hero.armorClassExplanation)
                RollChoiceButton(explanation:hero.initiativeExplanation) { mode in store.rollTyped(hero.expression("1d20",bonus:hero.initiative,targets:["initiative","checks","check.1"]),"Initiative",hero:hero,kind:.initiative,ability:1,mode:mode) } label: { sheetStat("INIT",signed(hero.initiative+hero.testPenalty),"bolt") }
                sheetStat("SPEED","\(hero.movement)","figure.walk")
                sheetStat("PROF",signed(hero.proficiency),"star")
                sheetStat("PASSIVE","\(hero.passivePerception)","eye")
            }
            HealthPanel(hero:$hero,store:store,rest:{ rest = true })
            AbilityTable(hero:$hero,store:store)
            AttacksPanel(hero:$hero,store:store,edit:{ attackEditor = $0 })
            CounterPanel(hero:$hero)
            SkillsPanel(hero:$hero,store:store)
            ConditionsPanel(hero:$hero)
            FeaturePanel(hero:$hero,store:store)
            BonusPanel(hero:$hero)
        }
    }
    func sheetStat(_ label:String,_ value:String,_ icon:String)->some View {
        VStack(spacing:5) {
            Label(label,systemImage:icon).font(.system(size:9,weight:.medium)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
            Text(value).font(.system(size:20,weight:.medium,design:.rounded)).lineLimit(1).minimumScaleFactor(0.75)
        }.frame(maxWidth:.infinity).frame(height:60).background(surface,in:RoundedRectangle(cornerRadius:7))
    }
    func stat(_ label: String,_ value: String,_ icon:String) -> some View {
        HStack(spacing:6) { Image(systemName:icon).foregroundStyle(.secondary).font(.system(size:10)); Text(label).font(.system(size:10,weight:.medium)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8); Spacer(minLength:2); Text(value).font(.system(size:20,weight:.medium,design:.rounded)).lineLimit(1).minimumScaleFactor(0.75) }.padding(.horizontal,10).frame(maxWidth:.infinity).frame(height:PageControl.statisticHeight).background(surface).clipShape(RoundedRectangle(cornerRadius:6))
    }
    func check(_ i:Int,_ label:String,mode:RollMode? = nil) { let targets = ["checks","check.\(i)"]; store.rollTyped(hero.expression("1d20",bonus:hero.modifier(i)+hero.flat(targets),targets:targets),label,hero:hero,kind:.check,ability:i,mode:mode) }

    var spellNavigationIDs:[UUID] { hero.spells.enumerated().filter { (spellLevel == -1 || $0.element.level == spellLevel) && preparation.includes($0.element) }.filter { search.isEmpty || $0.element.name.localizedCaseInsensitiveContains(search) }.sorted { $0.element.level == $1.element.level ? $0.offset < $1.offset:$0.element.level < $1.element.level }.map { $0.element.id } }
    var spellbook: some View {
        VStack(spacing:16) {
            PageToolbar(title:"Spells",subtitle:"\(hero.spells.count) spells in your spellbook",color:sky,searchTitle:"Search spells",query:$search,focus:$searchFocused) {
                Menu { Button("Prepare all") { for i in hero.spells.indices { hero.spells[i].prepared=true } };Button("Unprepare all level 1+") { for i in hero.spells.indices where hero.spells[i].level > 0 { hero.spells[i].prepared=false } } } label: { Text("Preparation") }.modifier(PageMenuStyle()).fixedSize().help("Changes your whole spellbook, including spells hidden by filters.")
                Button { browsingSpells = true } label: { Label("Add spell",systemImage:"plus") }.buttonStyle(PageButtonStyle(color:sky,prominent:true))
                    .popover(isPresented:$browsingSpells) {
                        GuideSpellBrowser(catalog:GuideCatalog(compendium:store.compendium,library:store.library),className:hero.characterClass,alreadyKnown:hero.spells,hero:hero,onAdd:{ spell in
                            var copy = spell; copy.id = UUID(); copy.castingAbility = nil; copy.sourceClassID = nil; copy.sourceClassName = nil; copy.prepared = copy.level == 0
                            hero.spells.append(copy)
                        },onCustom:{ browsingSpells = false; adding = "Spell" })
                    }
            }
            HStack(spacing:12) { stat("SPELL SAVE DC","\(hero.spellDC)","shield").help(hero.spellDCExplanation); stat("SPELL ATTACK",signed(hero.spellAttack+hero.testPenalty),"sparkles").help(hero.spellAttackExplanation); Button("Manage slots") { managingSlots = true }.buttonStyle(PageButtonStyle(height:PageControl.statisticHeight)) }
            Card(title:"Spell slots") {
                ForEach(0..<9,id:\.self) { i in if hero.slots[i] > 0 { HStack { Text("Level \(i+1)").font(.system(size:12,weight:.semibold)).frame(width:70,alignment:.leading); ForEach(0..<hero.slots[i],id:\.self) { slot in Button { hero.usedSlots[i] = slot < hero.usedSlots[i] ? slot : slot+1 } label: { Image(systemName:slot < hero.usedSlots[i] ? "circle.fill":"circle").font(.system(size:19)).foregroundStyle(accent) }.buttonStyle(.plain).help("Toggle expended spell slots") }; Spacer(); Text("\(max(0,hero.slots[i]-hero.usedSlots[i])) remaining").font(.caption).foregroundStyle(.secondary) } } }
                Text("Filled circles are expended. Set slot totals and casting ability in Edit character.").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing:10) {
                ControlFlowLayout(spacing:10) {
                    HStack(spacing:2) {
                        ForEach(PreparationFilter.allCases,id:\.self) { filter in
                            Button { preparation = filter } label: {
                                Text(filter.rawValue).font(.system(size:11,weight:.medium)).frame(width:94,height:PageControl.height-6)
                                    .foregroundStyle(preparation == filter ? paper:ink.opacity(0.7))
                                    .background(preparation == filter ? accent:Color.clear).clipShape(RoundedRectangle(cornerRadius:6))
                            }.buttonStyle(.plain).accessibilityLabel("\(filter.rawValue) spells").accessibilityAddTraits(preparation == filter ? .isSelected:[])
                        }
                    }.padding(3).background(surface).clipShape(RoundedRectangle(cornerRadius:8))
                    PagePicker(title:"Spell level",selectionTitle:spellLevel < 0 ? "All levels":spellLevel == 0 ? "Cantrips":"Level \(spellLevel)",selection:$spellLevel) { Text("All levels").tag(-1); Text("Cantrips").tag(0); ForEach(1...9,id:\.self) { Text("Level \($0)").tag($0) } }.frame(width:125)
                }
                if !search.isEmpty || preparation != .all || spellLevel >= 0 {
                    ControlFlowLayout(spacing:6) {
                        if !search.isEmpty { ActiveFilterChip(title:"Search: "+search) { search="" } }
                        if preparation != .all { ActiveFilterChip(title:preparation.rawValue) { preparation = .all } }
                        if spellLevel >= 0 { ActiveFilterChip(title:spellLevel == 0 ? "Cantrips":"Level \(spellLevel)") { spellLevel = -1 } }
                        Button("Clear all") { search="";preparation = .all;spellLevel = -1 }.buttonStyle(.plain).font(.system(size:11)).foregroundStyle(accent)
                        Text("\(spellNavigationIDs.count) of \(hero.spells.count) spells").font(.system(size:11)).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(0...9,id:\.self) { level in
                let matching = hero.spells.filter { $0.level == level && (spellLevel == -1 || $0.level == spellLevel) && (preparation.includes($0)) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
                if !matching.isEmpty { Card(title:level == 0 ? "Cantrips" : "Level \(level)") { ForEach(matching) { spell in SpellbookRow(hero:$hero,store:store,spell:spell,navigationIDs:spellNavigationIDs) } } }
            }
            Button("Browse the compendium") { store.showCompendium = true }.buttonStyle(.plain).foregroundStyle(sky)
            if !hero.spells.isEmpty && !hero.spells.contains(where: { (spellLevel == -1 || $0.level == spellLevel) && preparation.includes($0) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }) {
                CenteredEmptyState("No matching spells",systemImage:"sparkles",description:Text("Try another level, preparation filter, or search."),height:300)
            }
            if hero.spells.isEmpty { CenteredEmptyState("Your spellbook is empty",systemImage:"sparkles",description:Text("Add a custom spell or choose one from the compendium."),height:300) }
        }
    }
    var equipment: some View { EquipmentPanel(hero:$hero,store:store,edit:{ itemEditor = $0 }) }

}

struct HeroEditor: View {
    @Binding var hero: Hero
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment:.leading) {
            HStack { Text("Edit character").font(.title2).fontDesign(.serif); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }.padding(22)
            Form {
                Section("Portrait") { PictureControls(data:$hero.portrait,label:"Character portrait") }
                Section("Identity") { TextField("Name",text:$hero.name); TextField("Ancestry",text:$hero.ancestry); TextField("Class / multiclass",text:$hero.characterClass).disabled(hero.classLevels != nil); TextField("Background",text:$hero.background); OptionField(title:"Alignment",value:$hero.alignment,choices:alignmentChoices); Stepper("Total level: \(hero.level)",value:$hero.level,in:1...20).disabled(hero.classLevels != nil); if hero.classLevels != nil { Text("Use Level up on the banner to advance class levels.").font(.caption).foregroundStyle(.secondary) } }
                Section("Abilities") { ForEach(0..<6,id:\.self) { i in Stepper("\(abilities[i]): \(hero.scores[i])",value:$hero.scores[i],in:1...30) } }
                Section("Combat") { Stepper("Base maximum HP: \(hero.maxHP)",value:$hero.maxHP,in:1...999); Stepper("Base AC (without equipment): \(hero.ac)",value:$hero.ac,in:0...50); Stepper("Speed: \(hero.speed) ft",value:$hero.speed,in:0...300,step:5); Picker("Hit die",selection:$hero.hitDie) { ForEach([6,8,10,12],id:\.self) { Text("d\($0)").tag($0) } } }
                Section("Spellcasting") { Picker("Casting ability",selection:$hero.castingAbility) { ForEach(0..<6,id:\.self) { Text(abilities[$0]).tag($0) } }; ForEach(0..<9,id:\.self) { i in Stepper("Level \(i+1) slots: \(hero.slots[i])",value:$hero.slots[i],in:0...20) } }
                Section("Weapon & armor training") { EquipmentTrainingEditor(grants:$hero.trainingGrants,source:"Manual character training",expanded:true); ForEach(hero.equipmentTrainingGrants) { grant in Text(trainingTargetName(grant.target)+" · "+grant.source).font(.caption) } }
                Section("Features & traits") { Text("Manage feature descriptions and custom rolls on the Sheet.").font(.caption).foregroundStyle(.secondary) }
            }.formStyle(.grouped).editorBorder()
        }.frame(width:570,height:720).tint(accent)
    }
}
struct AddKind: Identifiable { var name:String; var id:String { name } }
struct AddEntry: View {
    let kind:String
    @Binding var hero: Hero
    @ObservedObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var name = ""
    @State var level = 1
    @State var ability = 0
    @State var damage = "1d8"
    @State var damageType = "Slashing"
    @State var addModifier = true
    @State var spellAttack = false
    @State var quantity = 1
    @State var weight = 0.0
    @State var text = ""
    @State var school = "Evocation"
    @State var time = "1 action"
    @State var range = "60 feet"
    @State var duration = "Instantaneous"
    @State var components = "V, S"
    var isSpell:Bool { kind.contains("spell") || kind == "Spell" }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Add \(kind.lowercased())").font(.title2).fontDesign(.serif)
            Form {
                TextField("Name",text:$name)
                if isSpell { Stepper("Spell level: \(level) (0 = cantrip)",value:$level,in:0...9); TextField("School",text:$school); TextField("Casting time",text:$time); TextField("Range",text:$range); TextField("Duration",text:$duration); SpellComponentButtons(value:$components); SpellMaterialField(components:$components); Text("Description"); TextEditor(text:$text).frame(height:130) }
                else if kind == "Attack" { Picker("Ability",selection:$ability) { ForEach(0..<6,id:\.self) { Text(abilities[$0]).tag($0) } }; DiceFormulaField(value:$damage); OptionField(title:"Damage type",value:$damageType,choices:damageTypeChoices); Toggle("Spell attack",isOn:$spellAttack); Toggle("Add ability modifier to damage",isOn:$addModifier) }
                else { Stepper("Quantity: \(quantity)",value:$quantity,in:1...999); TextField("Weight each (lb)",value:$weight,format:.number); TextField("Notes",text:$text) }
            }.textFieldStyle(.roundedBorder)
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Add") { add() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(name.trimmingCharacters(in:.whitespaces).isEmpty || (kind == "Attack" && (try? Dice.roll(damage)) == nil) || weight < 0) }
        }.padding(26).frame(width:500).tint(accent)
    }
    func add() {
        if isSpell { let s = Spell(name:name,level:level,school:school,time:time,range:range,duration:duration,components:components,text:text); if kind == "Library spell" { store.library.append(s); store.save() } else { hero.spells.append(s) } }
        else if kind == "Attack" { hero.attacks.append(Attack(name:name,ability:ability,addDamageModifier:addModifier,damage:damage,type:damageType,isSpell:spellAttack)) }
        else { hero.items.append(Item(name:name,quantity:quantity,weight:weight,notes:text)) }
        dismiss()
    }
}
