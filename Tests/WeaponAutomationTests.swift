import Foundation
@main struct WeaponAutomationTests {
    static func main() throws {
        let rapier=CompendiumEntry(category:.item,name:"Rapier",fields:[ReferenceField(name:"type",text:"M"),ReferenceField(name:"dmg1",text:"1d8"),ReferenceField(name:"dmgType",text:"P"),ReferenceField(name:"property",text:"F,M"),ReferenceField(name:"text",text:"Proficiency: martial, rapier")])
        assert(rapier.weaponProfile?.trainingName == "Rapier")
        var h=Hero();h.level=5;h.scores=[10,18,12,10,10,10];h.items=[rapier.item()];h.attacks=[];h.trainingGrants=[TrainingGrant(target:"weapon.simple",source:"Class")]
        let id=h.items[0].id;h.synchronizeWeaponAttacks(compendium:[rapier]);assert(h.attacks.isEmpty)
        h.setItemEquipped(id,true,compendium:[rapier]);assert(h.attacks.count == 1)
        let attack=h.attacks[0];assert(attack.equipmentID == id && attack.ability == 1 && attack.damage == "1d8" && attack.type == "Piercing")
        assert(h.attackBonus(attack) == 4)
        h.trainingGrants?.append(TrainingGrant(target:"weapon.martial",source:"Feature"));assert(h.attackBonus(attack) == 7)
        h.setItemEquipped(id,false,compendium:[rapier]);assert(h.readyAttacks.isEmpty && h.stowedAttacks.count == 1)
        h.setItemEquipped(id,true,compendium:[rapier]);assert(h.attacks.count == 1 && h.attacks[0].id == attack.id)
        let snapshot=h;h.synchronizeWeaponAttacks(compendium:[rapier]);assert(h == snapshot)
        h.attacks[0].damage="2d4";h.attacks[0].ability=3;h.attacks[0].automaticWeaponAttack=false
        h.synchronizeWeaponAttacks(compendium:[rapier]);assert(h.attacks[0].damage == "2d4" && h.attacks[0].ability == 3)
        h.removeWeaponAttack(attack.id);h.synchronizeWeaponAttacks(compendium:[rapier]);assert(h.attacks.isEmpty && h.items[0].automaticAttack == false)
        h.items[0].automaticAttack=true;h.synchronizeWeaponAttacks(compendium:[rapier]);assert(h.attacks.count == 1)
        var legacy=Hero();legacy.items=[Item(name:"Rapier",equipped:true,kind:.melee)];legacy.attacks=[Attack(name:"Rapier",ability:3,damage:"1d12")]
        let prior=legacy.attacks[0].id;legacy.synchronizeWeaponAttacks(compendium:[rapier]);assert(legacy.attacks.count == 1 && legacy.attacks[0].id == prior && legacy.attacks[0].damage == "1d12" && legacy.attacks[0].ability == 3 && legacy.attacks[0].equipmentID == legacy.items[0].id)
        var two=Hero();two.attacks=[];two.items=[rapier.item(),rapier.item()];for i in two.items.indices { two.items[i].equipped=true };two.synchronizeWeaponAttacks(compendium:[rapier]);assert(two.attacks.count == 2 && Set(two.attacks.compactMap(\.equipmentID)).count == 2)
        var unknown=Hero();unknown.attacks=[];unknown.items=[Item(name:"Unknown weapon",equipped:true,kind:.melee)];unknown.synchronizeWeaponAttacks(compendium:[]);assert(unknown.attacks.isEmpty)
        unknown.items[0].weaponProfile=WeaponProfile(damage:"1d10",damageType:"Force",ranged:true);unknown.synchronizeWeaponAttacks(compendium:[]);assert(unknown.attacks.first?.ability == 1)
        unknown.items[0].quantity=0;unknown.attacks=[];unknown.synchronizeWeaponAttacks(compendium:[]);assert(unknown.attacks.isEmpty)
        var magic=rapier;magic.id=UUID();magic.name="Rapier +1";magic.fields += [ReferenceField(name:"modifier",text:"Weapon Attacks +1"),ReferenceField(name:"modifier",text:"Weapon Damage +1")]
        var m=Hero();m.level=5;m.scores=[10,18,12,10,10,10];m.attacks=[];m.items=[magic.item()];m.items[0].equipped=true;m.trainingGrants=[TrainingGrant(target:"weapon.Rapier",source:"Specific weapon")]
        m.synchronizeWeaponAttacks(compendium:[magic]);let ma=m.attacks[0];assert(m.attackBonus(ma) == 8 && m.damageBonus(ma) == 5)
        assert(m.flat(["attack"]) == 0 && m.flat(["damage"]) == 0)
        let template=TemplateFactory.item(m.items[0]);assert(template.template?.item?.bonuses?.isEmpty != false)
        try validate(Archive(heroes:[m],library:[]));let restored=try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(m));assert(restored == m)
        if CommandLine.arguments.count > 1 {
            let imported=try CompendiumImport.read(Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
            let real=imported.entries.first { $0.name == "Rapier [2024]" && $0.category == .item }!
            assert(real.weaponProfile?.finesse == true && real.weaponProfile?.damage == "1d8")
            var r=Hero();r.attacks=[];r.items=[Item(name:"Rapier",equipped:true,kind:.melee)];r.synchronizeWeaponAttacks(compendium:imported.entries);assert(r.attacks.count == 1 && r.attacks[0].damage == "1d8")
        }
        print("PASS: equipped weapon generation, finesse/ranged ability, dynamic proficiency, ready/stowed state, idempotence, manual attack preservation, removal opt-out, duplicate weapon instances, unknown/custom/zero-quantity items, magic bonus isolation, clean templates, real XML and persistence")
    }
}
