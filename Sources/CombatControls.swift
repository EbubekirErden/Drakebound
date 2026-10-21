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
    init(hero:Binding<Hero>,store:Store,initialRest:CounterReset = .shortRest) {
        _hero = hero;self.store = store;_selected = State(initialValue:initialRest)
    }
    var preview:RestPreview { RestPreview(hero:hero,event:selected) }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("Rest & recovery").font(.title3.bold()); Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
            Picker("Rest",selection:$selected) {
                Text("Short rest").tag(CounterReset.shortRest)
                Text("Long rest").tag(CounterReset.longRest)
                Text("Full rest").tag(CounterReset.fullRest)
            }.pickerStyle(.segmented).labelsHidden()
            VStack(alignment:.leading,spacing:10) {
                ForEach(preview.rows) { row in
                    HStack(alignment:.firstTextBaseline,spacing:16) {
                        Text(row.title).foregroundStyle(.secondary)
                        Spacer(minLength:8)
                        Text(row.value).multilineTextAlignment(.trailing).fixedSize(horizontal:false,vertical:true)
                    }
                    if row.id != preview.rows.last?.id { Divider().opacity(0.5) }
                }
            }.font(.system(size:12)).padding(14).background(surface,in:RoundedRectangle(cornerRadius:9))
            if !preview.resources.isEmpty {
                HStack(alignment:.top,spacing:8) {
                    Text("Refills").foregroundStyle(.secondary)
                    ScrollView { Text(preview.resources.joined(separator:", ")).frame(maxWidth:.infinity,alignment:.leading).fixedSize(horizontal:false,vertical:true) }.frame(maxHeight:65)
                }.font(.system(size:11))
            }
            Text(preview.note).font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            HStack {
                Spacer()
                Button("Complete \(selected.rawValue.lowercased())") {
                    let names = preview.resources.count
                    hero = preview.after
                    store.record(RollResult(label:selected.rawValue,expression:"Recovery completed · \(names) configured resources",dice:[],total:0,event:true))
                    store.captureActivity()
                    if store.notice?.activityID == nil { store.notify("\(selected.rawValue) completed",heroID:hero.id) }
                    dismiss()
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width:480).background(paper).foregroundStyle(ink).tint(accent)
    }
}
