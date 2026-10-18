import Foundation
@main struct SpellScalingTests {
    static func main() throws {
        var hero = Hero.sample
        var time = Spell(name:"Time Warp",level:2,components:"V, S, M",concentration:true)
        let damage = NamedRoll(name:"Damage",expression:"4d6",damageType:"Force",upcast:UpcastDice())
        time.rolls = [damage]; time.automaticRollID = damage.id
        assert(damage.expression(spell:time,slot:2) == "4d6")
        assert(damage.expression(spell:time,slot:3) == "5d6")
        assert(damage.expression(spell:time,slot:9) == "11d6")
        assert(damage.expression(spell:time,slot:0) == "4d6")
        var chrono = Spell(name:"Chronophage",level:4)
        let necro = NamedRoll(name:"Damage",expression:"6d8",damageType:"Force",upcast:UpcastDice(sides:8))
        chrono.rolls = [necro]; chrono.automaticRollID = necro.id
        assert(necro.expression(spell:chrono,slot:5) == "7d8")
        assert(necro.expression(spell:chrono,slot:9) == "11d8")
        let old = NamedRoll(name:"Legacy",expression:"7d8",slotLevel:5)
        assert(old.expression(spell:chrono,slot:9) == "7d8")
        let mixed = NamedRoll(expression:"2d6+3",upcast:UpcastDice(everySlots:2))
        assert(mixed.expression(spell:time,slot:3) == "2d6+3")
        assert(mixed.expression(spell:time,slot:4) == "2d6+3+1d6")
        hero.spells = [time,chrono]; hero.slots = Array(repeating:3,count:9); hero.usedSlots = Array(repeating:0,count:9)
        assert(validRolls(time.rolls,hero:hero,spell:time))
        let cast = try hero.cast(time.id,at:4)
        assert(cast.expression == "6d6" && cast.dice.count == 6 && cast.label.contains("Force"))
        assert(hero.usedSlots[3] == 1 && hero.concentrationSpellID == time.id)
        let separate = try hero.performAction(SheetActionRef(kind:.spellRoll,sourceID:time.id,rollID:damage.id),slot:5)
        assert(separate.expression == "7d6" && hero.usedSlots[4] == 0)
        var invalid = damage; invalid.upcast = UpcastDice(count:0)
        assert(!validRolls([invalid],hero:hero,spell:time))
        var bad = time; bad.rolls = [invalid]; bad.automaticRollID = invalid.id; hero.spells = [bad]
        let before = hero
        do { _ = try hero.cast(bad.id,at:4); assertionFailure("Invalid scaling cast") } catch { }
        assert(hero == before)
        let encoded = try JSONEncoder().encode(time)
        let decoded = try JSONDecoder().decode(Spell.self,from:encoded)
        assert(decoded == time)
        let entry = TemplateFactory.spell(time)
        let roundtrip = try JSONDecoder().decode(CompendiumEntry.self,from:JSONEncoder().encode(entry))
        assert(roundtrip.spell()?.rolls?.first?.upcast == damage.upcast)
        assert(roundtrip.spell()?.rolls?.first?.damageType == "Force")
        let legacy = try JSONDecoder().decode(NamedRoll.self,from:Data("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"Roll\",\"expression\":\"1d6\"}".utf8))
        assert(legacy.upcast == nil && legacy.damageType == nil)
        let components = SpellComponents("Verbal, Somatic, Material (a grain of black sand)")
        assert(components.contains("V") && components.material == "a grain of black sand")
        assert(SpellComponents(components.settingMaterial("a black ")).material == "a black ")
        let xml = Data("<compendium><spell><name>Material test</name><level>2</level><components>V, S, M</components><materials>a diamond worth 300 gp, consumed</materials></spell></compendium>".utf8)
        let imported = try FightClubImport.read(xml).spells[0]
        assert(SpellComponents(imported.components).material == "a diamond worth 300 gp, consumed")
        let inline = SpellComponents("V, S, M (a pearl worth 100 gp)")
        assert(inline.material == "a pearl worth 100 gp")
        assert(SpellComponents(inline.setting("S",enabled:false)).material == inline.material)
        print("Spell scaling, casting, materials, and compatibility checks passed")
    }
}
