import Foundation

@main struct ActivityTests {
    static func main() throws {
        var hero = Hero.sample
        var log = ActivityLedger()
        let start = hero
        var before = CharacterPlayState(hero)
        hero.damage(6)
        log.record(before:before,hero:hero)
        assert(log.entries.count == 1 && log.canUndo(hero))
        assert(log.entries[0].details.contains { $0.hasPrefix("HP ") })
        // Preserve text, portraits, and inventory descriptions edited after the event.
        hero.notes = "Do not roll this back"; hero.items[0].notes = "Edited description"
        hero = try log.undo(hero)
        assert(hero.hp == start.hp && hero.tempHP == start.tempHP && hero.notes == "Do not roll this back" && hero.items[0].notes == "Edited description")
        assert(log.entries[0].undone && !log.canUndo(hero))
        // One cast atomically restores slots, linked resources, and prior concentration.
        hero.conditions = []; hero.hp = hero.maximumHP; hero.slots = [3,0,0,0,0,0,0,0,0]; hero.usedSlots = Array(repeating:0,count:9)
        let counter = ResourceCounter(name:"Focus",current:3,maximum:3)
        hero.counters = [counter]
        let cost = ResourceCost(resource:ResourceRef(kind:.counter,id:counter.id))
        let oldSpell = Spell(name:"Old concentration",level:0,concentration:true)
        var spell = Spell(name:"New concentration",level:1,concentration:true); spell.resourceCost = cost
        hero.spells = [oldSpell,spell]; hero.concentrationSpellID = oldSpell.id
        let castStart = hero
        before = CharacterPlayState(hero)
        _ = try hero.cast(spell.id)
        log.record(before:before,hero:hero,hint:"Cast new concentration")
        assert(hero.usedSlots[0] == 1 && hero.counters![0].current == 2 && hero.concentrationSpellID == spell.id)
        hero = try log.undo(hero)
        assert(hero == castStart)
        // Separate events undo in reverse order, and divergent state is rejected.
        log = ActivityLedger()
        before = CharacterPlayState(hero); hero.inspiration.toggle(); log.record(before:before,hero:hero)
        let withInspiration = hero
        before = CharacterPlayState(hero); hero.damage(3); log.record(before:before,hero:hero)
        var divergent = hero; divergent.tempHP = 99
        let savedLog = log
        do { _ = try log.undo(divergent); fatalError("Divergent state accepted") } catch {}
        assert(log == savedLog)
        hero = try log.undo(hero); assert(hero == withInspiration)
        hero = try log.undo(hero); assert(hero.inspiration == castStart.inspiration)
        // Structural edits prevent partial undo of a level-up or changed counter maximum.
        before = CharacterPlayState(hero); hero.level += 1; hero.maxHP += 7; hero.hp += 7
        log.record(before:before,hero:hero)
        assert(!log.canUndo(hero) && !log.entries[0].undoable)
        before = CharacterPlayState(hero); hero.damage(1); log.record(before:before,hero:hero)
        hero = try log.undo(hero); assert(!log.canUndo(hero))
        // Creature state and equipment restore without touching their descriptions/images.
        log = ActivityLedger(); hero.creatures = [Creature(name:"Companion")]
        before = CharacterPlayState(hero); hero.creatures![0].isActive = false; hero.items[0].equipped.toggle(); log.record(before:before,hero:hero)
        hero = try log.undo(hero); assert(hero.creatures![0].isActive)
        // Durable history remains usable after relaunch and stays bounded.
        for i in 1...70 { before = CharacterPlayState(hero); hero.tempHP = i; log.record(before:before,hero:hero) }
        assert(log.entries.count == 50)
        var copy = try JSONDecoder().decode(ActivityLedger.self,from:JSONEncoder().encode(log))
        assert(copy == log && copy.canUndo(hero)); let undone = try copy.undo(hero); assert(undone.tempHP == 69)
        assert(JSONEncoderSize(copy) < 1_000_000)
        var second = Hero.sample; second.id = UUID()
        assert(!copy.canUndo(second))
        print("PASS: activity log grouping, atomic cast undo, damage/temp HP, equipment/creatures, text preservation, reverse order, setup barriers, stale rejection, persistence, character isolation, and bounded history")
    }
    static func JSONEncoderSize(_ log:ActivityLedger) -> Int { (try! JSONEncoder().encode(log)).count }
}
