import Foundation

enum FeatureEffectMode:String,Codable,CaseIterable { case automatic="Recognized rules",manual="Custom effects",referenceOnly="Reference only" }
struct FeatureEffect:Codable,Equatable,Identifiable {
    var id=UUID()
    var target="maxHP"
    var amount=0
    var perLevel=0
    var enabled=true
    func total(at level:Int) -> Int { amount+perLevel*level }
}
extension CharacterFeature {
    var recognizedEffects:[FeatureEffect] {
        let key=name.lowercased().replacingOccurrences(of:" [2024]",with:"").replacingOccurrences(of:"origin: ",with:"").trimmingCharacters(in:.whitespacesAndNewlines)
        let description=text.lowercased()
        guard category == .feat,key == "tough",description.contains("hit point maximum"),description.contains("twice your character level") || description.contains("twice your level") else { return [] }
        return [FeatureEffect(id:guideID("recognized-tough-hp"),target:"maxHP",perLevel:2)]
    }
    var resolvedEffects:[FeatureEffect] {
        switch effectMode ?? .automatic {
        case .referenceOnly:return []
        case .manual:return effects ?? []
        case .automatic:return effectMode != nil || source == "Compendium" ? recognizedEffects:[]
        }
    }
}
extension Hero {
    var featureEffectBonuses:[Bonus] {
        var seen=Set<UUID>(),result:[Bonus]=[]
        for feature in featureEntries ?? [] {
            for effect in feature.resolvedEffects where effect.enabled && seen.insert(effect.id).inserted {
                // An older manually configured Tough modifier already represents this rule.
                if effect.id == guideID("recognized-tough-hp"),(bonuses ?? []).contains(where:{ $0.enabled && $0.target == "maxHP" && $0.name.localizedCaseInsensitiveContains("Tough") }) { continue }
                result.append(Bonus(id:guideID(feature.id.uuidString+effect.id.uuidString),name:feature.name,target:effect.target,amount:effect.total(at:level)))
            }
        }
        return result
    }
    mutating func replaceFeatures(_ features:[CharacterFeature]) {
        let before=maximumHP,full=hp > 0 && hp == before
        featureEntries=features
        hp=full ? maximumHP:min(hp,maximumHP)
    }
    mutating func migrateRecognizedFeatureEffects() {
        let eligible=(featureEntries ?? []).filter { $0.effectMode == nil && $0.effects == nil && $0.source == "Compendium" && !$0.recognizedEffects.isEmpty }.map(\.id)
        guard !eligible.isEmpty else { return }
        var baseline=self
        for i in baseline.featureEntries!.indices where eligible.contains(baseline.featureEntries![i].id) { baseline.featureEntries![i].effectMode = .referenceOnly }
        let full=hp > 0 && hp == baseline.maximumHP
        for i in featureEntries!.indices where eligible.contains(featureEntries![i].id) { featureEntries![i].effectMode = .automatic }
        if full { hp=maximumHP } else { hp=min(hp,maximumHP) }
    }
    var maximumHPExplanation:String {
        (["Base maximum HP: \(maxHP)"]+activeBonuses.filter { $0.target == "maxHP" }.map { $0.name+": "+signed($0.amount) }+["Maximum HP: \(maximumHP)"]).joined(separator:"\n")
    }
}
func validFeatureEffects(_ feature:CharacterFeature) -> Bool {
    let effects=feature.effects ?? []
    return effects.count <= 50 && Set(effects.map(\.id)).count == effects.count && effects.allSatisfy { effect in (-100...100).contains(effect.amount) && (-20...20).contains(effect.perLevel) && baseBonusTargets.contains(where:{ $0.0 == effect.target }) }
}
