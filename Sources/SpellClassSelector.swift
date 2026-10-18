import SwiftUI

struct SpellClassSelector: View {
    @Binding var classes: String
    var options: [String] = []
    @State private var choosing = false
    @State private var query = ""

    private var selected: [String] {
        classes.components(separatedBy:",").map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    private var choices: [String] {
        let names = ClassProfile.all.map(\.name) + options + selected
        var seen = Set<String>()
        return names.filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    private func contains(_ name: String) -> Bool {
        selected.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }
    private func set(_ name: String, selected include: Bool) {
        var values = selected.filter { $0.caseInsensitiveCompare(name) != .orderedSame }
        if include { values.append(name) }
        classes = values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.joined(separator:", ")
    }

    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text("Available class lists").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { query = ""; choosing = true } label: { Label("Choose classes",systemImage:"list.bullet") }
                    .buttonStyle(PageButtonStyle())
                    .popover(isPresented:$choosing) {
                        VStack(alignment:.leading,spacing:12) {
                            HStack { Text("Available class lists").font(.headline); Spacer(); Button("Done") { choosing = false } }
                            PageSearchField(title:"Search classes",query:$query)
                            ScrollView {
                                LazyVStack(alignment:.leading,spacing:10) {
                                    ForEach(choices.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) },id:\.self) { name in
                                        Toggle(name,isOn:Binding(get:{ contains(name) },set:{ set(name,selected:$0) }))
                                            .toggleStyle(.checkbox).frame(maxWidth:.infinity,alignment:.leading)
                                    }
                                    if !query.isEmpty && !choices.contains(where:{ $0.localizedCaseInsensitiveContains(query) }) {
                                        Text("No matching classes").foregroundStyle(.secondary)
                                    }
                                }.padding(4)
                            }
                            Text("Select all classes that can learn this spell.").font(.caption).foregroundStyle(.secondary)
                        }.padding(16).frame(width:300,height:350).tint(sky)
                    }
            }
            Text(selected.isEmpty ? "No class lists selected":selected.joined(separator:", "))
                .font(.system(size:12)).foregroundStyle(selected.isEmpty ? Color.secondary:ink)
                .fixedSize(horizontal:false,vertical:true)
        }
    }
}
