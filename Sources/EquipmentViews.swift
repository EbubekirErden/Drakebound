import SwiftUI

struct ItemPresentation { var heroID:UUID; var itemID:UUID; var ids:[UUID] }
struct EquipmentPanel:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var edit:(Item)->Void
    @State private var search = ""
    @State private var trainingOpen = false
    @State private var adding=false
    @State private var kind = "All types"
    @State private var equippedOnly = false
    @State private var collapsed:Set<UUID> = []
    @State private var containerEditor:EquipmentContainer?
    @FocusState private var searchFocused:Bool
    var types:[String] { Array(Set(hero.items.map { $0.equipmentKind.rawValue })).sorted() }
    var items:[Item] { hero.items.filter { (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) && (kind == "All types" || $0.equipmentKind.rawValue == kind) && (!equippedOnly || $0.equipped) } }
    var filtering:Bool { !search.isEmpty || kind != "All types" || equippedOnly }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            DisclosureGroup("Weapon & armor proficiency",isExpanded:$trainingOpen) { EquipmentTrainingRoster(hero:hero);EquipmentTrainingEditor(grants:$hero.trainingGrants,source:"Manual character training",expanded:true) }.font(.caption)
            HStack {
                Label(String(format:"%.1f / %d lb",hero.items.reduce(0) { $0+Double($1.quantity)*$1.weight },hero.effectiveScore(0)*15),systemImage:"scalemass").font(.caption).foregroundStyle(.secondary)
                Spacer(); CurrencyButton(hero:$hero)
                Button { containerEditor = EquipmentContainer(name:"") } label: { Label("Container",systemImage:"shippingbox") }
                Button("Compendium") { store.showCompendium = true }; Button { adding=true } label: { Label("Add item",systemImage:"plus") }.buttonStyle(.borderedProminent).popover(isPresented:$adding) { EquipmentQuickAdd(entries:store.compendium.filter { $0.category == .item }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },onAdd:{ hero.items.append($0) },onCustom:{ edit(Item(name:"",kind:.gear)) }) }
            }
            HStack { TextField("Search equipment",text:$search).focused($searchFocused); Picker("Type",selection:$kind) { Text("All types").tag("All types"); ForEach(types,id:\.self) { Text($0).tag($0) } }.labelsHidden().frame(width:175); Toggle("Equipped",isOn:$equippedOnly).toggleStyle(.checkbox) }.textFieldStyle(.roundedBorder)
            LazyVStack(spacing:10) {
                if items.contains(where:{ $0.containerID == nil }) || !filtering { inventoryGroup(nil) }
                ForEach(hero.inventoryContainers) { storage in if !filtering || items.contains(where:{ $0.containerID == storage.id }) { inventoryGroup(storage) } }
            }
            if items.isEmpty && filtering { Text("No items match these filters.").font(.caption).foregroundStyle(.secondary).padding() }
        }
        .sheet(item:$containerEditor) { storage in ContainerEditor(storage:storage,existing:hero.inventoryContainers) { updated in var all = hero.inventoryContainers; if let i = all.firstIndex(where:{ $0.id == updated.id }) { all[i] = updated } else { all.append(updated) }; hero.equipmentContainers = all } }
        .onReceive(store.$commandRequest) { request in if let request,request.action == .search && request.heroID == hero.id && store.activeTab == "Equipment" && !store.showCompendium && store.consume(request) { searchFocused = true } }
    }
    func inventoryGroup(_ storage:EquipmentContainer?) -> some View {
        let group = items.filter { $0.containerID == storage?.id }
        let total = hero.items.filter { $0.containerID == storage?.id }.count
        let open = storage.map { !collapsed.contains($0.id) } ?? true
        return VStack(spacing:7) {
            HStack {
                if let storage { Button { if collapsed.contains(storage.id) { collapsed.remove(storage.id) } else { collapsed.insert(storage.id) } } label: { Label(storage.name,systemImage:open ? "chevron.down":"chevron.right") }.buttonStyle(.plain).accessibilityLabel("\(open ? "Collapse":"Expand") \(storage.name)") }
                else { Label("Carried",systemImage:"backpack") }
                Spacer(); Text(String(format:"%d items · %.1f lb",total,hero.inventoryWeight(in:storage?.id))).font(.caption2).foregroundStyle(.secondary)
                if let storage { Menu { Button("Rename container") { containerEditor = storage }; Button("Remove container · keep items") { hero.removeContainer(storage.id) } } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).frame(width:20) }
            }.font(.system(size:12,weight:.medium)).foregroundStyle(gold).padding(.vertical,6)
            if open {
                ForEach(group) { item in itemRow(item) }
                if group.isEmpty && !filtering { Text("Empty · move items here from their menu or editor").font(.caption2).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).padding(8) }
            }
        }.padding(10).overlay(RoundedRectangle(cornerRadius:9).stroke(ink.opacity(0.07)))
    }
    func itemRow(_ item:Item) -> some View {
        HStack(spacing:12) {
            Button { if let i = hero.items.firstIndex(where:{ $0.id == item.id }) { hero.items[i].equipped.toggle() } } label: { Image(systemName:item.equipped ? "checkmark.square.fill":"square").font(.system(size:15)).foregroundStyle(item.equipped ? accent:Color.secondary) }.buttonStyle(.plain).help("Equip \(item.name)")
            Button { store.itemDetail = ItemPresentation(heroID:hero.id,itemID:item.id,ids:items.map(\.id)) } label: {
                HStack(spacing:12) { VStack(alignment:.leading,spacing:4) { Text(item.name).font(.system(size:13,weight:.medium)); Text(item.equipmentKind.rawValue).font(.system(size:10)).foregroundStyle(.secondary) }; Spacer(minLength:0); if !(item.rolls ?? []).isEmpty { Image(systemName:"dice").foregroundStyle(sky) }; if !(item.bonuses ?? []).isEmpty || item.armorBase != nil { Text("Effects").font(.caption2).foregroundStyle(gold) }; if item.requiresAttunement == true { Text(item.attuned == true ? "Attuned":"Unattuned").font(.caption2).foregroundStyle(item.attuned == true ? sky:coral) }; Text(String(format:"%.1f lb",Double(item.quantity)*item.weight)).font(.system(size:11)).foregroundStyle(.secondary).frame(width:70,alignment:.trailing) }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("Open \(item.name) details")
            Text("×\(item.quantity)").font(.system(size:12,weight:.medium,design:.monospaced)).frame(width:40,alignment:.trailing)
            Menu {
                Button("Edit item") { edit(item) }
                Menu("Move to") {
                    Button("Carried") { hero.placeItem(item.id,in:nil) }
                    ForEach(hero.inventoryContainers) { storage in Button(storage.name) { hero.placeItem(item.id,in:storage.id) }.disabled(item.containerID == storage.id) }
                }
                Button("Remove equipment",role:.destructive) { hero.items.removeAll { $0.id == item.id } }
            } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).frame(width:20).accessibilityLabel("Options for \(item.name)")
        }.padding(.horizontal,10).padding(.vertical,10).background(paper.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius:8))
    }
}
struct ContainerEditor:View {
    @State var storage:EquipmentContainer
    var existing:[EquipmentContainer]
    var save:(EquipmentContainer)->Void
    @Environment(\.dismiss) private var dismiss
    var name:String { storage.name.trimmingCharacters(in:.whitespacesAndNewlines) }
    var valid:Bool { !name.isEmpty && name.count <= 120 && !existing.contains { $0.id != storage.id && $0.name.caseInsensitiveCompare(name) == .orderedSame } }
    var body:some View { VStack(alignment:.leading,spacing:16) {
        Text("Equipment container").font(.title3.bold())
        TextField("Backpack, pouch, camp chest…",text:$storage.name).textFieldStyle(.roundedBorder).onSubmit { commit() }
        Text("Items retain their quantity, weight, equipped state, and modifiers when moved. Removing a container returns its contents to Carried.").font(.caption).foregroundStyle(.secondary)
        HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Save container") { commit() }.buttonStyle(.borderedProminent).disabled(!valid) }
    }.padding(22).frame(width:430).background(surface).foregroundStyle(ink).tint(gold) }
    func commit() { guard valid else { return }; storage.name = name; save(storage); dismiss() }
}
struct ItemDetails:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var presentation:ItemPresentation
    var close:()->Void
    @State private var currentID:UUID?
    @State private var editing = false
    var index:Int? { hero.items.firstIndex { $0.id == (currentID ?? presentation.itemID) } }
    var position:Int { presentation.ids.firstIndex(of:currentID ?? presentation.itemID) ?? 0 }
    var body:some View {
        if let index {
            let item = hero.items[index]
            VStack(alignment:.leading,spacing:16) {
                HStack { Button { navigate(-1) } label: { Image(systemName:"chevron.left") }.disabled(position == 0); Text("\(position+1) / \(presentation.ids.count)").font(.caption).foregroundStyle(.secondary); Button { navigate(1) } label: { Image(systemName:"chevron.right") }.disabled(position >= presentation.ids.count-1); Spacer(); Button("Edit") { editing = true }; Button("Done",action:close) }
                Text(item.name).font(.system(size:23,weight:.semibold))
                HStack { Text(item.equipmentKind.rawValue).foregroundStyle(gold); Text(String(format:"%.1f lb each",item.weight)).foregroundStyle(.secondary); Spacer(); Stepper("×\(item.quantity)",value:$hero.items[index].quantity,in:0...999).frame(width:100) }.font(.caption)
                Text(item.containerID.flatMap { id in hero.inventoryContainers.first { $0.id == id }?.name } ?? "Carried").font(.caption).foregroundStyle(gold)
                HStack { Toggle("Equipped",isOn:$hero.items[index].equipped); if item.requiresAttunement == true { Toggle("Attuned",isOn:Binding(get:{ hero.items[index].attuned ?? false },set:{ hero.items[index].attuned = $0 })) } }.toggleStyle(.checkbox).font(.caption)
                Divider()
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        if !item.notes.isEmpty { Text(item.notes).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }
                        if item.armorBase != nil || !(item.bonuses ?? []).isEmpty { EditorGroup(title:"Configured effects") { if let base = item.armorBase { Text("Base armor AC \(base)").font(.caption) }; ForEach(item.bonuses ?? []) { bonus in Text(bonusSummary(bonus,hero:hero)).font(.caption).foregroundStyle(gold) } } }
                        RollButtons(rolls:item.rolls,hero:hero,store:store,source:item.name,actionSource:SheetActionRef(kind:.itemRoll,sourceID:item.id))
                    }.frame(maxWidth:.infinity,alignment:.leading).padding(.trailing,4)
                }.frame(maxHeight:.infinity)
            }.padding(22).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
            .sheet(isPresented:$editing) { ItemEditor(item:item,hero:hero) { updated in if let i = hero.items.firstIndex(where:{ $0.id == updated.id }) { hero.items[i] = updated } } }
        }
    }
    func navigate(_ direction:Int) { let next = position+direction; guard presentation.ids.indices.contains(next) else { return }; currentID = presentation.ids[next] }
}
