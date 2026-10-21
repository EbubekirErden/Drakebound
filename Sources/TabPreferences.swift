import SwiftUI

enum CharacterTabs {
    static let all = [("Sheet","person.text.rectangle"),("Combat","bolt.shield"),("Equipment","backpack"),("Spells","sparkles"),("Journal","book.closed"),("Creatures","pawprint")]
    static let optional = Array(all.dropFirst(2))
}

extension Store {
    func tabIsVisible(_ title:String) -> Bool {
        guard let selected else { return true }
        return !(hiddenTabsByHero[selected.uuidString] ?? []).contains(title)
    }
    func setTabVisible(_ title:String,_ visible:Bool) {
        guard let selected,CharacterTabs.optional.contains(where:{ $0.0 == title }) else { return }
        var hidden = hiddenTabsByHero[selected.uuidString] ?? []
        hidden.removeAll { $0 == title }
        if !visible { hidden.append(title) }
        hiddenTabsByHero[selected.uuidString] = hidden
        if !visible && activeTab == title { activeTab = "Sheet" }
        // Interface preferences never enter portable character archives or isolated fixtures.
        if file.standardizedFileURL == Store.liveFile.standardizedFileURL {
            UserDefaults.standard.set(hiddenTabsByHero,forKey:"hiddenTabsByHero")
        }
    }
}

struct CharacterTabsMenu:View {
    @ObservedObject var store:Store
    @State private var customizing=false
    var body:some View {
        Menu {
            ForEach(Array(CharacterTabs.all.enumerated()),id:\.offset) { index,tab in
                Button(tab.0+"  ⌘\(index+1)") { store.navigate(to:tab.0) }
            }
            Divider()
            Button("Customize tabs…") { customizing=true }
        } label: { Label("Tabs",systemImage:"slider.horizontal.3").font(.system(size:12)) }
            .menuStyle(.borderlessButton).fixedSize().padding(.horizontal,12)
            .popover(isPresented:$customizing) {
                VStack(alignment:.leading,spacing:14) {
                    HStack { Text("Visible tabs").font(.headline);Spacer();Button("Done") { customizing=false } }
                    Text(store.heroes.first(where:{ $0.id == store.selected })?.name ?? "This character").font(.caption).foregroundStyle(.secondary)
                ForEach(CharacterTabs.optional,id:\.0) { title,_ in
                    Toggle(title,isOn:Binding(get:{ store.tabIsVisible(title) },set:{ store.setTabVisible(title,$0) }))
                }
                Divider()
                Button("Show all tabs") { for (title,_) in CharacterTabs.optional { store.setTabVisible(title,true) } }
                    Text("Sheet and Combat always stay visible. ⌘1–⌘7 keep their destinations, including hidden tabs.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                }.padding(18).frame(width:300)
            }
            .help("Open any tab or choose which tabs appear for this character. Keyboard shortcuts stay the same.")
    }
}
