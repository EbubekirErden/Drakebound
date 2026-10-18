import SwiftUI
func featureEffectSummary(_ effect:FeatureEffect,level:Int) -> String {
    let title=baseBonusTargets.first { $0.0 == effect.target }?.1 ?? effect.target
    let scaling=effect.perLevel == 0 ? "":" · \(signed(effect.perLevel)) per character level"
    return title+" "+signed(effect.total(at:level))+scaling
}
struct FeatureEffectsEditor:View {
    @Binding var feature:CharacterFeature
    var hero:Hero
    var mode:Binding<FeatureEffectMode> { Binding(get:{ feature.effectMode ?? .automatic },set:{ value in if value == .manual && feature.effects == nil { feature.effects=feature.resolvedEffects.map { var copy=$0;copy.id=UUID();return copy } };feature.effectMode=value }) }
    var list:Binding<[FeatureEffect]> { Binding(get:{ feature.effects ?? [] },set:{ feature.effects=$0 }) }
    var body:some View {
        EditorGroup(title:"Applied effects") {
            Picker("Effects",selection:mode) { ForEach(FeatureEffectMode.allCases,id:\.self) { Text($0.rawValue).tag($0) } }
            if mode.wrappedValue == .automatic {
                if feature.resolvedEffects.isEmpty { Text("No recognized automatic effect").font(.caption).foregroundStyle(.secondary);if !feature.recognizedEffects.isEmpty { Button("Apply recognized rule") { feature.effectMode = .automatic } } }
                ForEach(feature.resolvedEffects) { effect in Label(featureEffectSummary(effect,level:hero.level),systemImage:"checkmark.circle.fill").font(.caption).foregroundStyle(leaf) }
            } else if mode.wrappedValue == .manual {
                ForEach(list) { $effect in VStack(alignment:.leading,spacing:7) {
                    HStack { Picker("Applies to",selection:$effect.target) { ForEach(baseBonusTargets,id:\.0) { Text($0.1).tag($0.0) } };Toggle("Active",isOn:$effect.enabled);Button { feature.effects?.removeAll { $0.id == effect.id } } label: { Image(systemName:"minus.circle") } }
                    HStack { Stepper("Flat: \(signed(effect.amount))",value:$effect.amount,in:-100...100);Stepper("Per level: \(signed(effect.perLevel))",value:$effect.perLevel,in:-20...20) }
                    Text(featureEffectSummary(effect,level:hero.level)).font(.caption).foregroundStyle(leaf)
                }.padding(9).background(surface).clipShape(RoundedRectangle(cornerRadius:7)) }
                Button("Add effect") { feature.effects=(feature.effects ?? [])+[FeatureEffect()] }
            }
        }.help("Recognized rules currently support Tough. Use Custom effects for explicit flat or per-level bonuses. Choose Reference only if the effect is already included in base stats or tracked elsewhere. Changing maximum HP keeps a full-health character full and does not heal a wounded character.")
    }
}
