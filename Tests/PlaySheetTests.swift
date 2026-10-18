import Foundation

@main struct PlaySheetTests {
    static func main() throws {
        var hero = Hero.sample
        let pack = EquipmentContainer(name:"Backpack"); let chest = EquipmentContainer(name:"Camp chest")
        hero.equipmentContainers = [pack,chest]
        let arrow = Item(name:"Arrows",quantity:20,weight:0.05,equipped:true,containerID:pack.id)
        let sword = Item(name:"Sword",weight:3,equipped:true,bonuses:[Bonus(name:"Ward",target:"ac",amount:1)])
        hero.items = [arrow,sword]
        let before = hero.items
        assert(abs(hero.inventoryWeight(in:pack.id)-1) < 0.00001)
        assert(hero.placeItem(sword.id,in:chest.id))
        assert(hero.items[1].equipped && hero.items[1].bonuses == before[1].bonuses && hero.inventoryWeight(in:chest.id) == 3)
        assert(!hero.placeItem(sword.id,in:UUID()) && hero.items[1].containerID == chest.id)
        hero.removeContainer(chest.id)
        assert(hero.items[1].containerID == nil && hero.items.count == 2 && hero.items[1].bonuses == before[1].bonuses)
        assert(hero.inventoryWeight(in:nil) == 3)
        let template = TemplateFactory.item(arrow)
        assert(template.item().containerID == nil && template.template?.item?.containerID == nil)
        try validate(Archive(heroes:[hero],library:[]))
        let roundtrip = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(hero))
        assert(roundtrip == hero)
        var invalid = hero; invalid.items[0].containerID = UUID()
        do { try validateInventory(invalid); fatalError("Accepted an unknown container") } catch {}
        invalid = hero; invalid.equipmentContainers!.append(pack)
        do { try validateInventory(invalid); fatalError("Accepted duplicate container IDs") } catch {}
        var old = Hero.sample; old.equipmentContainers = nil; old.migrateEquipmentContainers()
        assert(old.inventoryContainers.isEmpty)
        let attack = Attack(name:"Sword",equipmentID:sword.id)
        let custom = Attack(name:"Unarmed",damage:"1")
        hero.attacks = [attack,custom]
        assert(hero.readyAttacks.count == 2)
        hero.items[1].equipped = false
        assert(hero.readyAttacks.map(\.id) == [custom.id] && hero.stowedAttacks.map(\.id) == [attack.id])
        assert(hero.attacks.count == 2)
        hero.items[1].equipped = true; assert(hero.readyAttacks.count == 2)
        hero.items[1].quantity = 0; assert(hero.stowedAttacks.count == 1)
        assert(hero.scoreExplanation(3).contains("Effective score: \(hero.effectiveScore(3))"))
        assert(hero.checkExplanation(3).contains("ability check") && hero.saveExplanation(3).contains("saving throw"))
        hero.trainingGrants = [TrainingGrant(target:"skill.Arcana",rank:2,source:"Class feature")]
        hero.bonuses = [Bonus(name:"Study",target:"skill.Arcana",amount:1),Bonus(name:"Guidance",target:"checks",amount:0,dice:"1d4")]
        assert(hero.skillExplanation("Arcana",ability:3).contains("Expertise (2 × proficiency)"))
        assert(hero.skillExplanation("Arcana",ability:3).contains("Guidance: 1d4 on the roll"))
        assert(hero.skillExplanation("Arcana",ability:3).contains("Total modifier: "+signed(hero.skillBonus("Arcana",3))))
        hero.bonuses!.append(Bonus(name:"Arcane focus",target:"spellAttack",amount:1,dice:"1d4"))
        assert(hero.spellAttackExplanation.contains("Arcane focus: +1 · 1d4 on the roll") && hero.spellAttackExplanation.contains("Total modifier: "+signed(hero.spellAttack)))
        let damageAttack = Attack(name:"Test blade",ability:1,addDamageModifier:true,damage:"1d6")
        assert(hero.damageExplanation(damageAttack).contains("Roll: "+hero.expression(damageAttack.damage,bonus:hero.damageBonus(damageAttack),targets:hero.attackTargets(damageAttack,damage:true))))
        hero.rulesEdition = "2024"; hero.exhaustionLevel = 1
        assert(hero.saveExplanation(3).contains("Exhaustion: -2"))
        assert(hero.saveExplanation(3).contains("Total modifier: "+signed(hero.saveBonus(3)+hero.testPenalty)))
        hero.items = [Item(name:"Armor",equipped:true,armorBase:15,armorAddsDexterity:true,armorDexterityCap:2)]
        assert(hero.armorClassExplanation.contains("Armor base: 15") && hero.armorClassExplanation.contains("Total AC: \(hero.armorClass)"))
        if CommandLine.arguments.count > 1 {
            var shennie = try FightClubImport.read(Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))).heroes[0]
            assert(shennie.inventoryContainers.count == 1 && shennie.inventoryContainers[0].name == "Scholar's Pack")
            let packID = shennie.inventoryContainers[0].id
            assert(shennie.items.filter { $0.containerID == packID }.count == 6)
            assert(shennie.items.first { $0.name == "Backpack" }?.containerID == nil)
            assert(!shennie.readyAttacks.contains { $0.name == "Dagger" } && shennie.stowedAttacks.contains { $0.name == "Dagger" })
            let staffIndex = shennie.items.firstIndex { $0.name == "Staff" }!
            assert(!shennie.items[staffIndex].equipped && shennie.stowedAttacks.contains { $0.name == "Staff" })
            shennie.items[staffIndex].equipped = true
            assert(shennie.readyAttacks.contains { $0.name == "Staff" })
            assert(shennie.skillExplanation("Arcana",ability:3).contains("Scholar") && shennie.skillExplanation("Arcana",ability:3).contains("Total modifier: +10"))
            let ids = shennie.items.map(\.id); let slots = shennie.usedSlots; let hp = shennie.hp
            shennie.equipmentContainers = nil
            for i in shennie.items.indices { shennie.items[i].containerID = nil }
            shennie.migrateEquipmentContainers()
            assert(shennie.items.filter { $0.containerID != nil }.count == 6 && shennie.items.map(\.id) == ids)
            assert(shennie.items.first { $0.name == "Backpack" }?.containerID == nil)
            assert(shennie.hp == hp && shennie.usedSlots == slots)
            let firstMigration = shennie; shennie.migrateEquipmentContainers(); assert(firstMigration == shennie)
            try validate(Archive(heroes:[shennie],library:[]))
            print("PASS: Shennie’s six bag items, preserved inventory/HP/slots, idempotent legacy migration, ready/stowed attacks, and modifier explanations")
        }
        if CommandLine.arguments.count > 2 {
            let compendium = try CompendiumImport.read(Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2]))).entries
            let wizard = compendium.first { $0.category == .classEntry && $0.name == "Wizard [2024]" }!
            let artificer = compendium.first { $0.category == .classEntry && $0.name == "Artificer" }!
            assert(GuideRules.importedCantrips(wizard,at:1) == 3 && GuideRules.importedCantrips(wizard,at:4) == 4 && GuideRules.importedCantrips(wizard,at:10) == 5)
            assert(GuideRules.importedCantrips(artificer,at:1) == 2)
            assert(GuideRules.importedSlots(wizard,at:1) == [2,0,0,0,0,0,0,0,0])
        }
        print("PASS: container moves/removal/validation, independent templates, JSON round trip, distinct checks/saves, source explanations, and class cantrip counts separate from slots")
    }
}
