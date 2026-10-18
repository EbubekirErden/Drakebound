import SwiftUI

struct SpellUpcastEditor: View {
    @Binding var roll: NamedRoll
    var spell: Spell
    var rule: Binding<UpcastDice> { Binding(get:{ roll.upcast ?? UpcastDice() },set:{ roll.upcast = $0 }) }
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            Toggle("Automatic upcasting",isOn:Binding(get:{ roll.upcast != nil },set:{ roll.upcast = $0 ? UpcastDice():nil }))
                .disabled(roll.kind != nil && roll.upcast == nil)
            if roll.upcast != nil {
                HStack {
                    Stepper("Add \(rule.wrappedValue.count) dice",value:rule.count,in:1...20)
                    Picker("Die",selection:rule.sides) { ForEach([4,6,8,10,12,20,100],id:\.self) { Text("d\($0)").tag($0) } }.frame(width:115)
                }
                Stepper(rule.wrappedValue.everySlots == 1 ? "For each slot above level \(spell.level)":"For every \(rule.wrappedValue.everySlots) slots above level \(spell.level)",value:rule.everySlots,in:1...8)
                Text((spell.level...9).map { "L\($0): \(roll.expression(spell:spell,slot:$0))" }.joined(separator:" · "))
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
        }
    }
}
