import Foundation
let equipmentTrainingOptions:[(String,String)] = [("weapon.simple","Simple weapons"),("weapon.martial","Martial weapons"),("armor.light","Light armor"),("armor.medium","Medium armor"),("armor.heavy","Heavy armor"),("armor.shield","Shields")]
let specificWeaponOptions=["Club","Dagger","Greatclub","Handaxe","Javelin","Light Hammer","Mace","Quarterstaff","Sickle","Spear","Light Crossbow","Dart","Shortbow","Sling","Battleaxe","Flail","Glaive","Greataxe","Greatsword","Halberd","Lance","Longsword","Maul","Morningstar","Pike","Rapier","Scimitar","Shortsword","Trident","War Pick","Warhammer","Whip","Blowgun","Hand Crossbow","Heavy Crossbow","Longbow","Net"]
func trainingTargetName(_ target:String) -> String {
    if let label=equipmentTrainingOptions.first(where:{ $0.0 == target })?.1 { return label }
    if target.hasPrefix("weapon.") { return String(target.dropFirst(7)) }
    if target.hasPrefix("skill.") { return String(target.dropFirst(6)) }
    if target.hasPrefix("save."),let i=Int(target.dropFirst(5)),abilities.indices.contains(i) { return abilities[i]+" save" }
    return target
}
extension GuideRules {
    static func equipmentTraining(_ entry:CompendiumEntry) -> [TrainingGrant] {
        let raw=(entry.value("armor")+","+entry.value("weapons")).lowercased()
        var targets=equipmentTrainingOptions.filter { raw.contains($0.1.lowercased()) }.map(\.0)
        for weapon in specificWeaponOptions where raw.components(separatedBy:",").contains(where:{ $0.trimmingCharacters(in:.whitespaces) == weapon.lowercased() }) { targets.append("weapon."+weapon) }
        return targets.map { TrainingGrant(id:guideID(entry.id.uuidString+"-equipment-"+$0),target:$0,source:entry.name) }
    }
    static func featureEquipmentTraining(_ feature:CharacterFeature) -> [TrainingGrant] {
        let first=feature.text.components(separatedBy:"\n\n").first?.lowercased() ?? ""
        guard first.contains("you gain proficiency") || first.contains("you gain training") else { return [] }
        return equipmentTrainingOptions.filter { first.contains($0.1.lowercased()) || ($0.0 == "armor.heavy" && first.contains("heavy armor")) }.map { TrainingGrant(id:guideID(feature.id.uuidString+"-equipment-"+$0.0),target:$0.0,source:feature.name) }
    }
}
extension Hero {
    func attackIsProficient(_ attack:Attack) -> Bool { attack.proficient && (linkedEquipment(attack).flatMap { weaponTraining(for:$0) } ?? true) }
    var equipmentTrainingGrants:[TrainingGrant] { allTraining.filter { $0.target.hasPrefix("weapon.") || $0.target.hasPrefix("armor.") } }
    func weaponTraining(for item:Item) -> Bool? {
        guard equipmentTrainingGrants.contains(where:{ $0.target.hasPrefix("weapon.") }) else { return nil } // Preserve legacy/manual attack proficiency when no roster exists.
        let name=(item.weaponProfile?.trainingName.isEmpty == false ? item.weaponProfile!.trainingName:item.name).replacingOccurrences(of:" [2024]",with:"")
        if equipmentTrainingGrants.contains(where:{ $0.target.caseInsensitiveCompare("weapon."+name) == .orderedSame }) { return true }
        if let group=item.weaponProfile?.trainingGroup,["simple","martial"].contains(group) { return equipmentTrainingGrants.contains { $0.target == "weapon."+group } }
        let simple=Array(specificWeaponOptions.prefix(14))
        guard specificWeaponOptions.contains(where:{ $0.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
        let key=simple.contains(where:{ $0.caseInsensitiveCompare(name) == .orderedSame }) ? "weapon.simple":"weapon.martial"
        return equipmentTrainingGrants.contains { $0.target == key }
    }
}
