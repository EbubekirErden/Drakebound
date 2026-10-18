import Foundation

struct WeaponProfile:Codable,Equatable {
    var damage:String
    var damageType:String
    var finesse=false
    var ranged=false
    var trainingName=""
    var trainingGroup=""
    var attackBonus=0
    var damageBonus=0
    var range=""
    var valid:Bool { Dice.bounds(damage) != nil && (-20...20).contains(attackBonus) && (-20...20).contains(damageBonus) }
}
extension CompendiumEntry {
    var weaponProfile:WeaponProfile? {
        if let profile=template?.item?.weaponProfile { return profile.valid ? profile:nil }
        guard category == .item,["M","R","ST"].contains(value("type")),Dice.bounds(value("dmg1")) != nil else { return nil }
        let properties=value("property").split(separator:",").map { $0.trimmingCharacters(in:.whitespaces) }
        let training=text.components(separatedBy:.newlines).first { $0.lowercased().hasPrefix("proficiency:") }?.lowercased() ?? ""
        let canonical=specificWeaponOptions.first { training.components(separatedBy:",").map { $0.trimmingCharacters(in:.whitespaces) }.contains($0.lowercased()) } ?? ""
        func bonus(_ label:String) -> Int {
            fields.filter { $0.name == "modifier" }.compactMap { field -> Int? in
                let value=field.text.trimmingCharacters(in:.whitespaces)
                guard value.lowercased().hasPrefix(label.lowercased()+" ") else { return nil }
                return Int(value.dropFirst(label.count).trimmingCharacters(in:.whitespaces))
            }.first ?? 0
        }
        let profile=WeaponProfile(damage:value("dmg1"),damageType:["P":"Piercing","S":"Slashing","B":"Bludgeoning"][value("dmgType")] ?? value("dmgType"),finesse:properties.contains("F"),ranged:value("type") == "R",trainingName:canonical,trainingGroup:training.contains("martial") ? "martial":training.contains("simple") ? "simple":"",attackBonus:bonus("Weapon Attacks"),damageBonus:bonus("Weapon Damage"),range:value("range"))
        return profile.valid ? profile:nil
    }
}
extension Hero {
    mutating func setItemEquipped(_ id:UUID,_ equipped:Bool,compendium:[CompendiumEntry]) {
        guard let i=items.firstIndex(where:{ $0.id == id }) else { return }
        items[i].equipped=equipped
        synchronizeWeaponAttacks(compendium:compendium)
    }
    mutating func synchronizeWeaponAttacks(compendium:[CompendiumEntry]) {
        for i in items.indices {
            guard items[i].equipped,items[i].quantity > 0,items[i].automaticAttack != false else { continue }
            if items[i].weaponProfile == nil {
                let name=items[i].name
                let candidates=compendium.filter { $0.category == .item && $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.weaponProfile != nil }
                let entry=candidates.first { edition == "2024" ? $0.sourceMark == .revised:$0.sourceMark != .revised } ?? candidates.first
                if let entry { items[i].weaponProfile=entry.weaponProfile;if items[i].kind == nil || items[i].equipmentKind == .gear { items[i].kind=EquipmentKind.code(entry.value("type")) } }
            }
            guard let profile=items[i].weaponProfile,profile.valid else { continue }
            let item=items[i]
            if let index=attacks.firstIndex(where:{ $0.equipmentID == item.id }) {
                if attacks[index].automaticWeaponAttack == true { attacks[index]=weaponAttack(item,profile:profile,id:attacks[index].id);applyWeaponBonuses(itemIndex:i,attack:attacks[index],profile:profile) }
                continue
            }
            let sameItems=items.filter { $0.name.caseInsensitiveCompare(item.name) == .orderedSame }
            if sameItems.count == 1,let index=attacks.firstIndex(where:{ $0.equipmentID == nil && $0.isSpell != true && $0.name.caseInsensitiveCompare(item.name) == .orderedSame }) { attacks[index].equipmentID=item.id;continue }
            let attack=weaponAttack(item,profile:profile)
            attacks.append(attack);applyWeaponBonuses(itemIndex:i,attack:attack,profile:profile)
        }
    }
    func weaponAttack(_ item:Item,profile:WeaponProfile,id:UUID=UUID()) -> Attack {
        let ability=profile.ranged || (profile.finesse && modifier(1) > modifier(0)) ? 1:0
        let range=profile.range.isEmpty || item.notes.contains(profile.range) ? "":"\nRange: "+profile.range
        return Attack(id:id,name:item.name,ability:ability,proficient:true,damage:profile.damage,type:profile.damageType,description:item.notes+range,equipmentID:item.id,automaticWeaponAttack:true)
    }
    private mutating func applyWeaponBonuses(itemIndex:Int,attack:Attack,profile:WeaponProfile) {
        var bonuses=items[itemIndex].bonuses ?? []
        for (target,amount) in [("attack",profile.attackBonus),("damage",profile.damageBonus)] {
            let id=guideID(items[itemIndex].id.uuidString+"-auto-weapon-"+target)
            bonuses.removeAll { $0.id == id }
            if amount != 0 { bonuses.append(Bonus(id:id,name:items[itemIndex].name,target:target+"."+attack.id.uuidString,amount:amount)) }
        }
        if !bonuses.isEmpty || items[itemIndex].bonuses != nil { items[itemIndex].bonuses=bonuses }
    }
    mutating func removeWeaponAttack(_ id:UUID) {
        guard let attack=attacks.first(where:{ $0.id == id }) else { return }
        if let item=linkedEquipment(attack),let i=items.firstIndex(where:{ $0.id == item.id }) {
            items[i].automaticAttack=false
            let ids=Set([guideID(item.id.uuidString+"-auto-weapon-attack"),guideID(item.id.uuidString+"-auto-weapon-damage")])
            items[i].bonuses?.removeAll { ids.contains($0.id) }
        }
        attacks.removeAll { $0.id == id }
    }
}

func cleanWeaponTemplateBonuses(_ item:Item) -> [Bonus]? {
    let ids=Set([guideID(item.id.uuidString+"-auto-weapon-attack"),guideID(item.id.uuidString+"-auto-weapon-damage")])
    return item.bonuses?.filter { !ids.contains($0.id) }
}
