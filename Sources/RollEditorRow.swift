import SwiftUI

struct RollEditorRow:View {
    @Binding var roll:NamedRoll
    var hero:Hero
    var spell:Spell?
    var allowsResourceCosts:Bool
    var remove:()->Void
    @State private var levelOptions=false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(alignment:.bottom,spacing:12) {
                EditorField(title:"Roll name") { TextField("Roll name",text:$roll.name) }
                EditorField(title:"Formula") { DiceFormulaField(value:$roll.expression,hero:hero,spell:spell,slot:roll.slotLevel ?? spell?.level ?? 0,allowTokens:true) }
                Button(action:remove) { Image(systemName:"minus.circle") }.buttonStyle(.plain).help("Remove roll").accessibilityLabel("Remove roll").frame(height:28)
            }
            if let spell {
                EditorColumns {
                    rollSettings
                } trailing: {
                    VStack(alignment:.leading,spacing:10) {
                        if spell.level > 0 { SpellUpcastEditor(roll:$roll,spell:spell) }
                        DisclosureGroup(spell.level == 0 ? "Cantrip level options":"Manual slot-level option",isExpanded:$levelOptions) {
                            VStack(alignment:.leading,spacing:8) {
                                if spell.level == 0 {
                                    Toggle("Use as cantrip scaling tier",isOn:Binding(get:{ roll.minimumCharacterLevel != nil },set:{ roll.minimumCharacterLevel = $0 ? 1:nil }))
                                    Stepper("Character level \(roll.minimumCharacterLevel ?? 1)+",value:Binding(get:{ roll.minimumCharacterLevel ?? 1 },set:{ roll.minimumCharacterLevel = $0 }),in:1...20)
                                } else {
                                    Toggle("Label as slot-level option",isOn:Binding(get:{ roll.slotLevel != nil },set:{ roll.slotLevel = $0 ? max(1,spell.level):nil }))
                                    Stepper("Slot level \(roll.slotLevel ?? spell.level)",value:Binding(get:{ roll.slotLevel ?? spell.level },set:{ roll.slotLevel = $0 }),in:max(1,spell.level)...9)
                                }
                            }.padding(.top,6)
                        }.font(.system(size:12))
                    }
                }
            } else { rollSettings }
            if let resolved=try? hero.resolveRoll(roll.expression,spell:spell,slot:spell?.level ?? 0) { Text("Preview: \(resolved)").font(.caption2).foregroundStyle(.secondary) }
            else { Text("Invalid formula or unknown token").font(.caption2).foregroundStyle(coral) }
        }.onAppear { levelOptions = roll.minimumCharacterLevel != nil || roll.slotLevel != nil }
    }
    private var rollSettings:some View {
        VStack(alignment:.leading,spacing:10) {
            EditorField(title:"Damage type") { OptionField(title:"Damage type",value:Binding(get:{ roll.damageType ?? "None" },set:{ roll.damageType = $0 == "None" ? nil:$0 }),choices:damageTypeChoices) }
            EditorField(title:"Condition effects") {
                Picker("Condition effects",selection:$roll.kind) { Text("Generic · no automatic conditions").tag(Optional<D20Kind>.none);ForEach(D20Kind.allCases,id:\.self) { Text($0.rawValue).tag(Optional($0)) } }
            }
            if roll.kind == .save || roll.kind == .check {
                EditorField(title:"Ability") { Picker("Ability",selection:$roll.ability) { Text("Unspecified").tag(Optional<Int>.none);ForEach(0..<6,id:\.self) { Text(abilities[$0]).tag(Optional($0)) } } }
            }
            if allowsResourceCosts { ResourceCostPicker(cost:$roll.resourceCost,hero:hero) }
        }
    }
}
