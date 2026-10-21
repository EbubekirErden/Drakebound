import SwiftUI

struct SearchDetail:Identifiable {
    var id=UUID()
    var title:String
    var subtitle:String
    var text:String
    var reference:CompendiumEntry? = nil
    var action:SheetAction? = nil
    var heroID:UUID? = nil
    var rolls:[NamedRoll]? = nil
    var rollSource:SheetActionRef? = nil
}

extension Store {
    func chooseSearchResult(_ result:GlobalSearchResult) {
        pendingSearchResult=result;globalSearchOpen=false
    }
    func completeGlobalSearch() {
        guard let result=pendingSearchResult else { return }
        pendingSearchResult=nil;openSearchResult(result)
    }
    func beginGlobalSearch() {
        guard menusAvailable,canPerformMenuAction,!importingCompendium else { return }
        globalSearchOpen=true
    }
    func openSearchResult(_ result:GlobalSearchResult) {
        globalSearchOpen=false
        spellDetail=nil;itemDetail=nil;searchDetail=nil
        if case .reference(let id) = result.target {
            guard let entry=compendium.first(where:{ $0.id == id }) else { return }
            searchDetail=SearchDetail(title:entry.name,subtitle:entry.category.singular+" · "+entry.sourceDescription,text:entry.text,reference:entry)
            return
        }
        if case .librarySpell(let id) = result.target {
            guard let spell=library.first(where:{ $0.id == id }) else { return }
            if let hero=heroes.first(where:{ $0.id == selected }) { openSpell(spell,hero:hero,library:true,ids:library.map(\.id)) }
            else { let reference=TemplateFactory.spell(spell);searchDetail=SearchDetail(title:spell.name,subtitle:"Library spell",text:spell.text,reference:reference) }
            return
        }
        guard let hero=heroes.first(where:{ $0.id == selected }) else { return }
        switch result.target {
        case .spell(let id):
            if let spell=hero.spells.first(where:{ $0.id == id }) { openSpell(spell,hero:hero,ids:hero.spells.map(\.id)) }
        case .item(let id):
            if hero.items.contains(where:{ $0.id == id }) { itemDetail=ItemPresentation(heroID:hero.id,itemID:id,ids:hero.items.map(\.id)) }
        case .feature(let id):
            guard let feature=hero.featureEntries?.first(where:{ $0.id == id }) else { return }
            let ref=SheetActionRef(kind:.featureUse,sourceID:id)
            searchDetail=SearchDetail(title:feature.name,subtitle:feature.category?.rawValue ?? "Feature",text:feature.text,action:hero.sheetActions.first { $0.ref == ref },heroID:hero.id,rolls:feature.rolls,rollSource:SheetActionRef(kind:.featureRoll,sourceID:id))
        case .attack(let id):
            guard let attack=hero.attacks.first(where:{ $0.id == id }) else { return }
            let ref=SheetActionRef(kind:.attack,sourceID:id)
            searchDetail=SearchDetail(title:attack.name,subtitle:hero.attackUnavailableReason(attack) ?? "Attack",text:attack.description ?? "",action:SheetAction(ref:ref,name:attack.name,subtitle:attack.type),heroID:hero.id)
        case .creature(let id):
            guard let creature=hero.creatures?.first(where:{ $0.id == id }) else { return }
            searchDetail=SearchDetail(title:creature.name,subtitle:"Companion · HP \(creature.hp)/\(creature.maximumHP) · AC \(creature.ac)",text:creature.description,heroID:hero.id)
        case .action(let ref):
            guard let action=hero.sheetActions.first(where:{ $0.ref == ref }) else { return }
            let text=hero.creatureFeature(ref)?.text ?? hero.creatureAttack(ref)?.description ?? ""
            searchDetail=SearchDetail(title:action.name,subtitle:action.subtitle,text:text,action:action,heroID:hero.id)
        case .reference,.librarySpell:break
        }
    }
}

