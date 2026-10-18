import SwiftUI

/// A click rolls immediately; holding or right-clicking chooses a mode for this roll only.
struct RollChoiceButton<LabelView:View>: View {
    var enabled = true
    var explanation:String? = nil
    var action:(RollMode?)->Void
    @ViewBuilder var label:()->LabelView
    @State private var choosing = false
    var body: some View {
        Button { action(nil) } label: { label().contentShape(Rectangle()) }
            .buttonStyle(.plain)
            .highPriorityGesture(LongPressGesture(minimumDuration:0.45).exclusively(before:TapGesture()).onEnded { value in
                switch value { case .first: if enabled { choosing = true } else { action(nil) }; case .second: action(nil) }
            })
            .contextMenu { if enabled { choices } }
            .popover(isPresented:$choosing,arrowEdge:.bottom) {
                VStack(alignment:.leading,spacing:12) {
                    Text("Roll once with…").font(.headline)
                    choices
                    Text("Combines with active condition effects. Your default stays unchanged.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                }.padding(16).frame(width:245)
            }.help(explanation ?? (enabled ? "Click to roll · hold or right-click for advantage / disadvantage":"Click to roll"))
    }
    @ViewBuilder var choices: some View {
        ForEach(RollMode.allCases,id:\.self) { mode in
            Button { choosing = false; action(mode) } label: {
                HStack { Image(systemName:mode == .normal ? "die.face.1":mode == .advantage ? "arrow.up":"arrow.down").frame(width:18); Text(mode == .normal ? "Normal":mode == .advantage ? "Advantage":"Disadvantage"); Spacer() }.padding(.vertical,5).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
    }
}

struct CounterResetPicker: View {
    @Binding var counter: ResourceCounter
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Text("Refill on these rests").font(.system(size:12,weight:.medium))
            ForEach([CounterReset.shortRest,.longRest,.fullRest],id:\.self) { event in
                Toggle(event.rawValue,isOn:Binding(get:{ counter.restEvents.contains(event) },set:{ flag in
                    var events = counter.restEvents; events.removeAll { $0 == event }; if flag { events.append(event) }; counter.restEvents = events
                })).toggleStyle(.checkbox)
            }
            Text("Select each rest independently. None selected means manual reset.").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

enum HealthAdjustment: String, Identifiable { case damage = "Take damage", healing = "Restore HP", temporary = "Temporary HP"; var id:String { rawValue } }
struct HealthAmountPopup: View {
    @Binding var hero: Hero
    var adjustment: HealthAdjustment
    @State private var amount = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss
    var value: Int? { guard let n = Int(amount), (0...(adjustment == .temporary ? 999:9999)).contains(n) else { return nil }; return n }
    var color: Color { adjustment == .damage ? coral:adjustment == .healing ? leaf:sky }
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Text(adjustment.rawValue).font(.headline)
            HStack(alignment:.firstTextBaseline) {
                TextField("Amount",text:$amount).textFieldStyle(.plain).font(.system(size:32,weight:.semibold,design:.rounded)).focused($focused).frame(width:160).onSubmit(apply)
                Text("HP").foregroundStyle(.secondary)
            }.padding(12).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:10))
            HStack(spacing:8) { ForEach([1,5,10,20],id:\.self) { n in Button("+\(n)") { amount = String(min(adjustment == .temporary ? 999:9999,(value ?? 0)+n)) } } }
            Text(adjustment == .damage ? "Temporary HP absorbs damage first." : adjustment == .healing ? "Healing is capped at your maximum HP." : "Sets temporary HP to this amount; it does not stack.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            if adjustment == .damage,hero.concentratingSpell != nil { Text("A pending concentration save will appear after damage. Enter damage after resistance or other reductions; temporary HP still counts.").font(.caption2).foregroundStyle(sky).fixedSize(horizontal:false,vertical:true) }
            HStack { if adjustment == .temporary { Button("Clear") { hero.tempHP = 0; dismiss() } }; Spacer(); Button("Cancel") { dismiss() }; Button(adjustment == .temporary ? "Set HP":"Apply",action:apply).buttonStyle(.borderedProminent).disabled(value == nil) }
        }.padding(18).frame(width:300).tint(color).onAppear { focused = true }
    }
    func apply() {
        guard let value else { return }
        switch adjustment { case .damage: hero.damage(value); case .healing: hero.hp = min(hero.maximumHP,hero.hp+value); case .temporary: hero.tempHP = value }
        dismiss()
    }
}

struct HitDicePopup: View {
    @Binding var hero: Hero
    @ObservedObject var store: Store
    @State private var count = 1
    @State private var selected: UUID?
    @State private var lastResult = ""
    var pools: [HitDicePool] { hero.hitDicePools ?? [] }
    var pool: HitDicePool? { pools.first { $0.id == selected } ?? pools.first }
    var available: Int { pool.map { $0.total-$0.used } ?? max(0,hero.level-hero.hitDiceUsed) }
    var sides: Int { pool?.sides ?? hero.hitDie }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Spend hit dice").font(.headline)
            if !pools.isEmpty {
                HStack { ForEach(pools) { p in Button { selected = p.id; count = 1 } label: { VStack(spacing:4) { Text("d\(p.sides)").font(.system(size:20,weight:.semibold)); Text(p.name).font(.caption2).lineLimit(1); Text("\(p.total-p.used) / \(p.total) left").font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth:.infinity).padding(10).background((pool?.id == p.id ? accent:Color.gray).opacity(0.12)).clipShape(RoundedRectangle(cornerRadius:8)) }.buttonStyle(.plain) } }
            }
            HStack { Text("\(max(0,available)) dice available"); Spacer(); Stepper("Spend \(count)",value:$count,in:1...max(1,available)).fixedSize() }.font(.caption)
            Text("Each d\(sides) adds CON \(signed(hero.modifier(2))). Healing is applied immediately.").font(.caption).foregroundStyle(.secondary)
            Button("Roll \(count)d\(sides) & heal",action:spend).buttonStyle(.borderedProminent).disabled(available < count)
            if !lastResult.isEmpty { Text(lastResult).font(.caption).foregroundStyle(leaf) }
        }.padding(18).frame(width:350).tint(accent)
    }
    func spend() {
        do { let previous = hero.hp; let r = try hero.spendHitDice(pool?.id,count:count); store.record(r); lastResult = "Recovered \(hero.hp-previous) HP · \(hero.hp) / \(hero.maximumHP)"; count = min(count,max(1,available)) }
        catch { store.error = error.localizedDescription }
    }
}

