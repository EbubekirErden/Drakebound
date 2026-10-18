import Foundation

@main struct ImportActionTests {
    static func main() throws {
        var h = Hero.sample
        h.usedSlots = h.slots
        let missile = h.spells.first { $0.name == "Magic missile" }!
        do { _ = try h.cast(missile.id); fatalError("Cast succeeded with exhausted slots") } catch ActionError.noSlots { }
        assert(h.usedSlots == h.slots)
        let cantrip = h.spells.first { $0.level == 0 }!
        let event = try h.cast(cantrip.id); assert(event.event && h.usedSlots == h.slots)
        h.usedSlots[1] = 0
        _ = try h.cast(missile.id); assert(h.usedSlots[1] == 1 && h.usedSlots[0] == 4)
        var healing = Spell(name:"Custom healing",level:1)
        let roll = NamedRoll(name:"Healing",expression:"1d8+{spell}+{slot}")
        healing.rolls = [roll]; healing.automaticRollID = roll.id; h.spells.append(healing)
        let healed = try h.cast(healing.id,at:2)
        assert(healed.expression == "1d8+4+2" && (7...14).contains(healed.total) && !healed.event)
        assert(tryResolve(h,"1d20+{str}") == "1d20-1")
        assert(tryResolve(h,"1d8+%0") == "1d8+4")
        var free = Spell(name:"Free step",level:2); free.usesSlot = false; free.freeUses = 1; free.freeRemaining = 1; h.spells.append(free)
        let before = h.usedSlots
        _ = try h.cast(free.id,mode:.free); assert(h.usedSlots == before && h.spells.last!.freeRemaining == 0)
        do { _ = try h.cast(free.id,mode:.free); fatalError("Exhausted free casting succeeded") } catch ActionError.noFreeUses { }
        var ritual = Spell(name:"Ritual test",level:1); ritual.ritual = true; h.spells.append(ritual)
        _ = try h.cast(ritual.id,mode:.ritual); assert(h.usedSlots == before)
        h.spells[h.spells.firstIndex(where:{ $0.id == healing.id })!].rolls?[0].expression = "not dice"
        do { _ = try h.cast(healing.id,at:2); fatalError("Invalid automatic roll succeeded") } catch { }
        assert(h.usedSlots == before)
        h.longRest(); assert(h.usedSlots.allSatisfy { $0 == 0 }); assert(h.spells.first { $0.id == free.id }!.freeRemaining == 1)
        let fallbackXML = Data("<compendium><spell><name>Test</name><school>EV</school><level>1</level><roll>1d8+%0</roll><roll>2d8+%0</roll><text>First</text><text>Second</text></spell></compendium>".utf8)
        let library = try FightClubImport.read(fallbackXML)
        assert(library.spells.count == 1 && library.spells[0].rolls?.count == 2 && library.spells[0].text == "First\n\nSecond")
        do { _ = try FightClubImport.read(Data("<!DOCTYPE pc [<!ENTITY secret SYSTEM 'file:///etc/passwd'>]><pc><character/></pc>".utf8)); fatalError("Accepted external entity XML") } catch { }
        if CommandLine.arguments.count > 1 {
            let xml = try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
            let imported = try FightClubImport.read(xml)
            assert(imported.heroes.count == 1)
            var character = imported.heroes[0]
            assert(character.name == "Shennie Dia" && character.level == 8)
            assert((0..<6).map { character.effectiveScore($0) } == [8,16,16,18,10,8])
            assert(character.hp == 60 && character.maximumHP == 60 && character.armorClass == 18)
            assert(character.slots == [4,3,3,2,0,0,0,0,0])
            assert(character.usedSlots == [0,0,0,1,0,0,0,0,0])
            assert(character.initiative == 7 && character.spellDC == 15 && character.spellAttack == 7)
            assert(character.skillBonus("Arcana",3) == 10)
            assert(character.spells.count == 29 && character.items.count == 18)
            assert(character.featureEntries?.count == 32 && character.counters?.count == 4)
            assert(character.counters?.first { $0.name == "Arcane Recovery" }?.current == 3)
            assert(character.counters?.first { $0.name == "Arcane Recovery" }?.maximum == 4)
            assert(character.creatures?.first?.name == "Tirpik" && character.creatures?.first?.attacks.count == 3)
            assert(character.portrait != nil && character.creatures?.first?.image != nil && character.sourceXML == xml)
            assert(character.hitDicePools?.map(\.sides) == [6,8] && character.hitDicePools?.map(\.total) == [7,1])
            let poolID = character.hitDicePools![1].id
            _ = try character.spendHitDie(poolID); assert(character.hitDicePools![1].used == 1 && character.hitDiceUsed == 1)
            character.longRest(); assert(character.hitDicePools![1].used == 0)
            let fireball = character.spells.first { $0.name == "Fireball [2024]" }!
            assert(fireball.school == "Evocation" && fireball.rolls?.first?.expression == "8d6" && fireball.rolls?.last?.expression == "14d6")
            assert(fireball.rolls?.first?.slotLevel == 3 && fireball.rolls?.last?.slotLevel == 9)
            let cure = character.spells.first { $0.name == "Cure Wounds (Artificer)" }!
            assert(cure.rolls?.count == 9 && cure.rolls?.first?.expression == "1d8+{spell}")
            assert(character.spells.first { $0.name == "Misty Step (Free Once)" }?.freeUses == 1)
            let saved = Archive(heroes:[character],library:[])
            let copy = try JSONDecoder().decode(Archive.self,from:JSONEncoder().encode(saved)); try validate(copy)
            assert(copy.heroes[0].sourceXML == xml && copy.heroes[0].spells.count == 29)
            print("PASS: Shennie Dia XML — 8 levels, effective scores 8/16/16/18/10/8, AC 18, HP 60, exact slot state, 29 spells, 18 items, 32 features, 4 trackers, Tirpik, both portraits, per-class hit dice, and backup round-trip")
        }
        print("PASS: direct casting, depleted slots, upcasting, cantrips, rituals, free-use limits/reset, token formulas, atomic resource use, repeated XML rolls, and entity rejection")
    }
    static func tryResolve(_ h:Hero,_ expression:String) -> String { try! h.resolveRoll(expression) }
}