struct GlobalSearchButton:View {
    @ObservedObject var store:Store
    var compact=false
    var body:some View {
        Button { store.beginGlobalSearch() } label: {
            HStack(spacing:8) {
                Image(systemName:"magnifyingglass")
                if !compact { Text("Search everything");Spacer(minLength:0);Text("⌘K").font(.system(size:10)).foregroundStyle(.secondary) }
            }.font(.system(size:12)).frame(maxWidth:.infinity,minHeight:32).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(ink.opacity(0.75)).padding(.horizontal,10).background(surface.opacity(0.7),in:RoundedRectangle(cornerRadius:8))
            .help("Search character and references · ⌘K").accessibilityLabel("Search everything")
            .disabled(!store.menusAvailable || store.importingCompendium)
    }
}

struct GlobalSearchPanel:View {
    @ObservedObject var store:Store
    @State private var query=""
    @State private var index:GlobalSearchIndex?
    @State private var results:[GlobalSearchResult]=[]
    @State private var selection:String?
    @FocusState private var focused:Bool
    var body:some View {
        VStack(spacing:0) {
            searchHeader
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    resultsContent

                }.onChange(of:selection) { _,value in if let value { proxy.scrollTo(value,anchor:.center) } }
            }
            Divider()
            HStack { Text("↑ ↓ to choose · Return to open");Spacer();Text("Opening a result spends nothing") }.font(.system(size:10)).foregroundStyle(.secondary).padding(.horizontal,18).padding(.vertical,12)
        }.frame(width:640,height:490).background(paper).foregroundStyle(ink)
            .task {
                let hero=store.heroes.first { $0.id == store.selected },library=store.library,compendium=store.compendium
                index=await Task.detached { GlobalSearchIndex(hero:hero,library:library,compendium:compendium) }.value
                focused=true
            }
            .task(id:query+String(index?.entries.count ?? 0)) {
                do { try await Task.sleep(nanoseconds:100_000_000) } catch { return }
                guard let index else { return }
                let term=query
                let found=await Task.detached { index.search(term) }.value
                guard !Task.isCancelled else { return }
                results=found;selection=found.first?.id
            }
            .onChange(of:query) { _,_ in results=[];selection=nil }
    }
    private var searchHeader:some View {
        HStack(spacing:12) {
            Image(systemName:"magnifyingglass").foregroundStyle(accent)
            TextField("Search spells, equipment, features…",text:$query).textFieldStyle(.plain).font(.system(size:17)).focused($focused).accessibilityLabel("Search everything")
                .onSubmit(openSelection)
                .onKeyPress(.downArrow) { move(1);return .handled }
                .onKeyPress(.upArrow) { move(-1);return .handled }
            Button("Done") { store.globalSearchOpen=false }.keyboardShortcut(.cancelAction).buttonStyle(.plain).foregroundStyle(.secondary)
        }.padding(20)
    }
    private var resultsContent:some View {
        LazyVStack(alignment:.leading,spacing:2) {
            if query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
                VStack(alignment:.leading,spacing:12) {
                    Text("Find what you need, then get back to play.").font(.system(size:16,weight:.medium,design:.serif))
                    Text("Search your character’s spells, equipment, features and attacks, plus the reference library.").font(.system(size:13)).foregroundStyle(.secondary)
                    Text("Try a name, spell level, equipment type or feature.").font(.system(size:12)).foregroundStyle(.secondary)
                }.padding(24)
            } else if index == nil {
                ProgressView().padding(24)
            } else if results.isEmpty {
                Text("No matches. Try a shorter name or a different type.").font(.system(size:13)).foregroundStyle(.secondary).padding(24)
            } else {
                ForEach(Array(results.enumerated()),id:\.element.id) { number,result in
                    if number == 0 || results[number-1].character != result.character {
                        Text(result.character ? "YOUR CHARACTER":"REFERENCES").font(.system(size:10,weight:.semibold)).tracking(1).foregroundStyle(.secondary).padding(.horizontal,12).padding(.top,14).padding(.bottom,6)
                    }
                    GlobalSearchResultRow(result:result,selected:selection == result.id) { store.chooseSearchResult(result) }.id(result.id)
                }
            }
        }.padding(.horizontal,8).padding(.bottom,12)
    }
    func move(_ amount:Int) {
        guard !results.isEmpty else { return }
        let current=results.firstIndex { $0.id == selection } ?? 0
        selection=results[min(results.count-1,max(0,current+amount))].id
    }
    func openSelection() {
        if let result=results.first(where:{ $0.id == selection }) { store.chooseSearchResult(result) }
    }
}

struct GlobalSearchResultRow:View {
    var result:GlobalSearchResult
    var selected:Bool
    var open:()->Void
    private var symbol:String { result.character ? "person.crop.circle":"books.vertical" }
    private var color:Color { result.character ? accent:sky }
    var body:some View {
        Button(action:open) {
            HStack(spacing:12) {
                Image(systemName:symbol).foregroundStyle(color).frame(width:22)
                VStack(alignment:.leading,spacing:4) {
                    Text(result.name).font(.system(size:13,weight:.medium)).frame(maxWidth:.infinity,alignment:.leading)
                    Text(result.subtitle).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(2)
                }
                Text(result.kind).font(.system(size:10)).foregroundStyle(.secondary)
                Image(systemName:"arrow.up.forward").font(.system(size:10)).foregroundStyle(.secondary)
            }.padding(12).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                .background(selected ? accent.opacity(0.12):Color.clear,in:RoundedRectangle(cornerRadius:8))
        }.buttonStyle(.plain).accessibilityLabel(result.name+", "+result.kind+", "+(result.character ? "your character":"reference"))
    }
}

struct SearchDetailView:View {
    @ObservedObject var store:Store
    var detail:SearchDetail
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text(detail.title).font(.system(size:22,weight:.semibold,design:.serif));Spacer();Button("Done") { store.searchDetail=nil }.buttonStyle(PageButtonStyle()) }
            Text(detail.subtitle).font(.system(size:12)).foregroundStyle(.secondary)
            if let action=detail.action,let i=store.heroes.firstIndex(where:{ $0.id == detail.heroID }) {
                CombatActionRow(hero:$store.heroes[i],store:store,action:action).background(surface,in:RoundedRectangle(cornerRadius:8))
            }
            ScrollView {
                if let reference=detail.reference { ReferenceBody(entry:reference) }
                else { Text(DescriptionMarkdown.attributed(detail.text.isEmpty ? "No description provided.":detail.text)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }
                if let i=store.heroes.firstIndex(where:{ $0.id == detail.heroID }) {
                    RollButtons(rolls:detail.rolls,hero:store.heroes[i],store:store,source:detail.title,actionSource:detail.rollSource)
                }
            }.frame(maxHeight:.infinity)
            if let reference=detail.reference {
                HStack { Spacer();Button("Add to character…") { store.searchDetail=nil;store.compendiumAdd=CompendiumAddRequest(picks:[CompendiumPick(reference)]) }.buttonStyle(PageButtonStyle(prominent:true)).disabled(store.heroes.isEmpty) }
            }
        }.padding(22).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
    }
}