struct RestEditor: View {
    @Binding var hero: Hero
    @ObservedObject var store: Store
    @State private var selected = CounterReset.shortRest
    @Environment(\.dismiss) private var dismiss
    var names: [String] {
        (hero.counters ?? []).filter { $0.restEvents.contains(selected) }.map(\.name) + (hero.featureEntries ?? []).filter { $0.counter?.restEvents.contains(selected) == true }.map(\.name)
    }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack { Text("Rest & recovery").font(.title2.bold()); Spacer(); Button("Cancel") { dismiss() } }
            HStack(spacing:10) { restCard(.shortRest,"cup.and.saucer","Hit dice & selected uses"); restCard(.longRest,"moon.stars","HP, slots & recovery"); restCard(.fullRest,"sun.max","Complete recovery") }
            VStack(alignment:.leading,spacing:10) {
                Text("\(selected.rawValue) preview").font(.headline)
                Text(selected == .shortRest ? "Spend hit dice before or after this rest using Hit dice. Completing a short rest refills only counters you assigned to it. Spell slots also recover when short-rest slot recovery is enabled." : selected == .longRest ? "Restore HP and spell slots; clear temporary HP and death saves; restore spell free uses; reduce exhaustion by one. Recover \(hero.edition == "2024" ? "all":"half your total") hit dice using \(hero.edition) rules." : "House-rule full recovery: restore HP, spell slots, all hit dice, and spell free uses; clear temporary HP, death saves, and all exhaustion. Counters use their separate Full rest setting.").font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                if selected == .shortRest && hero.slotsRecoverOnShortRest == true { Label("Spell slots will recover",systemImage:"sparkles").font(.caption).foregroundStyle(sky) }
                Divider()
                Text("Counters that will refill").font(.system(size:12,weight:.semibold))
                if names.isEmpty { Text("None assigned to this rest").foregroundStyle(.secondary).font(.caption) }
                else { ScrollView { VStack(alignment:.leading,spacing:7) { ForEach(Array(names.enumerated()),id:\.offset) { _,name in Label(name,systemImage:"arrow.clockwise").font(.caption) } }.frame(maxWidth:.infinity,alignment:.leading) }.frame(maxHeight:120) }
                Text("Change reset rules in a counter or feature’s editor. Rest types are independent.").font(.caption2).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(surface).clipShape(RoundedRectangle(cornerRadius:10))
            HStack { Spacer(); Button("Complete \(selected.rawValue.lowercased())") {
                switch selected { case .shortRest: hero.resetCounters(for:.shortRest); case .longRest: hero.longRest(); case .fullRest: hero.fullRest(); case .manual: break }
                store.record(RollResult(label:selected.rawValue,expression:"Recovery completed · \(names.count) configured counters",dice:[],total:0,event:true)); dismiss()
            }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(width:620).tint(accent)
    }
    func restCard(_ rest:CounterReset,_ icon:String,_ description:String) -> some View {
        Button { selected = rest } label: { VStack(spacing:9) { Image(systemName:icon).font(.system(size:23)).foregroundStyle(rest == .shortRest ? gold:rest == .longRest ? sky:leaf); Text(rest.rawValue).font(.system(size:13,weight:.semibold)); Text(description).font(.system(size:9)).foregroundStyle(.secondary) }.frame(maxWidth:.infinity).frame(height:98).background((selected == rest ? accent:Color.gray).opacity(0.09)).clipShape(RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(selected == rest ? accent:.clear)) }.buttonStyle(.plain)
    }
}
