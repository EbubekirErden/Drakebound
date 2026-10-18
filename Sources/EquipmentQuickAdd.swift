import SwiftUI

struct EquipmentQuickAdd:View {
    var entries:[CompendiumEntry]
    var onAdd:(Item)->Void
    var onCustom:()->Void
    @Environment(\.dismiss) private var dismiss
    @State private var query=""
    @State private var kind="All types"
    @State private var source=CompendiumScope.all
    @State private var preview:CompendiumEntry?
    var matches:[CompendiumEntry] { entries.filter { (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) && (kind == "All types" || $0.subcategory == kind) && source.includes($0) } }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Text("Add equipment").font(.headline);Spacer();Button("Custom item") { dismiss();onCustom() };Button("Done") { dismiss() } }
            TextField("Search compendium equipment",text:$query).textFieldStyle(.roundedBorder)
            HStack { Picker("Type",selection:$kind) { Text("All types").tag("All types");ForEach(Array(Set(entries.map(\.subcategory))).sorted(),id:\.self) { Text($0).tag($0) } };Picker("Source",selection:$source) { ForEach(CompendiumScope.allCases,id:\.self) { Text($0.rawValue).tag($0) } } }.labelsHidden().font(.caption)
            GeometryReader { geometry in ScrollView { LazyVStack(spacing:6) {
                ForEach(matches.prefix(80)) { entry in HStack { Button { preview=entry } label: { VStack(alignment:.leading,spacing:4) { Text(entry.name).font(.system(size:12,weight:.medium));Text(entry.summary).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }.frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain);Button("Add") { onAdd(entry.equippedItemCopy());dismiss() }.accessibilityLabel("Add "+entry.name) }.padding(10).background(paper).clipShape(RoundedRectangle(cornerRadius:7)) }
                if matches.isEmpty { CenteredEmptyState("No matching equipment",systemImage:"backpack",description:Text("Try another search, type, or source.")).frame(width:geometry.size.width,height:geometry.size.height) }
                if matches.count > 80 { Text("\(matches.count) matches · narrow your search").font(.caption2).foregroundStyle(.secondary) }
            } } }
        }.padding(16).frame(width:470,height:440).background(surface).foregroundStyle(ink).tint(gold).sheet(item:$preview) { GuideReferencePreview(entry:$0) }
    }
}
extension CompendiumEntry {
    func equippedItemCopy() -> Item {
        var copy=item()
        if template?.item == nil,let ac=Int(value("ac")) {
            if copy.equipmentKind == .shield { copy.bonuses=[Bonus(name:name,target:"ac",amount:ac)] }
            else if [.lightArmor,.mediumArmor,.heavyArmor].contains(copy.equipmentKind) { copy.armorBase=ac;copy.armorAddsDexterity=copy.equipmentKind != .heavyArmor;copy.armorDexterityCap=copy.equipmentKind == .mediumArmor ? 2:20 }
        }
        return copy
    }
}
