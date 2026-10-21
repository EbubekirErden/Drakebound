import SwiftUI

struct SheetConditionSummary:View {
    var hero:Hero
    @ObservedObject var store:Store
    var body:some View {
        if !hero.conditions.isEmpty || (hero.exhaustionLevel ?? 0) > 0 {
            ControlFlowLayout(spacing:8) {
                if !hero.conditions.isEmpty { Label(hero.conditions.joined(separator:", "),systemImage:"waveform.path.ecg").foregroundStyle(coral) }
                if (hero.exhaustionLevel ?? 0) > 0 { Text("Exhaustion \(hero.exhaustionLevel!)").foregroundStyle(gold) }
                Button("Manage in Combat") { store.navigate(to:"Combat") }.buttonStyle(.plain).foregroundStyle(accent)
            }.font(.system(size:11)).frame(maxWidth:.infinity,alignment:.leading)
        }
    }
}

struct ConditionsEditor:View {
    @Binding var hero:Hero
    @Environment(\.dismiss) private var dismiss
    @State private var info:ConditionDefinition?
    @State private var reference=false
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text("Conditions").font(.title3.bold());Spacer()
                Picker("Rules",selection:Binding(get:{ hero.edition },set:{ hero.rulesEdition=$0 })) { Text("2014").tag("2014");Text("2024").tag("2024") }.labelsHidden().frame(width:85)
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            LazyVGrid(columns:[GridItem(.flexible(),alignment:.leading),GridItem(.flexible(),alignment:.leading)],spacing:8) {
                ForEach(conditionDefinitions) { condition in
                    HStack(spacing:6) {
                        Toggle(condition.name,isOn:Binding(get:{ hero.hasCondition(condition.name) },set:{ active in
                            hero.conditions.removeAll { $0.caseInsensitiveCompare(condition.name) == .orderedSame }
                            if active { hero.conditions.append(condition.name) }
                            if hero.isIncapacitated { hero.endConcentration() }
                        })).toggleStyle(.checkbox).font(.system(size:12)).frame(maxWidth:.infinity,alignment:.leading)
                        Button { info=condition } label: { Image(systemName:"questionmark.circle").font(.system(size:11)).foregroundStyle(ink.opacity(0.5)).frame(width:22,height:24) }.buttonStyle(.plain).accessibilityLabel(condition.name+" rules")
                    }.padding(.horizontal,8).padding(.vertical,4).background(surface,in:RoundedRectangle(cornerRadius:6))
                }
            }
            HStack {
                Text("Exhaustion").font(.system(size:12,weight:.medium));Spacer()
                Picker("Exhaustion level",selection:Binding(get:{ hero.exhaustionLevel ?? 0 },set:{ hero.exhaustionLevel=$0 })) {
                    ForEach(0...6,id:\.self) { Text($0 == 0 ? "None":"Level \($0)").tag($0) }
                }.labelsHidden().frame(width:110)
            }.padding(10).background(surface,in:RoundedRectangle(cornerRadius:7))
            if hero.hasCondition("Frightened") || hero.hasCondition("Invisible") {
                VStack(alignment:.leading,spacing:8) {
                    if hero.hasCondition("Frightened") { Toggle("Fear source is visible",isOn:Binding(get:{ hero.fearSourceVisible ?? false },set:{ hero.fearSourceVisible=$0 })).accessibilityLabel("Fear source is visible") }
                    if hero.hasCondition("Invisible") { Toggle("Current target cannot see you",isOn:Binding(get:{ hero.invisibleToTarget ?? false },set:{ hero.invisibleToTarget=$0 })) }
                }.font(.system(size:11)).toggleStyle(.checkbox)
            }
            HStack {
                Button("Rules reference",systemImage:"books.vertical") { reference=true }.buttonStyle(.plain).foregroundStyle(accent)
                Spacer()
                Text("Also in Compendium → Conditions").foregroundStyle(.secondary)
            }.font(.system(size:11))
        }.padding(20).frame(width:470).background(paper).foregroundStyle(ink).tint(accent)
            .popover(item:$info) { condition in ConditionRuleDetail(condition:condition).padding(18).frame(width:330).background(surface).foregroundStyle(ink) }
            .sheet(isPresented:$reference) { ConditionsReference() }
    }
}

struct ConditionRuleDetail:View {
    var condition:ConditionDefinition
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text(condition.name).font(.system(size:13,weight:.semibold))
            Text(condition.summary).font(.system(size:12))
            Text(condition.reminder).font(.system(size:11)).foregroundStyle(.secondary)
        }.frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled)
    }
}

struct ConditionsReference:View {
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("Conditions reference").font(.title3.bold());Spacer();Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    ForEach(conditionDefinitions) { condition in ConditionRuleDetail(condition:condition).padding(12).background(surface,in:RoundedRectangle(cornerRadius:8)) }
                    VStack(alignment:.leading,spacing:8) {
                        Text("Exhaustion").font(.system(size:13,weight:.semibold))
                        Text("2014: cumulative check disadvantage at 1; half speed at 2; attack/save disadvantage at 3; half maximum HP at 4; no movement at 5; death at 6.")
                        Text("2024: −2 per level on typed D20 tests and −5 ft per level. Level 6 is fatal.")
                    }.font(.system(size:12)).padding(12).background(surface,in:RoundedRectangle(cornerRadius:8))
                    Text("Tracked effects update your stats and typed rolls. Incoming damage, target-dependent restrictions, senses and critical hits remain table decisions. Generic custom rolls use your selected ADV/DIS; assign a roll category for condition effects.").font(.system(size:11)).foregroundStyle(.secondary)
                }
            }
            HStack {
                Link("2014 rules",destination:URL(string:"https://www.dndbeyond.com/sources/dnd/basic-rules-2014/appendix-a-conditions")!)
                Link("2024 rules",destination:URL(string:"https://www.dndbeyond.com/sources/dnd/br-2024/rules-glossary")!)
            }.font(.system(size:11))
        }.padding(20).frame(width:520,height:500).background(paper).foregroundStyle(ink).tint(accent)
    }
}
