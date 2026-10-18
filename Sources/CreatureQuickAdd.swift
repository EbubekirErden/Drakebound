import SwiftUI

struct CreatureQuickAdd:View {
    var entries:[CompendiumEntry]
    var characterName:String
    var onAdd:(Creature)->Void
    var onCustom:()->Void
    @Environment(\.dismiss) private var dismiss
    @State private var query=""
    @State private var type="All types"
    @State private var challenge="All CRs"
    @State private var source=CompendiumScope.all
    @State private var role="Companion"
    @State private var preview:CompendiumEntry?
    var matches:[CompendiumEntry] { entries.filter { (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) && (type == "All types" || $0.subcategory == type) && (challenge == "All CRs" || $0.value("cr") == challenge) && source.includes($0) } }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { VStack(alignment:.leading,spacing:3) { Text("Add creature").font(.headline);Text("Adding to "+characterName).font(.caption).foregroundStyle(sky) };Spacer();Button("Custom creature") { dismiss();onCustom() };Button("Done") { dismiss() } }
            TextField("Search compendium creatures",text:$query).textFieldStyle(.roundedBorder)
            HStack { Picker("Type",selection:$type) { Text("All types").tag("All types");ForEach(Array(Set(entries.map(\.subcategory))).sorted(),id:\.self) { Text($0).tag($0) } };Picker("CR",selection:$challenge) { Text("All CRs").tag("All CRs");ForEach(Array(Set(entries.map { $0.value("cr") }.filter { !$0.isEmpty })).sorted { $0.localizedStandardCompare($1) == .orderedAscending },id:\.self) { Text("CR "+$0).tag($0) } };Picker("Source",selection:$source) { ForEach(CompendiumScope.allCases,id:\.self) { Text($0.rawValue).tag($0) } } }.labelsHidden().font(.caption)
            Picker("Add as",selection:$role) { ForEach(["Companion","Familiar","Summon","Encounter"],id:\.self) { Text($0).tag($0) } }.font(.caption)
            GeometryReader { geometry in ScrollView { LazyVStack(spacing:6) {
                ForEach(matches.prefix(80)) { entry in HStack(spacing:10) {
                    Button { preview=entry } label: { VStack(alignment:.leading,spacing:4) { Text(entry.name).font(.system(size:12,weight:.medium));Text(entry.summary).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }.frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain).help("Preview "+entry.name)
                    Button("Add") { var creature=entry.creature();creature.kind=role;onAdd(creature);dismiss() }.accessibilityLabel("Add "+entry.name)
                }.padding(10).background(paper).clipShape(RoundedRectangle(cornerRadius:7)) }
                if matches.isEmpty { CenteredEmptyState("No matching creatures",systemImage:"pawprint",description:Text(entries.isEmpty ? "Import a compendium with creatures or create a custom creature.":"Try another search, type, CR, or source.")).frame(width:geometry.size.width,height:geometry.size.height) }
                if matches.count > 80 { Text("\(matches.count) matches · narrow your search").font(.caption2).foregroundStyle(.secondary) }
            } } }
        }.padding(16).frame(width:570,height:480).background(surface).foregroundStyle(ink).tint(leaf).sheet(item:$preview) { GuideReferencePreview(entry:$0) }
    }
}
