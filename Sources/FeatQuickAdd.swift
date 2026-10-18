import SwiftUI

struct FeatQuickAdd:View {
    @Binding var hero:Hero
    var entries:[CompendiumEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var query=""
    @State private var source=CompendiumScope.all
    @State private var preview:CompendiumEntry?
    @State private var error:String?
    var matches:[CompendiumEntry] { entries.filter { (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) && source.includes($0) } }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { VStack(alignment:.leading,spacing:3) { Text("Browse feats").font(.headline);Text("Adding to "+hero.name).font(.caption).foregroundStyle(sky) };Spacer();Button("Done") { dismiss() } }
            TextField("Search compendium feats",text:$query).textFieldStyle(.roundedBorder)
            Picker("Source",selection:$source) { ForEach(CompendiumScope.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.font(.caption)
            GeometryReader { geometry in ScrollView { LazyVStack(spacing:6) {
                ForEach(matches.prefix(80)) { entry in
                    let copies=entry.featureCopies()
                    let owned = !copies.isEmpty && copies.allSatisfy { copy in (hero.featureEntries ?? []).contains { $0.name == copy.name && $0.source == copy.source && $0.text == copy.text } }
                    HStack(spacing:10) {
                        Button { preview=entry } label: { VStack(alignment:.leading,spacing:4) { Text(entry.name).font(.system(size:12,weight:.medium));Text(entry.sourceDescription).font(.caption2).foregroundStyle(sky).lineLimit(1);if !entry.value("prerequisite").isEmpty { Text(entry.value("prerequisite")).font(.caption2).foregroundStyle(.secondary).lineLimit(2) } }.frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain).help("Preview "+entry.name)
                        Button(owned ? "Added":"Add") { do { let result=try CompendiumTransfer.applying([CompendiumPick(entry)],to:hero,through:hero.level);hero=result.0;error=nil } catch { self.error=error.localizedDescription } }.disabled(owned).accessibilityLabel((owned ? "Added ":"Add ")+entry.name)
                    }.padding(10).background(paper).clipShape(RoundedRectangle(cornerRadius:7))
                }
                if matches.isEmpty { CenteredEmptyState("No matching feats",systemImage:"books.vertical",description:Text(entries.isEmpty ? "Import a compendium with feats to browse them here.":"Try another search or source.")).frame(width:geometry.size.width,height:geometry.size.height) }
                if matches.count > 80 { Text("\(matches.count) matches · narrow your search").font(.caption2).foregroundStyle(.secondary) }
            } } }
            if let error { Text(error).font(.caption).foregroundStyle(coral) }
        }.padding(16).frame(width:470,height:460).background(surface).foregroundStyle(ink).tint(accent).sheet(item:$preview) { GuideReferencePreview(entry:$0) }
    }
}
