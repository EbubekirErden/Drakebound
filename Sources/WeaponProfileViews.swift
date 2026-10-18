import SwiftUI
struct WeaponProfileEditor:View {
    @Binding var item:Item
    var profile:Binding<WeaponProfile> { Binding(get:{ item.weaponProfile ?? WeaponProfile(damage:"1d6",damageType:"Bludgeoning") },set:{ item.weaponProfile=$0 }) }
    var body:some View {
        if [.melee,.ranged,.staff].contains(item.equipmentKind) || item.weaponProfile != nil {
            EditorGroup(title:"Weapon attack") {
                Toggle("Automatically create a linked attack when equipped",isOn:Binding(get:{ item.automaticAttack ?? true },set:{ item.automaticAttack=$0 })).font(.caption)
                if item.weaponProfile != nil {
                    HStack { EditorField(title:"Base damage") { DiceFormulaField(value:profile.damage) };EditorField(title:"Damage type") { OptionField(title:"Damage type",value:profile.damageType,choices:damageTypeChoices) } }
                    HStack { Toggle("Finesse",isOn:profile.finesse);Toggle("Ranged",isOn:profile.ranged) }.font(.caption)
                    Picker("Weapon proficiency group",selection:profile.trainingGroup) { Text("Use weapon name / manual").tag("");Text("Simple").tag("simple");Text("Martial").tag("martial") }.font(.caption)
                    HStack { Stepper("Attack bonus: \(signed(profile.wrappedValue.attackBonus))",value:profile.attackBonus,in:-20...20);Stepper("Damage bonus: \(signed(profile.wrappedValue.damageBonus))",value:profile.damageBonus,in:-20...20) }.font(.caption)
                } else { Button("Configure custom weapon stats") { item.weaponProfile=WeaponProfile(damage:"1d6",damageType:"Bludgeoning") } }
            }.help("Recognized compendium weapons supply their own stats. Finesse initially uses your better Strength/Dexterity modifier. Editing an attack preserves your custom choices. Removing its attack turns off automatic creation for this item.")
        }
    }
}
