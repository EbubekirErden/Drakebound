import SwiftUI

struct HealthBar: View {
    var hp: Int
    var maximum: Int
    var height: CGFloat = 6
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some View {
        GeometryReader { g in
            ZStack(alignment:.leading) {
                Capsule().fill(ink.opacity(0.08))
                Capsule().fill(healthColor(hp,maximum).gradient).frame(width:g.size.width * min(1,max(0,Double(hp)/Double(max(1,maximum)))))
            }
        }.frame(height:height).animation(reduceMotion ? nil:.spring(response:0.45,dampingFraction:0.85),value:hp).accessibilityLabel("Health \(hp) of \(maximum)")
    }
}

struct Portrait: View {
    var data: Data?
    var name: String
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius:8).fill(accent.opacity(0.12))
            if let image = LocalImage.display(data) { Image(nsImage:image).resizable().scaledToFill().frame(width:size,height:size).clipped() }
            else { Text(String(name.prefix(1)).uppercased()).font(.system(size:size*0.43,weight:.medium,design:.serif)).foregroundStyle(accent) }
        }.frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:8)).accessibilityLabel("\(name) portrait")
    }
}

struct PictureControls: View {
    @Binding var data: Data?
    var label: String
    @State var error: String?
    var previewHeight:CGFloat = 200
    @State var preview = false
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            if let image = LocalImage.display(data) {
                Button { preview = true } label: { Image(nsImage:image).resizable().scaledToFit().frame(maxWidth:420,maxHeight:previewHeight).clipShape(RoundedRectangle(cornerRadius:8)) }.buttonStyle(.plain).help("View image")
            }
            HStack {
                Button { do { if let chosen = try LocalImage.choose() { data = chosen } } catch { self.error = "Choose a readable image under 25 MB. PNG, JPEG, and HEIC are supported.\n\(error.localizedDescription)" } } label: { Label(data == nil ? "Add image":"Replace image",systemImage:"photo") }
                if data != nil { Button("Remove image",role:.destructive) { data = nil } }
                Text(label).font(.caption).foregroundStyle(.secondary)
            }.font(.system(size:11))
        }
        .alert("Image could not be loaded",isPresented:Binding(get:{ error != nil },set:{ if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        .sheet(isPresented:$preview) { VStack { HStack { Text(label).font(.headline); Spacer(); Button("Done") { preview = false } }; if let image = LocalImage.display(data) { Image(nsImage:image).resizable().scaledToFit().frame(maxWidth:.infinity,maxHeight:.infinity) } }.padding(22).frame(width:720,height:600) }
    }
}

struct PartySidebar: View {
    @ObservedObject var store: Store
    @Binding var compact: Bool
    @State private var characterQuery = ""
    private var matchingCharacters: [Hero] {
        let query = characterQuery.trimmingCharacters(in:.whitespacesAndNewlines)
        return compact || query.isEmpty ? store.heroes:store.heroes.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.characterClass.localizedCaseInsensitiveContains(query) }
    }
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            brand
            if !compact {
                HStack {
                    Text("Characters").font(.system(size:12,weight:.semibold))
                    Spacer()
                    Text("\(store.heroes.count)").font(.system(size:11)).foregroundStyle(.secondary)
                }.padding(.horizontal,18).padding(.top,20).padding(.bottom,10)
                HStack(spacing:7) {
                    Image(systemName:"magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search characters",text:$characterQuery).textFieldStyle(.plain).accessibilityLabel("Search characters")
                    if !characterQuery.isEmpty {
                        Button { characterQuery = "" } label: { Image(systemName:"xmark.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain).help("Clear character search").accessibilityLabel("Clear character search")
                    }
                }.font(.system(size:12)).padding(9).background(paper.opacity(0.7),in:RoundedRectangle(cornerRadius:8)).padding(.horizontal,12).padding(.bottom,10)
            }
            ScrollView {
                VStack(spacing:6) {
                    ForEach(matchingCharacters) { hero in characterRow(hero) }
                    if matchingCharacters.isEmpty && !characterQuery.isEmpty {
                        Text("No matching characters").font(.caption).foregroundStyle(.secondary).padding(.vertical,12)
                    }
                    Button { store.addHero() } label: { sidebarLabel("New character",icon:"plus") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("New character · ⌘N")
                }.padding(.horizontal,10).padding(.top,compact ? 12:0)
            }.scrollIndicators(.hidden)
            VStack(spacing:6) {
                Button { store.showCompendium = true } label: { sidebarLabel("Compendium",icon:"books.vertical") }
                    .buttonStyle(.plain).foregroundStyle(store.showCompendium ? accent:ink.opacity(0.75))
                    .background(store.showCompendium ? accent.opacity(0.12):Color.clear,in:RoundedRectangle(cornerRadius:10))
                    .accessibilityAddTraits(store.showCompendium ? .isSelected:[]).help("Compendium · ⌘7")
                Divider().padding(.vertical,6)
                if compact {
                    VStack(spacing:6) { importControl; exportControl }
                } else {
                    HStack(spacing:8) { importControl; exportControl }
                }
                if !compact {
                    Label("On this Mac",systemImage:"internaldrive").font(.system(size:11)).foregroundStyle(.secondary)
                        .frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,10).padding(.top,8)
                }
            }.font(.system(size:13)).foregroundStyle(ink.opacity(0.7)).padding(10).padding(.bottom,6)
        }.frame(maxHeight:.infinity).background(paper)
    }

    private var importControl: some View {
        Button { store.importBackup() } label: { transferLabel("Import",icon:"square.and.arrow.down") }
            .buttonStyle(.plain).help("Import backup or Fight Club XML")
            .background(ink.opacity(0.04),in:RoundedRectangle(cornerRadius:8))
    }

    private var exportControl: some View {
        Menu {
            Button("Character PDF…") { store.showPDFExport = true }.disabled(store.selected == nil)
            Button("Backup JSON…") { store.exportBackup() }
        } label: { transferLabel("Export",icon:"square.and.arrow.up") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).tint(ink.opacity(0.7))
            .frame(maxWidth:.infinity,minHeight:36)
            .background(ink.opacity(0.04),in:RoundedRectangle(cornerRadius:8))
            .help("Export character PDF or JSON backup").accessibilityLabel("Export")
    }

    private func transferLabel(_ title:String,icon:String) -> some View {
        HStack(spacing:6) {
            Image(systemName:icon).frame(width:15)
            if !compact { Text(title).lineLimit(1) }
        }.font(.system(size:12,weight:.medium)).frame(maxWidth:.infinity,minHeight:36)
            .contentShape(Rectangle()).accessibilityElement(children:.ignore).accessibilityLabel(title)
    }

    private var brand: some View {
        HStack(spacing:8) {
            Button {
                withAnimation(reduceMotion ? nil:.easeInOut(duration:0.2)) { compact.toggle() }
            } label: {
                Group {
                    if let mark = AppBrand.sidebarMark { Image(nsImage:mark).resizable().scaledToFit() }
                    else { Image(systemName:"hexagon").resizable().scaledToFit().foregroundStyle(gold) }
                }.frame(width:36,height:36).contentShape(Rectangle())
            }.buttonStyle(.plain).help(compact ? "Expand sidebar":"Compact sidebar")
                .accessibilityLabel(compact ? "Expand sidebar":"Compact sidebar")
            if !compact {
                VStack(alignment:.leading,spacing:3) {
                    Text("Drakebound").font(.custom("Palatino-Bold",size:18,relativeTo:.headline)).lineLimit(1).minimumScaleFactor(0.85)
                    Text("Character companion").font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength:0)
                compactButton
            }
        }.frame(maxWidth:.infinity,alignment:compact ? .center:.leading)
            .padding(.horizontal,compact ? 10:14).padding(.top,20).padding(.bottom,18)
            .overlay(alignment:.bottom) { Rectangle().fill(ink.opacity(0.06)).frame(height:1).padding(.horizontal,14) }
    }

    private var compactButton: some View {
        Button {
            withAnimation(reduceMotion ? nil:.easeInOut(duration:0.2)) { compact.toggle() }
        } label: {
            Image(systemName:"sidebar.left").font(.system(size:14)).frame(width:28,height:28)
                .background(ink.opacity(0.04),in:RoundedRectangle(cornerRadius:6)).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(.secondary)
            .help(compact ? "Expand sidebar":"Compact sidebar")
            .accessibilityLabel(compact ? "Expand sidebar":"Compact sidebar")
    }

    private func characterRow(_ hero: Hero) -> some View {
        let selected = store.selected == hero.id && !store.showCompendium
        return Button {
            withAnimation(reduceMotion ? nil:.easeOut(duration:0.18)) { store.selected = hero.id; store.showCompendium = false }
        } label: {
            HStack(spacing:12) {
                VStack(spacing:5) {
                    Portrait(data:hero.portrait,name:hero.name,size:compact ? 36:42)
                        .overlay(RoundedRectangle(cornerRadius:8).stroke(selected ? accent.opacity(0.65):ink.opacity(0.1),lineWidth:1))
                    if compact { HealthBar(hp:hero.hp,maximum:hero.maximumHP,height:3).frame(width:32) }
                }
                if !compact {
                    VStack(alignment:.leading,spacing:5) {
                        Text(hero.name).font(.system(size:13,weight:.semibold)).lineLimit(2)
                        Text("\(hero.characterClass) · Level \(hero.level)").font(.system(size:11)).foregroundStyle(.secondary).lineLimit(1)
                        HealthBar(hp:hero.hp,maximum:hero.maximumHP,height:3)
                    }.frame(maxWidth:.infinity,alignment:.leading)
                }
            }.frame(maxWidth:.infinity,alignment:compact ? .center:.leading).padding(.horizontal,10).padding(.vertical,11)
                .background(selected ? accent.opacity(0.12):Color.clear,in:RoundedRectangle(cornerRadius:10))
                .overlay(alignment:.leading) { if selected { Capsule().fill(accent).frame(width:3).padding(.vertical,14) } }
                .contentShape(RoundedRectangle(cornerRadius:10))
        }.buttonStyle(.plain).help("\(hero.name) · \(hero.characterClass) · Level \(hero.level) · \(hero.hp)/\(hero.maximumHP) HP")
            .accessibilityLabel("\(hero.name), \(hero.characterClass), level \(hero.level)")
            .accessibilityAddTraits(selected ? .isSelected:[])
    }

    private func sidebarLabel(_ title: String,icon: String) -> some View {
        HStack(spacing:10) {
            Image(systemName:icon).font(.system(size:15)).frame(width:20)
            if !compact { Text(title).font(.system(size:13,weight:.medium)); Spacer(minLength:0) }
        }.frame(maxWidth:.infinity,minHeight:38,alignment:compact ? .center:.leading)
            .padding(.horizontal,10).contentShape(RoundedRectangle(cornerRadius:8))
            .accessibilityElement(children:.ignore).accessibilityLabel(title)
    }
}

struct JournalPanel: View {
    @Binding var hero: Hero
    var quickNote:(()->Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State var expanded: Set<UUID> = []
    @State var search = ""
    @State private var editing:JournalEntry?
    @State private var selectedTag:String?
    var availableTags:[String] { JournalEntry.parseTags(entries.wrappedValue.flatMap(\.normalizedTags).joined(separator:",")).sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var entries: Binding<[JournalEntry]> { Binding(get:{ hero.journalEntries ?? [] },set:{ hero.journalEntries = $0 }) }
    var visibleNotes:[JournalEntry] { hero.orderedJournalEntries.filter { $0.matchesJournalSearch(search,tag:selectedTag) } }
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            PageToolbar(title:"Adventure journal",subtitle:"\(entries.wrappedValue.count) \(entries.wrappedValue.count == 1 ? "note":"notes") · \(entries.wrappedValue.filter { $0.pinned == true }.count) pinned",color:journalTint,searchTitle:"Search notes",query:$search) {
                if let quickNote {
                    Button(action:quickNote) { Label("Quick note",systemImage:"square.and.pencil") }
                        .buttonStyle(PageButtonStyle()).help("Quick note · ⇧⌘J")
                }
                Button { editing = JournalEntry() } label: { Label("New note",systemImage:"plus") }.buttonStyle(PageButtonStyle(color:journalTint,prominent:true))
            }
            if !availableTags.isEmpty || selectedTag != nil {
                ControlFlowLayout(spacing:8) {
                    PagePicker(title:"Tag",selectionTitle:selectedTag ?? "All tags",selection:$selectedTag) {
                        Text("All tags").tag(String?.none)
                        ForEach(availableTags,id:\.self) { Text($0).tag(Optional($0)) }
                    }
                    if let selectedTag { ActiveFilterChip(title:selectedTag) { self.selectedTag = nil } }
                }
            }
            if entries.wrappedValue.isEmpty { CenteredEmptyState("A story worth keeping",systemImage:"book.closed",description:Text("Add a note for each session, person, place, or idea."),height:300) }
            if !entries.wrappedValue.isEmpty && visibleNotes.isEmpty {
                CenteredEmptyState("No matching notes",systemImage:"book.closed",description:Text("Try another title, text, or tag."),height:300)
            }
            ForEach(visibleNotes) { entry in
                let siblings=visibleNotes.filter { ($0.pinned == true) == (entry.pinned == true) }.map(\.id)
                let position=siblings.firstIndex(of:entry.id) ?? 0
                if entry.matchesJournalSearch(search,tag:selectedTag) {
                    VStack(alignment:.leading,spacing:0) {
                        DisclosureGroup(isExpanded:Binding(get:{ expanded.contains(entry.id) },set:{ isOpen in withAnimation(reduceMotion ? nil:.easeOut(duration:0.18)) { if isOpen { expanded.insert(entry.id) } else { expanded.remove(entry.id) } } })) {
                            VStack(alignment:.leading,spacing:12) {
                                if entry.description.isEmpty {
                                    Text("No note text yet.").font(.system(size:13)).foregroundStyle(.secondary)
                                } else {
                                    Text(AttributedString(JournalText.read(entry.richText,plain:entry.description,dark:colorScheme == .dark)))
                                        .textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                                }
                                if let data = entry.image, let image = NSImage(data:data) {
                                    Image(nsImage:image).resizable().scaledToFit().frame(maxHeight:280)
                                        .clipShape(RoundedRectangle(cornerRadius:8)).accessibilityLabel("Note image")
                                }

                            }.padding(.top,14)
                        } label: {
                            HStack(spacing:8) {
                            ListReorderGrip(token:ListReorderToken(kind:.journal,heroID:hero.id,entryID:entry.id),name:entry.title,enabled:siblings.count > 1)
                            Button { withAnimation(reduceMotion ? nil:.easeOut(duration:0.18)) { if expanded.contains(entry.id) { expanded.remove(entry.id) } else { expanded.insert(entry.id) } } } label: {
                                HStack(spacing:10) { Image(systemName:entry.image == nil ? "text.alignleft":"photo.on.rectangle").foregroundStyle(gold); VStack(alignment:.leading,spacing:4) { Text(entry.title.isEmpty ? "Untitled note":entry.title).font(.system(size:13,weight:.medium)); if !expanded.contains(entry.id) { Text(entry.description.isEmpty ? "Add a description…":entry.description.replacingOccurrences(of:"\n",with:" ")).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(1) } }; Spacer() }.contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Button { hero.toggleJournalPin(entry.id) } label: {
                                Image(systemName:entry.pinned == true ? "pin.fill":"pin").font(.system(size:12)).frame(width:28,height:28).foregroundStyle(entry.pinned == true ? journalTint:Color.secondary)
                            }.buttonStyle(.plain).help(entry.pinned == true ? "Unpin note":"Pin note to top").accessibilityLabel(entry.pinned == true ? "Unpin note":"Pin note")
                            Button { editing = entry } label: {
                                Image(systemName:"pencil").font(.system(size:12,weight:.medium)).frame(width:28,height:28)
                                    .background(ink.opacity(0.04),in:RoundedRectangle(cornerRadius:6)).contentShape(Rectangle())
                            }.buttonStyle(.plain).help("Edit note").accessibilityLabel("Edit note")
                            Menu {
                                Button(entry.pinned == true ? "Unpin note":"Pin note") { hero.toggleJournalPin(entry.id) }
                                Button("Move up") { if position > 0 { hero.reorderJournal(ListReorderToken(kind:.journal,heroID:hero.id,entryID:entry.id),onto:siblings[position-1],visibleIDs:siblings) } }.disabled(position == 0)
                                Button("Move down") { if position+1 < siblings.count { hero.reorderJournal(ListReorderToken(kind:.journal,heroID:hero.id,entryID:entry.id),onto:siblings[position+1],visibleIDs:siblings) } }.disabled(position+1 >= siblings.count)
                                Divider()
                                Button("Duplicate note") { var copy = entry; copy.id = UUID(); copy.title += " copy"; hero.journalEntries?.append(copy) }
                                Button("Delete note",role:.destructive) { let id = entry.id; hero.journalEntries?.removeAll { $0.id == id } }
                            } label: { Image(systemName:"ellipsis") }
                                .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width:28,height:28)
                                .background(ink.opacity(0.04),in:RoundedRectangle(cornerRadius:6))
                                .help("Note options").accessibilityLabel("Note options")
                            }
                        }
                        if !entry.normalizedTags.isEmpty {
                            ControlFlowLayout(spacing:6) {
                                ForEach(entry.normalizedTags,id:\.self) { tag in
                                    Button { selectedTag = tag } label: {
                                        Label(tag,systemImage:"tag").font(.system(size:10)).padding(.horizontal,7).padding(.vertical,4)
                                            .foregroundStyle(journalTint).background(journalTint.opacity(0.08),in:Capsule())
                                    }.buttonStyle(.plain).help("Show notes tagged \(tag)")
                                }
                            }.padding(.top,8)
                        }
                    }.padding(16).background(surface).clipShape(RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(ink.opacity(0.06)))
                    .modifier(ListReorderDropTarget { token in hero.reorderJournal(token,onto:entry.id,visibleIDs:visibleNotes.map(\.id)) })
                }
            }
        }.onAppear { hero.migrateContent() }
        .sheet(item:$editing) { note in
            JournalNoteEditor(note:note,isNew:!entries.wrappedValue.contains { $0.id == note.id }) { saved in
                if let index = hero.journalEntries?.firstIndex(where:{ $0.id == saved.id }) {
                    hero.journalEntries?[index] = saved
                } else { hero.journalEntries = [saved] + (hero.journalEntries ?? []) }
                expanded.insert(saved.id)
            }
        }
    }
}

struct CreaturesPanel: View {
    @Binding var hero: Hero
    @ObservedObject var store: Store
    @State var editing: Creature?
    @State var search = ""
    @State private var browsing=false
    var creatures: Binding<[Creature]> { Binding(get:{ hero.creatures ?? [] },set:{ hero.creatures = $0 }) }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            PageToolbar(title:"Creatures",subtitle:"Companions, summons, and encounters",color:leaf,searchTitle:"Search creatures",query:$search) {
                Button { browsing=true } label: { Label("Add creature",systemImage:"plus") }.buttonStyle(PageButtonStyle(color:leaf,prominent:true)).popover(isPresented:$browsing) { CreatureQuickAdd(entries:store.compendium.filter { $0.category == .monster }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },characterName:hero.name,onAdd:{ hero.creatures=(hero.creatures ?? [])+[$0] },onCustom:{ editing=Creature() }) }
            }
            if creatures.wrappedValue.isEmpty { creatureEmptyState("Make room for a companion","Browse the compendium or create a custom creature with portraits, stats, HP, and attacks.") }
            let matching = creatures.wrappedValue.filter { matches($0) }
            if !creatures.wrappedValue.isEmpty && matching.isEmpty { creatureEmptyState("No matching creatures","Try another name, type, or role.") }
            if !matching.isEmpty {
                HStack { Text("Active · \(matching.filter(\.isActive).count)").font(.caption).foregroundStyle(accent); Spacer(); Text("Inactive creatures keep their HP, attacks, and notes.").font(.caption2).foregroundStyle(.secondary) }
            }
            ForEach(creatures) { $creature in
                if matches(creature) && creature.isActive {
                    CreatureCard(creature:$creature,store:store,deactivate:{ hero.setCreatureActive(creature.id,false) },edit:{ editing = creature },remove:{ let id = creature.id; hero.creatures?.removeAll { $0.id == id } })
                }
            }
            if matching.contains(where:{ !$0.isActive }) {
                Card(title:"Inactive · \(matching.filter { !$0.isActive }.count)") {
                    ForEach(creatures) { $creature in
                        if matches(creature) && !creature.isActive {
                            HStack(spacing:12) {
                                Image(systemName:"moon.zzz").foregroundStyle(.secondary)
                                VStack(alignment:.leading,spacing:3) { Text(creature.name).font(.system(size:12,weight:.semibold)); Text("\(creature.kind) · \(creature.hp)/\(creature.maximumHP) HP").font(.caption2).foregroundStyle(.secondary) }
                                Spacer()
                                Button("Edit") { editing = creature }.buttonStyle(.borderless)
                                Button(creature.isSummon ? "Summon":"Activate") { hero.setCreatureActive(creature.id,true) }.buttonStyle(.bordered).tint(accent).accessibilityLabel("Activate "+creature.name)
                            }.padding(8).background(paper.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius:7))
                        }
                    }
                }
            }
        }.sheet(item:$editing) { creature in CreatureEditor(creature:creature) { updated in var all = hero.creatures ?? []; if let i = all.firstIndex(where:{ $0.id == updated.id }) { all[i] = updated } else { all.append(updated) }; hero.creatures = all } }
    }
    func creatureEmptyState(_ title:String,_ message:String) -> some View { CenteredEmptyState(title,systemImage:"pawprint",description:Text(message),height:300) }
    func matches(_ creature:Creature) -> Bool { search.isEmpty || [creature.name,creature.kind,creature.type].contains { $0.localizedCaseInsensitiveContains(search) } }
}

