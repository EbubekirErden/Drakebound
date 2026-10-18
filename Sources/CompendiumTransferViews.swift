import SwiftUI

struct CompendiumDestination:View {
    @ObservedObject var store:Store
    var request:CompendiumAddRequest
    @State private var destination:UUID?
    @State private var throughLevel = 1
    @State private var result:String?
    @State private var failure:String?
    @Environment(\.dismiss) private var dismiss
    var hasClass:Bool { request.picks.contains { $0.entry?.category == .classEntry } }
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("Add to character").font(.title2.bold()); Spacer(); Button(result == nil ? "Cancel":"Done") { dismiss() } }
            Text("\(request.picks.count) selected \(request.picks.count == 1 ? "entry":"entries")").font(.caption).foregroundStyle(.secondary)
            ScrollView { VStack(alignment:.leading,spacing:4) { ForEach(request.picks) { pick in Text(pick.name).font(.caption).lineLimit(1).frame(maxWidth:.infinity,alignment:.leading) } } }.frame(maxHeight:95)
            Divider()
            ScrollView { VStack(spacing:7) {
                ForEach(store.heroes) { hero in
                    Button { destination = hero.id; throughLevel = request.throughLevel ?? hero.level; failure = nil } label: {
                        HStack(spacing:10) { Portrait(data:hero.portrait,name:hero.name,size:32); VStack(alignment:.leading,spacing:3) { Text(hero.name).font(.system(size:12,weight:.semibold)); Text(hero.characterClass+" · level \(hero.level)").font(.caption2).foregroundStyle(.secondary) }; Spacer(); Image(systemName:destination == hero.id ? "checkmark.circle.fill":"circle").foregroundStyle(destination == hero.id ? accent:Color.secondary) }.padding(10).background((destination == hero.id ? accent.opacity(0.09):surface)).clipShape(RoundedRectangle(cornerRadius:8)).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("Choose "+hero.name).disabled(result != nil)
                }
            } }.frame(maxHeight:.infinity)
            if hasClass { Stepper("Class features through level \(throughLevel)",value:$throughLevel,in:1...20).font(.caption).disabled(result != nil).help("Adds separate reference features through this level. Class levels, ability scores, and prerequisites are not changed.") }
            if let result { Label(result,systemImage:"checkmark.circle.fill").font(.caption).foregroundStyle(accent).fixedSize(horizontal:false,vertical:true) }
            if let failure { Text(failure).font(.caption).foregroundStyle(coral) }
            HStack { Spacer(); Button(destination.flatMap { id in store.heroes.first { $0.id == id } }.map { "Add to "+$0.name } ?? "Choose a character") { add() }.buttonStyle(.borderedProminent).disabled(destination == nil || result != nil) }
        }.padding(22).frame(width:510,height:500).tint(accent)
    }
    func add() {
        guard let index = store.heroes.firstIndex(where:{ $0.id == destination }) else { return }
        do {
            let (hero,summary) = try CompendiumTransfer.applying(request.picks,to:store.heroes[index],through:throughLevel)
            store.heroes[index] = hero; store.save()
            result = summary.text+" added to "+hero.name+"."
        } catch { failure = "Nothing was added. "+error.localizedDescription }
    }
}
