import Foundation

@main struct ModelTests {
    static func main() throws {
        var h = Hero.sample
        assert(h.modifier(0) == -1 && h.modifier(3) == 4)
        assert(h.proficiency == 3 && h.spellDC == 15)
        assert(h.skillBonus("Arcana",3) == 7 && h.passivePerception == 14)
        h.skillRanks["Arcana"] = 2; assert(h.skillBonus("Arcana",3) == 10)
        h.level = 1; assert(h.proficiency == 2)
        h.level = 20; assert(h.proficiency == 6)
        h.hp = 20; h.tempHP = 5; h.damage(3); assert(h.hp == 20 && h.tempHP == 2)
        h.damage(7); assert(h.hp == 15 && h.tempHP == 0)
        h.damage(100); assert(h.hp == 0)
        h.level = 5; h.hitDiceUsed = 5; h.usedSlots = Array(repeating:2,count:9); h.longRest()
        assert(h.hp == h.maxHP && h.hitDiceUsed == 3 && h.usedSlots.allSatisfy { $0 == 0 })
        for _ in 0..<1000 {
            let r = try Dice.roll("2d6+3-1d4")
            assert((1...14).contains(r.total)); assert(r.dice.count == 3)
        }
        let constant = try Dice.roll("5"); assert(constant.total == 5)
        for invalid in ["", "d20", "0d20", "101d6", "1d1", "2d6hello", "1d6++3", "1d6/2", "99999999999999999999999999"] {
            do { _ = try Dice.roll(invalid); fatalError("Accepted invalid roll: \(invalid)") } catch { }
        }
        let a = Archive(heroes:[h],library:starterSpells)
        let roundtrip = try JSONDecoder().decode(Archive.self,from:JSONEncoder().encode(a)); try validate(roundtrip)
        assert(roundtrip.heroes[0].name == h.name && roundtrip.heroes[0].spells.count == 6)
        var corrupt = a; corrupt.heroes[0].scores = [1]
        do { try validate(corrupt); fatalError("Accepted corrupt scores") } catch { }
        corrupt = a; corrupt.heroes[0].skillRanks["Arcana"] = 7
        do { try validate(corrupt); fatalError("Accepted invalid proficiency") } catch { }
        corrupt = a; corrupt.heroes[0].castingAbility = 6
        do { try validate(corrupt); fatalError("Accepted invalid casting ability") } catch { }
        let xml = "<compendium><spell><name>Example spell</name><level>2</level><school>A</school><text>First paragraph.</text><text>Second paragraph.</text></spell><spell><name>Invalid</name><level>99</level></spell></compendium>"
        let reader = SpellXML(); let parser = XMLParser(data:Data(xml.utf8)); parser.delegate = reader
        assert(parser.parse()); assert(reader.spells.count == 1)
        assert(reader.spells[0].school == "Abjuration" && reader.spells[0].text.contains("First paragraph.\nSecond paragraph."))
        var equipped = Hero.sample
        equipped.items = [Item(name:"Leather",quantity:1,equipped:true,armorBase:11,armorAddsDexterity:true),Item(name:"Shield",equipped:true,bonuses:[Bonus(name:"Shield",target:"ac",amount:2)])]
        assert(equipped.armorClass == 15)
        equipped.items[1].equipped = false; assert(equipped.armorClass == 13)
        equipped.items[1].equipped = true; equipped.items[1].requiresAttunement = true
        assert(equipped.armorClass == 13)
        equipped.items[1].attuned = true; assert(equipped.armorClass == 15)
        equipped.items[1].quantity = 0; assert(equipped.armorClass == 13)
        equipped.items[1].quantity = 1
        equipped.bonuses = [Bonus(name:"Dexterity feat",target:"score.1",amount:2),Bonus(name:"Tough",target:"maxHP",amount:10),Bonus(name:"Alert",target:"initiative",amount:5),Bonus(name:"Bless",target:"saves",amount:0,dice:"1d4"),Bonus(name:"Arcana",target:"skill.Arcana",amount:2)]
        assert(equipped.effectiveScore(1) == 16 && equipped.armorClass == 16)
        assert(equipped.initiative == 8 && equipped.maximumHP == 42)
        assert(equipped.skillBonus("Arcana",3) == 9)
        assert(equipped.expression("1d20",bonus:equipped.saveBonus(3),targets:["saves","save.3"]) == "1d20+7+1d4")
        equipped.items[0].armorBase = 14; equipped.items[0].armorDexterityCap = 2
        assert(equipped.armorClass == 18)
        equipped.items[0].equipped = false; equipped.items[1].equipped = false
        assert(equipped.armorClass == equipped.ac)
        let weapon = equipped.attacks[0]; let spell = equipped.attacks[1]
        equipped.bonuses?.append(Bonus(name:"Wand",target:"spellAttack",amount:2))
        equipped.bonuses?.append(Bonus(name:"Weapon",target:"attack.\(weapon.id.uuidString)",amount:1))
        assert(equipped.attackBonus(weapon) == 3 && equipped.attackBonus(spell) == 9)
        equipped.bonuses?.append(Bonus(name:"Weapon damage",target:"damage.\(weapon.id.uuidString)",amount:2))
        assert(equipped.damageBonus(weapon) == 1 && equipped.damageBonus(spell) == 0)
        equipped.bonuses?[0].enabled = false; assert(equipped.effectiveScore(1) == 14)
        equipped.counters = [ResourceCounter(name:"Ki",current:0,maximum:5,reset:.shortRest),ResourceCounter(name:"Luck",current:1,maximum:3,reset:.longRest),ResourceCounter(name:"Arrows",current:12,maximum:20,reset:.manual)]
        equipped.resetCounters(for:.shortRest)
        assert(equipped.counters!.map(\.current) == [5,1,12])
        equipped.counters?[0].current = 0; equipped.longRest()
        assert(equipped.counters!.map(\.current) == [5,3,12] && equipped.hp == 42)
        let modern = Archive(heroes:[equipped],library:starterSpells)
        try validate(modern)
        let modernCopy = try JSONDecoder().decode(Archive.self,from:JSONEncoder().encode(modern))
        assert(modernCopy.heroes[0].counters!.count == 3 && modernCopy.heroes[0].maximumHP == 42)
        var legacyJSON = try JSONSerialization.jsonObject(with:JSONEncoder().encode(Hero.sample)) as! [String:Any]
        legacyJSON.removeValue(forKey:"bonuses"); legacyJSON.removeValue(forKey:"counters")
        var legacyItems = legacyJSON["items"] as! [[String:Any]]
        for i in legacyItems.indices { for key in ["bonuses","armorBase","armorAddsDexterity","armorDexterityCap","requiresAttunement","attuned"] { legacyItems[i].removeValue(forKey:key) } }
        legacyJSON["items"] = legacyItems
        let migrated = try JSONDecoder().decode(Hero.self,from:JSONSerialization.data(withJSONObject:legacyJSON))
        assert(migrated.bonuses == nil && migrated.counters == nil && migrated.armorClass == 12)
        let savedURL = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Fellowship5e/characters.json")
        if FileManager.default.fileExists(atPath:savedURL.path) { let saved = try JSONDecoder().decode(Archive.self,from:Data(contentsOf:savedURL)); try validate(saved); print("PASS: existing saved characters remain readable") }
        var story = Hero.sample
        let originalNotes = story.notes
        story.migrateContent()
        assert(story.journalEntries?.count == 1 && story.journalEntries?[0].description == originalNotes)
        let noteID = story.journalEntries![0].id
        story.migrateContent(); assert(story.journalEntries![0].id == noteID)
        story.journalEntries?.append(JournalEntry(title:"The next chapter",description:"Session two",image:Data([1,2,3])))
        story.portrait = Data([4,5,6])
        var companion = Creature(name:"Test companion",hp:12,maximumHP:12,ac:13,scores:[8,14,10,10,12,10],attacks:[CreatureAttack(name:"Bite",bonus:4,damage:"1d6+2")],image:Data([7,8,9]))
        assert(companion.modifier(0) == -1 && companion.modifier(1) == 2)
        companion.damage(99); assert(companion.hp == 0)
        companion.heal(99); assert(companion.hp == 12)
        companion.damage(-10); companion.heal(-10); assert(companion.hp == 12)
        story.creatures = [companion]
        let content = Archive(heroes:[story],library:starterSpells)
        try validate(content)
        let contentCopy = try JSONDecoder().decode(Archive.self,from:JSONEncoder().encode(content))
        assert(contentCopy.heroes[0].journalEntries?.count == 2 && contentCopy.heroes[0].portrait == story.portrait)
        assert(contentCopy.heroes[0].creatures?[0].image == companion.image && contentCopy.heroes[0].journalEntries?[1].image == Data([1,2,3]))
        var brokenContent = content; brokenContent.heroes[0].creatures?[0].scores = []
        do { try validate(brokenContent); fatalError("Accepted invalid creature") } catch { }
        brokenContent = content; brokenContent.heroes[0].creatures?[0].attacks[0].damage = "bad dice"
        do { try validate(brokenContent); fatalError("Accepted invalid creature attack") } catch { }
        brokenContent = content; brokenContent.heroes[0].journalEntries?.append(story.journalEntries![0])
        do { try validate(brokenContent); fatalError("Accepted duplicate notes") } catch { }
        print("PASS: rules, modifiers, dice, XML, counters, legacy migration, journal migration, creature stats/validation, and image-inclusive backup round-trip")
    }
}
