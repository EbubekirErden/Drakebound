import SwiftUI

struct ConditionsPanel: View {
    @Binding var hero: Hero
    @State var manage = false
    private var conditionSummary:String {
        var names=hero.conditions
        if (hero.exhaustionLevel ?? 0) > 0 { names.append("Exhaustion \(hero.exhaustionLevel ?? 0)") }
        return names.isEmpty ? "No active conditions":names.joined(separator:", ")
    }
    var body: some View {
        SheetCard(title:"Conditions",summary:conditionSummary) {
            HStack {
                Text(hero.conditions.isEmpty && (hero.exhaustionLevel ?? 0) == 0 ? "No active conditions":"Effects update tracked stats and typed rolls").font(.system(size:11)).foregroundStyle(.secondary)
                Spacer()
                Button("Manage") { manage = true }
            }
            if !hero.conditions.isEmpty {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:120))],alignment:.leading,spacing:6) {
                    ForEach(hero.conditions,id:\.self) { name in
                        Button { hero.conditions.removeAll { $0 == name } } label: { HStack { Text(name).font(.system(size:11)); Image(systemName:"xmark").font(.system(size:8)) }.padding(.horizontal,9).padding(.vertical,6).background(coral.opacity(0.12)).clipShape(Capsule()) }.buttonStyle(.plain).foregroundStyle(coral).help("Remove \(name)")
                    }
                }
            }
            if (hero.exhaustionLevel ?? 0) > 0 { Text("Exhaustion \(hero.exhaustionLevel ?? 0) · \(hero.edition) rules").font(.system(size:11,weight:.medium)).foregroundStyle(gold) }
        }.sheet(isPresented:$manage) { ConditionsEditor(hero:$hero) }
    }
}
struct ConditionsEditor: View {
    @Binding var hero: Hero
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("Conditions & effects").font(.headline); Spacer(); Button("Done") { dismiss() } }
            Picker("Rules",selection:Binding(get:{ hero.edition },set:{ hero.rulesEdition = $0 })) { Text("2014").tag("2014"); Text("2024").tag("2024") }.pickerStyle(.segmented)
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    ForEach(conditionDefinitions) { condition in
                        VStack(alignment:.leading,spacing:5) {
                            Toggle(condition.name,isOn:Binding(get:{ hero.hasCondition(condition.name) },set:{ enabled in hero.conditions.removeAll { $0.caseInsensitiveCompare(condition.name) == .orderedSame }; if enabled { hero.conditions.append(condition.name) }; if hero.isIncapacitated { hero.endConcentration() } })).toggleStyle(.checkbox).font(.system(size:13,weight:.medium))
                            Text(condition.summary).font(.system(size:12)).foregroundStyle(ink)
                            Text(condition.reminder).font(.system(size:11)).foregroundStyle(.secondary)
                            if condition.name == "Frightened" && hero.hasCondition("Frightened") { Toggle("Fear source is visible",isOn:Binding(get:{ hero.fearSourceVisible ?? false },set:{ hero.fearSourceVisible = $0 })).font(.caption) }
                            if condition.name == "Invisible" && hero.hasCondition("Invisible") { Toggle("Current target cannot see you",isOn:Binding(get:{ hero.invisibleToTarget ?? false },set:{ hero.invisibleToTarget = $0 })).font(.caption) }
                        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(surface).clipShape(RoundedRectangle(cornerRadius:8))
                    }
                    Card(title:"Exhaustion") {
                        Stepper("Level \(hero.exhaustionLevel ?? 0)",value:Binding(get:{ hero.exhaustionLevel ?? 0 },set:{ hero.exhaustionLevel = $0 }),in:0...6)
                        Text(hero.edition == "2024" ? "−2 per level on typed D20 tests; −5 ft per level. Level 6 is fatal." : "Cumulative: checks DIS at 1; half speed at 2; attacks/saves DIS at 3; half maximum HP at 4; no movement at 5; death at 6.").font(.system(size:11)).foregroundStyle(.secondary)
                    }
                    Text("Automatic: self attack/check/save modifiers, movement, 2014 HP maximum, and action restrictions. Incoming damage, target-dependent restrictions, senses, and critical hits remain table decisions. Generic custom rolls apply only your chosen ADV/DIS; assign a roll category to receive condition effects.").font(.caption).foregroundStyle(.secondary)
                    HStack { Link("2014 rules",destination:URL(string:"https://www.dndbeyond.com/sources/dnd/basic-rules-2014/appendix-a-conditions")!); Link("2024 rules",destination:URL(string:"https://www.dndbeyond.com/sources/dnd/br-2024/rules-glossary")!) }.font(.caption)
                }
            }
        }.padding(22).frame(width:600,height:720).tint(accent)
    }
}
