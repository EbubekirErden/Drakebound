import Foundation

@main struct CompendiumTests {
    static func main() throws {
        let xml = """
        <compendium><spell><name>Test & magic</name><level>1</level><school>EV</school><text>A &amp; B</text><roll>1d6</roll></spell><item><name>Rope</name><weight>10</weight><text>Climb.</text></item><monster><name>Wolf</name><hp>11 (2d8+2)</hp><ac>13 (natural)</ac><speed>40 ft.</speed><str>12</str><action><name>Bite</name><attack>Bite|4|2d4+2</attack></action></monster><class><name>Wizard</name><autolevel level="2"><feature><name>Tradition</name><text>Choose.</text></feature></autolevel></class><feat><name>Alert</name><text>React.</text></feat></compendium>
        """
        let result = try CompendiumImport.read(Data(xml.utf8))
        assert(result.entries.count == 5 && result.repairedAmpersands == 1)
        assert(result.entries[0].spell()?.name == "Test & magic" && result.entries[0].value("text") == "A & B")
        assert(result.entries[1].item().weight == 10)
        let c = result.entries[2].creature(); assert(c.hp == 11 && c.ac == 13 && c.speed == 40 && c.attacks[0].damage == "2d4+2")
        assert(result.entries[3].text.contains("Level 2") && result.entries[3].text.contains("Tradition"))
        assert(result.entries[3].featureCopies(through:1).isEmpty)
        assert(result.entries[3].featureCopies(through:2).first?.name == "Tradition")
        assert(result.entries[3].featureCopies(through:2).first?.source == "Wizard · Level 2")
        assert(result.entries[0].subcategory == "Level 1")
        assert(EquipmentKind.code("$") == .valuables && EquipmentKind.code("G") == .gear && EquipmentKind.code("W") == .wondrous && EquipmentKind.code("M") == .melee && EquipmentKind.code("S") == .shield)
        assert(CompendiumImport.merged(result.entries,result.entries).count == 5)
        var variant = result.entries[0]; variant.fields[1].text = "2"
        assert(CompendiumImport.merged(result.entries,[variant]).count == 6)
        let encoded = try JSONEncoder().encode(result.entries)
        let decoded = try JSONDecoder().decode([CompendiumEntry].self,from:encoded); assert(decoded == result.entries)
        let evil = "<!DOCTYPE compendium [<!ENTITY x SYSTEM 'file:///tmp/private'>]><compendium><item><name>&x;</name></item></compendium>"
        do { _ = try CompendiumImport.read(Data(evil.utf8)); fatalError("Accepted entity declaration") } catch { }
        if CommandLine.arguments.count > 1 {
            let full = try CompendiumImport.read(Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
            let counts = Dictionary(grouping:full.entries,by:\.category).mapValues(\.count)
            assert(full.entries.count == 25597 && full.repairedAmpersands == 1)
            assert(counts[.item] == 14985 && counts[.monster] == 6153 && counts[.spell] == 3090 && counts[.feat] == 715 && counts[.race] == 402 && counts[.classEntry] == 78 && counts[.background] == 174)
            let validSpells = full.entries.compactMap { $0.spell() }; assert(validSpells.count == 1723)
            for entry in full.entries where entry.category == .monster { let creature = entry.creature(); try validateContent(Hero(creatures:[creature])) }
            let unique = CompendiumImport.merged([],full.entries)
            assert(unique.count == 25563)
            assert(CompendiumImport.merged(unique,full.entries).count == unique.count)
            print("PASS: complete FC5 Compendium — 25,597 records, seven categories, one repaired ampersand, \(validSpells.count) usable spells, all creatures validated, nested class levels retained, repeat-import deduplication")
        }
        if let path = CommandLine.arguments.dropFirst(2).first {
            var h = try FightClubImport.read(Data(contentsOf:URL(fileURLWithPath:path))).heroes[0]
            let ray = h.spells.first { $0.name.contains("Ray of Frost") }!
            assert(h.cantripRoll(ray,at:h.level)?.expression == "2d8")
            let slotState = h.usedSlots
            let tier = try h.cast(ray.id,cantripLevel:17)
            assert(tier.expression == "4d8" && tier.dice.count == 4 && h.usedSlots == slotState && h.level == 8)
            let standard = try h.cast(ray.id,cantripLevel:h.level)
            assert(standard.expression == "2d8" && h.usedSlots == slotState)
            assert(h.creatures![0].attacks[0].description!.contains("8d10"))
            assert(h.creatures![0].traits!.contains { $0.name.contains("Soul Shackles") })
            assert(h.items.first { $0.name == "Wand" }?.equipmentKind == .wand)
            assert(h.items.first { $0.name == "Shield" }?.equipmentKind == .shield)
            assert(PreparationFilter.prepared.includes(ray) && !PreparationFilter.unprepared.includes(ray))
            for i in h.items.indices { h.items[i].kind = nil }
            for i in h.creatures![0].attacks.indices { h.creatures![0].attacks[i].description = nil }
            h.creatures![0].traits = nil; h.migrateContent()
            assert(h.creatures![0].attacks[0].description!.contains("8d10") && h.creatures![0].traits!.count > 0)
            assert(h.items.first { $0.name == "Wand" }?.equipmentKind == .wand)
            let migratedCopy = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(h))
            assert(migratedCopy.creatures == h.creatures && migratedCopy.items == h.items)
            assert(h.featureEntries?.filter { $0.category == .ancestry }.count == 9)
            assert(h.featureEntries?.filter { $0.category == .feat }.count == 1)
            for i in h.featureEntries!.indices { h.featureEntries![i].category = nil; h.featureEntries![i].source = nil }
            let oldIDs = h.featureEntries!.map(\.id); h.migrateContent()
            assert(h.featureEntries!.allSatisfy { $0.category != nil } && h.featureEntries!.map(\.id) == oldIDs)
            assert(h.featureEntries!.first { $0.name == "Fey Touched (Intelligence)" }?.category == .feat)
            print("PASS: feature-source import and migration preserve existing feature IDs and content")
            print("PASS: equipment types, prepared filters, individual attack descriptions/traits and migration, class feature splitting by level, and cantrip tier casting without spell slots")
        }
        print("PASS: compendium mappings, XML repair, entity rejection, fields/attributes, conversion, and JSON round trip")
    }
}
