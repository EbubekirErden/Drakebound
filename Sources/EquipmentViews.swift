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
            PageToolbar(title:"Equipment",subtitle:String(format:"%d items · %.1f / %d lb",hero.items.count,hero.items.reduce(0) { $0+Double($1.quantity)*$1.weight },hero.effectiveScore(0)*15),color:gold,searchTitle:"Search equipment",query:$search,focus:$searchFocused) {
                Button { adding=true } label: { Label("Add item",systemImage:"plus") }.buttonStyle(PageButtonStyle(color:gold,prominent:true)).popover(isPresented:$adding) { EquipmentQuickAdd(entries:store.compendium.filter { $0.category == .item }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },onAdd:{ hero.items.append($0) },onCustom:{ edit(Item(name:"",kind:.gear)) }) }
            }
            ControlFlowLayout(spacing:10) {
                PagePicker(title:"Type",selectionTitle:kind,selection:$kind) { Text("All types").tag("All types"); ForEach(types,id:\.self) { Text($0).tag($0) } }
                Toggle("Equipped",isOn:$equippedOnly).toggleStyle(.checkbox).padding(.horizontal,10).frame(height:PageControl.height).background(surface,in:RoundedRectangle(cornerRadius:8))
                CurrencyButton(hero:$hero).buttonStyle(PageButtonStyle())
                Button("New container",systemImage:"shippingbox") { containerEditor = EquipmentContainer(name:"") }.buttonStyle(PageButtonStyle())
                Button("Proficiencies",systemImage:"shield") { trainingOpen = true }.buttonStyle(PageButtonStyle())
                    .popover(isPresented:$trainingOpen) { EquipmentTrainingPopover(hero:$hero) { trainingOpen=false } }
                Button("Compendium",systemImage:"books.vertical") { store.showCompendium = true }.buttonStyle(PageButtonStyle())
            }.font(.system(size:12)).controlSize(.regular)
            if filtering {
                ControlFlowLayout(spacing:6) {
                    if !search.isEmpty { ActiveFilterChip(title:"Search: "+search) { search="" } }
                    if kind != "All types" { ActiveFilterChip(title:kind) { kind="All types" } }
                    if equippedOnly { ActiveFilterChip(title:"Equipped") { equippedOnly=false } }
                    Button("Clear all") { search="";kind="All types";equippedOnly=false }.buttonStyle(.plain).font(.system(size:11)).foregroundStyle(accent)
                    Text("\(items.count) of \(hero.items.count) entries").font(.system(size:11)).foregroundStyle(.secondary)
                }
            }
            LazyVStack(spacing:0) {
                if items.contains(where:{ $0.containerID == nil }) || !filtering { inventoryGroup(nil) }
                ForEach(hero.inventoryContainers) { storage in if !filtering || items.contains(where:{ $0.containerID == storage.id }) { inventoryGroup(storage) } }
            }
            .background(surface,in:RoundedRectangle(cornerRadius:10))
            if items.isEmpty && filtering { CenteredEmptyState("No matching equipment",systemImage:"backpack",description:Text("Try another search, type, or turn off Equipped."),height:220) }
        }
        .sheet(item:$containerEditor) { storage in ContainerEditor(storage:storage,existing:hero.inventoryContainers) { updated in var all = hero.inventoryContainers; if let i = all.firstIndex(where:{ $0.id == updated.id }) { all[i] = updated } else { all.append(updated) }; hero.equipmentContainers = all } }
        .onReceive(store.$commandRequest) { request in if let request,request.action == .search && request.heroID == hero.id && store.activeTab == "Equipment" && !store.showCompendium && store.consume(request) { searchFocused = true } }
    }
    func inventoryGroup(_ storage:EquipmentContainer?) -> some View {
        let group = items.filter { $0.containerID == storage?.id }
        let total = hero.items.filter { $0.containerID == storage?.id }.count
        let open = storage.map { !collapsed.contains($0.id) } ?? true
        return VStack(spacing:0) {
            HStack {
                if let storage { Button { if collapsed.contains(storage.id) { collapsed.remove(storage.id) } else { collapsed.insert(storage.id) } } label: { Label(storage.name,systemImage:open ? "chevron.down":"chevron.right") }.buttonStyle(.plain).accessibilityLabel("\(open ? "Collapse":"Expand") \(storage.name)") }
                else { Label("Carried",systemImage:"backpack") }
                Spacer(); Text(String(format:"%d items · %.1f lb",total,hero.inventoryWeight(in:storage?.id))).font(.caption2).foregroundStyle(.secondary)
                if let storage { Menu { Button("Rename container") { containerEditor = storage }; Button("Remove container · keep items") { hero.removeContainer(storage.id) } } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).frame(width:20) }
            }.font(.system(size:10,weight:.semibold)).foregroundStyle(gold).padding(.horizontal,12).padding(.top,14).padding(.bottom,8)
            if open {
                ForEach(group) { item in itemRow(item);Divider().opacity(0.4).padding(.horizontal,12) }
                if group.isEmpty && !filtering { Text("Empty · move items here from their menu or editor").font(.caption2).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).padding(8) }
            }
        }
    }
    func itemRow(_ item:Item) -> some View {
        let siblings=items.filter { $0.containerID == item.containerID }.map(\.id)
        let position=siblings.firstIndex(of:item.id) ?? 0
        return CombatRowLayout {
            HStack(spacing:8) {
                ListReorderGrip(token:ListReorderToken(kind:.equipment,heroID:hero.id,entryID:item.id,containerID:item.containerID),name:item.name,enabled:siblings.count > 1)
                Button { hero.setItemEquipped(item.id,!item.equipped,compendium:store.compendium) } label: {
                    Image(systemName:item.equipped ? "checkmark.circle.fill":"circle").foregroundStyle(item.equipped ? accent:Color.secondary).frame(width:20,height:26)
                }.buttonStyle(.plain).help((item.equipped ? "Unequip ":"Equip ")+item.name).accessibilityLabel("Toggle equipped for "+item.name).accessibilityValue(item.equipped ? "Equipped":"Carried")
                Button { openItem(item) } label: {
                    ViewThatFits(in:.horizontal) {
                        HStack(spacing:9) { itemName(item);itemType(item).fixedSize() }
                        VStack(alignment:.leading,spacing:3) { itemName(item);itemType(item) }
                    }.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                }.buttonStyle(.plain).help("Open "+item.name+" details").accessibilityLabel(item.name+" details")
            }
            HStack(spacing:9) {
                if !(item.rolls ?? []).isEmpty { Image(systemName:"dice").font(.system(size:11)).foregroundStyle(sky).help("Custom rolls available in item details") }
                if !(item.bonuses ?? []).isEmpty || item.armorBase != nil { Image(systemName:"bolt.circle").font(.system(size:11)).foregroundStyle(gold).help("Configured effects · open item for details") }
                if item.requiresAttunement == true {
                    Button { openItem(item) } label: { Text(item.attuned == true ? "Attuned":"Unattuned").font(.system(size:10)).foregroundStyle(item.attuned == true ? sky:coral) }.buttonStyle(.plain).help("Open item to change attunement")
                }
                Text(String(format:"%.1f lb",Double(item.quantity)*item.weight)).font(.system(size:10)).foregroundStyle(.secondary).monospacedDigit().frame(minWidth:46,alignment:.trailing)
                EquipmentQuantityButton(quantity:Binding(get:{ hero.items.first(where:{ $0.id == item.id })?.quantity ?? item.quantity },set:{ value in
                    if let index=hero.items.firstIndex(where:{ $0.id == item.id }) { hero.items[index].quantity=value }
                }),name:item.name)
            Menu {
                Button("Edit item") { edit(item) }
                Button("Move up in container") { if position > 0 { hero.reorderEquipment(ListReorderToken(kind:.equipment,heroID:hero.id,entryID:item.id,containerID:item.containerID),onto:siblings[position-1],visibleIDs:siblings) } }.disabled(position == 0)
                Button("Move down in container") { if position+1 < siblings.count { hero.reorderEquipment(ListReorderToken(kind:.equipment,heroID:hero.id,entryID:item.id,containerID:item.containerID),onto:siblings[position+1],visibleIDs:siblings) } }.disabled(position+1 >= siblings.count)
                Divider()
                Menu("Move to") {
                    Button("Carried") { hero.placeItem(item.id,in:nil) }
                    ForEach(hero.inventoryContainers) { storage in Button(storage.name) { hero.placeItem(item.id,in:storage.id) }.disabled(item.containerID == storage.id) }
                }
                Button("Remove equipment",role:.destructive) { hero.items.removeAll { $0.id == item.id } }
            } label: { Image(systemName:"ellipsis").frame(width:20,height:26) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().accessibilityLabel("Options for \(item.name)")
            }.fixedSize(horizontal:true,vertical:false)
        }.padding(.horizontal,12).padding(.vertical,6)
            .modifier(ListReorderDropTarget { token in hero.reorderEquipment(token,onto:item.id,visibleIDs:siblings) })
    }
    func openItem(_ item:Item) { store.itemDetail=ItemPresentation(heroID:hero.id,itemID:item.id,ids:items.map(\.id)) }
    func itemName(_ item:Item)->some View { Text(item.name).font(.system(size:12,weight:.medium)).fixedSize(horizontal:false,vertical:true) }
    func itemType(_ item:Item)->some View { Text(item.equipmentKind.rawValue).font(.system(size:10)).foregroundStyle(.secondary) }

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
                        if !item.notes.isEmpty { Text(DescriptionMarkdown.attributed(item.notes)).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }
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

struct EquipmentQuantityButton:View {
    @Binding var quantity:Int
    var name:String
    @State private var open=false
    var body:some View {
        Button { open=true } label: {
            Text("×\(quantity)").font(.system(size:11,weight:.medium,design:.monospaced)).foregroundStyle(gold).frame(minWidth:26,minHeight:26,alignment:.trailing).contentShape(Rectangle())
        }.buttonStyle(.plain).help("Change quantity of "+name).accessibilityLabel("Change quantity of "+name).accessibilityValue(String(quantity))
            .popover(isPresented:$open) { EquipmentQuantityPopup(quantity:$quantity,name:name) }
    }
}

enum EquipmentQuantityOperation:String,CaseIterable { case add="Add",remove="Remove",set="Set" }
struct EquipmentQuantityPopup:View {
    @Binding var quantity:Int
    var name:String
    @State var amount=""
    @State var operation=EquipmentQuantityOperation.add
    @Environment(\.dismiss) private var dismiss
    var result:Int? {
        guard let value=Int(amount.trimmingCharacters(in:.whitespacesAndNewlines)),(0...999).contains(value) else { return nil }
        let next:Int
        switch operation {
        case .add:
            let sum=quantity.addingReportingOverflow(value)
            guard !sum.overflow else { return nil };next=sum.partialValue
        case .remove:
            guard value <= quantity else { return nil };next=quantity-value
        case .set:next=value
        }
        return (0...999).contains(next) ? next:nil
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Text("Quantity").font(.headline);Spacer();Button("Done") { dismiss() } }
            Text(name).font(.system(size:12,weight:.medium)).fixedSize(horizontal:false,vertical:true)
            HStack(spacing:20) {
                Button { quantity=max(0,quantity-1) } label: { Image(systemName:"minus").frame(width:28,height:28) }.disabled(quantity <= 0).accessibilityLabel("Remove one "+name)
                Text("×\(quantity)").font(.system(size:26,weight:.semibold,design:.rounded)).monospacedDigit().foregroundStyle(gold).frame(maxWidth:.infinity)
                Button { quantity=min(999,quantity+1) } label: { Image(systemName:"plus").frame(width:28,height:28) }.disabled(quantity >= 999).accessibilityLabel("Add one "+name)
            }
            Picker("Change",selection:$operation) { ForEach(EquipmentQuantityOperation.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            TextField("Whole number · 0–999",text:$amount).textFieldStyle(.roundedBorder).onSubmit(apply).accessibilityLabel("Quantity amount")
            HStack {
                Text(result.map { "New quantity: \($0)" } ?? (amount.isEmpty ? "Zero keeps the item in inventory":"Enter an amount that leaves 0–999" )).font(.caption2).foregroundStyle(.secondary)
                Spacer();Button("Apply",action:apply).buttonStyle(.borderedProminent).disabled(result == nil)
            }
        }.padding(18).frame(width:320).background(surface).foregroundStyle(ink).tint(gold)
    }
    func apply() { guard let result else { return };quantity=result;amount="" }
}