struct CreatureCard: View {
    @Binding var creature:Creature
    @ObservedObject var store:Store
    var deactivate:()->Void
    var edit:()->Void
    var remove:()->Void
    @State private var detail:CreatureAttack?
    @State private var health:HealthAdjustment?
    @State private var expanded:Set<UUID> = []
    @State private var cardExpanded=true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        Card(title:creature.kind,tip:.creatures) {
            HStack(spacing:12) {
                Button { health=nil;detail=nil;withAnimation(reduceMotion ? nil:.easeInOut(duration:0.18)) { cardExpanded.toggle() } } label: {
                    HStack(spacing:8) { Image(systemName:cardExpanded ? "chevron.down":"chevron.right").font(.system(size:11,weight:.semibold)).frame(width:16);Text(creature.name).font(.system(size:13,weight:.semibold));if !cardExpanded { Text("\(creature.hp)/\(creature.maximumHP) HP · AC \(creature.ac)").font(.caption).foregroundStyle(.secondary) } }.contentShape(Rectangle())
                }.buttonStyle(.plain).help(cardExpanded ? "Collapse creature card":"Expand creature card").accessibilityLabel((cardExpanded ? "Collapse ":"Expand ")+creature.name).accessibilityValue(cardExpanded ? "Expanded":"Collapsed")
                Spacer();Label("Active in play",systemImage:"checkmark.circle.fill").font(.caption).foregroundStyle(accent);Button(action:deactivate) { Label(creature.isSummon ? "Dismiss":"Deactivate",systemImage:"moon.zzz").padding(.horizontal,6).frame(minHeight:28).contentShape(Rectangle()) }.buttonStyle(.bordered).tint(gold).font(.caption).help("Move to Inactive without changing HP or notes").accessibilityLabel((creature.isSummon ? "Dismiss ":"Deactivate ")+creature.name) }
            if cardExpanded {
            if creature.imageLayout == nil || creature.imageLayout == .banner { CreatureBanner(creature:$creature,edit:edit,remove:remove) }
            if creature.imageLayout == nil || creature.imageLayout == .banner { creatureDetails }
            else { HStack(alignment:.top,spacing:16) {
                if creature.imageLayout == .left { sidePortrait }
                VStack(alignment:.leading,spacing:12) { CreatureCompactHeader(creature:$creature,edit:edit,remove:remove);creatureDetails }.frame(maxWidth:.infinity)
                if creature.imageLayout == .right { sidePortrait }
            } }
            }
        }.popover(item:$detail) { attack in AttackDescription(name:attack.name,text:attack.description ?? "",edit:{ detail = nil; edit() }) }
    }
    var sidePortrait:some View { CroppedImage(data:creature.image,crop:creature.bannerCrop ?? BannerCrop()).frame(width:150,height:250).background(surface).clipShape(RoundedRectangle(cornerRadius:9)).accessibilityLabel(creature.name+" portrait") }
    var creatureDetails:some View { VStack(alignment:.leading,spacing:12) {
            HStack {
                Text("\(creature.hp)").font(.system(size:27,weight:.semibold,design:.rounded)).foregroundStyle(healthColor(creature.hp,creature.maximumHP)); Text("/ \(creature.maximumHP) HP").font(.caption).foregroundStyle(.secondary); Spacer()
                Button { health = .damage } label: { Label("Damage",systemImage:"minus") }.tint(coral).popover(isPresented:Binding(get:{ health == .damage },set:{ if !$0 { health = nil } })) { CreatureHealthPopup(creature:$creature,healing:false) }
                Button { health = .healing } label: { Label("Heal",systemImage:"plus") }.tint(leaf).popover(isPresented:Binding(get:{ health == .healing },set:{ if !$0 { health = nil } })) { CreatureHealthPopup(creature:$creature,healing:true) }
            }
            HealthBar(hp:creature.hp,maximum:creature.maximumHP,height:6)
            HStack(spacing:7) { ForEach(0..<6,id:\.self) { i in RollChoiceButton { mode in store.roll("1d20\(signed(creature.modifier(i)))","\(creature.name) · \(abilities[i])",mode:mode) } label: { VStack(spacing:4) { Text(String(abilities[i].prefix(3)).uppercased()).font(.system(size:9)).foregroundStyle(.secondary); Text(signed(creature.modifier(i))).font(.system(size:17,weight:.semibold,design:.rounded)) }.frame(maxWidth:.infinity).padding(.vertical,9).background(paper.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius:7)) } } }.padding(.vertical,5)
            if !creature.attacks.isEmpty {
                Text("ATTACKS").font(.system(size:9,weight:.bold)).tracking(1).foregroundStyle(coral)
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:10),count:min(2,creature.attacks.count)),alignment:.leading,spacing:10) {
                    ForEach(creature.attacks) { attack in
                        VStack(alignment:.leading,spacing:10) {
                            HStack { Button { detail = attack } label: { Label(attack.name,systemImage:"scope").font(.system(size:13,weight:.semibold)).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle()) }.buttonStyle(.plain); Image(systemName:"info.circle").font(.caption).foregroundStyle(.secondary) }
                            HStack(spacing:7) {
                                if attack.resolution != .damage { RollChoiceButton { mode in store.roll("1d20\(signed(attack.bonus))","\(creature.name) · \(attack.name)",mode:mode) } label: { AttackRollField(title:"TO HIT",value:signed(attack.bonus),subtitle:store.rollMode.rawValue,color:sky) } }
                                Button { store.roll(attack.damage,"\(creature.name) · \(attack.name) · damage") } label: { AttackRollField(title:"DAMAGE",value:attack.damage,color:coral) }.buttonStyle(.plain)
                            }
                            if let text = attack.description, !text.isEmpty { Text(text).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(2) }
                        }.padding(12).background(paper.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius:9))
                    }
                }
            }
            if let traits = creature.traits, !traits.isEmpty {
                Text("TRAITS & ACTIONS").font(.system(size:9,weight:.bold)).tracking(1).foregroundStyle(gold).padding(.top,5)
                ForEach(traits) { trait in
                    DisclosureGroup(isExpanded:Binding(get:{ expanded.contains(trait.id) },set:{ value in if value { expanded.insert(trait.id) } else { expanded.remove(trait.id) } })) { Text(trait.text).font(.system(size:12)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,7) } label: { Button { if expanded.contains(trait.id) { expanded.remove(trait.id) } else { expanded.insert(trait.id) } } label: { Text(trait.name).font(.system(size:12,weight:.medium)).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle()) }.buttonStyle(.plain) }.padding(9).background(paper.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius:7))
                }
            }
            if !creature.description.isEmpty { DisclosureGroup("Notes & source") { DetailText(text:creature.description) }.font(.caption) }
    } }

}
struct CreatureHealthPopup:View {
    @Binding var creature:Creature
    var healing:Bool
    @State private var amount = ""
    @FocusState private var focused:Bool
    @Environment(\.dismiss) var dismiss
    var value:Int? { guard let n = Int(amount), (0...99999).contains(n) else { return nil }; return n }
    var body:some View { VStack(alignment:.leading,spacing:14) { Text(healing ? "Restore HP":"Take damage").font(.headline); TextField("Amount",text:$amount).textFieldStyle(.roundedBorder).font(.system(size:26,weight:.semibold,design:.rounded)).focused($focused).onSubmit(apply); HStack { ForEach([1,5,10,20],id:\.self) { n in Button("+\(n)") { amount = String(min(99999,(value ?? 0)+n)) } } }; HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Apply",action:apply).buttonStyle(.borderedProminent).disabled(value == nil) } }.padding(18).frame(width:280).tint(healing ? leaf:coral).onAppear { focused = true } }
    func apply() { guard let value else { return }; if healing { creature.heal(value) } else { creature.damage(value) }; dismiss() }
}

struct CreatureEditor:View {
    @State var creature:Creature
    var onSave:(Creature)->Void
    @State private var saveToCompendium = false
    @Environment(\.templateSaveAction) private var saveTemplate
    @Environment(\.dismiss) var dismiss
    var valid:Bool { !creature.name.trimmingCharacters(in:.whitespaces).isEmpty && (1...99999).contains(creature.maximumHP) && (0...99999).contains(creature.hp) && (0...50).contains(creature.ac) && (0...999).contains(creature.speed) && creature.scores.allSatisfy { (1...30).contains($0) } && creature.attacks.allSatisfy { (-100...100).contains($0.bonus) && (try? Dice.roll($0.damage)) != nil } }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Creature").font(.system(size:20,weight:.semibold)); Spacer(); Button("Cancel") { dismiss() }.buttonStyle(PageButtonStyle()); Button("Save creature") { creature.hp = min(creature.hp,creature.maximumHP); if saveToCompendium { saveTemplate?(TemplateFactory.creature(creature)) }; onSave(creature); dismiss() }.buttonStyle(PageButtonStyle(prominent:true)).disabled(!valid) }
            SaveTemplateToggle(selected:$saveToCompendium)
            ScrollView { VStack(spacing:12) {
                EditorGroup(title:"Identity") { TextField("Creature name",text:$creature.name); HStack { Picker("Role",selection:$creature.kind) { ForEach(["Companion","Familiar","Summon","Encounter","Reference"],id:\.self) { Text($0).tag($0) } }; TextField("Size / type / challenge",text:$creature.type) }; DisclosureGroup("Image") { PictureControls(data:$creature.image,label:"Creature image") } }
                EditorGroup(title:"Notes & full source") { BorderedTextEditor(text:$creature.description,height:90,markdown:true) }
                EditorColumns {
                EditorGroup(title:"Combat stats") {
                    HStack { EditorField(title:"HP") { TextField("Current HP",value:$creature.hp,format:.number) }; EditorField(title:"Maximum") { TextField("Maximum HP",value:$creature.maximumHP,format:.number) }; EditorField(title:"AC") { TextField("Armor class",value:$creature.ac,format:.number) }; EditorField(title:"Speed · ft") { TextField("Speed",value:$creature.speed,format:.number) } }
                    HStack { ForEach(0..<6,id:\.self) { i in EditorField(title:String(abilities[i].prefix(3)).uppercased()) { TextField(abilities[i],value:$creature.scores[i],format:.number) } } }
                }
                    EditorGroup(title:"Presentation & play") {
                CreatureLayoutPicker(creature:$creature)
                Toggle("Active in play",isOn:Binding(get:{ creature.isActive },set:{ creature.isActive = $0 })).font(.caption).help("Inactive creatures remain saved and can be activated at any time. Companions stay active until you deactivate them.")
                    }
                } trailing: {
                EditorGroup(title:"Attacks") {
                    ForEach($creature.attacks) { $attack in
                        VStack(alignment:.leading,spacing:9) { HStack { TextField("Attack name",text:$attack.name); Button { let id = attack.id; creature.attacks.removeAll { $0.id == id } } label: { Image(systemName:"minus.circle") }.buttonStyle(.plain) }; HStack { EditorField(title:"To hit") { TextField("To hit",value:$attack.bonus,format:.number) }; EditorField(title:"Damage dice") { DiceFormulaField(value:$attack.damage) } }; VStack(alignment:.leading,spacing:9) { ActionTimingPicker(timing:$attack.timing,defaultLabel:"Default · Action"); Picker("Resolution",selection:Binding(get:{ attack.resolution ?? .attack },set:{ attack.resolution = $0 })) { ForEach(CreatureResolution.allCases,id:\.self) { option in Text(option.rawValue).tag(option) } } }; BorderedTextEditor(text:Binding(get:{ attack.description ?? "" },set:{ attack.description = $0 }),height:75) }.modifier(EditorRowStyle(index:creature.attacks.firstIndex { $0.id == attack.id } ?? 0))
                    }
                    Button("Add attack") { creature.attacks.append(CreatureAttack()) }
                }
                EditorGroup(title:"Traits & other actions") {
                    ForEach(Binding(get:{ creature.traits ?? [] },set:{ creature.traits = $0 })) { $trait in VStack(spacing:8) { HStack { TextField("Trait name",text:$trait.name); Button { let id = trait.id; creature.traits?.removeAll { $0.id == id } } label: { Image(systemName:"minus.circle") }.buttonStyle(.plain) }; ActionTimingPicker(timing:$trait.timing,defaultLabel:"Passive · hide from Actions"); BorderedTextEditor(text:$trait.text,height:70) } }
                    Button("Add trait / action") { creature.traits = (creature.traits ?? [])+[CharacterFeature()] }
                }
                }
            } }
        }.padding(20).modifier(CustomEditorFrame()).textFieldStyle(.roundedBorder).tint(accent)
    }
}
