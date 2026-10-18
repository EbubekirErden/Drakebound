import Foundation

@main struct ConcentrationTests {
    static func main() throws {
        var h = Hero.sample
        h.rulesEdition = "2024"; h.maxHP = 500; h.hp = 500; h.tempHP = 100
        let a = Spell(name:"Focus",level:0,concentration:true)
        let b = Spell(name:"Other focus",level:0,concentration:true)
        h.spells = [a,b]; _ = try h.cast(a.id)
        h.damage(31)
        assert(h.hp == 500 && h.tempHP == 69 && h.concentrationSaves.first!.dc == 15)
        h.damage(80)
        assert(h.hp == 489 && h.concentrationSaves.map(\.dc) == [15,30])
        let restored = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(h))
        assert(restored == h && restored.concentrationSaves.count == 2)
        try validate(Archive(heroes:[h],library:[]))
        let first = h.concentrationSaves[0]
        _ = try h.resolveConcentrationSave(first.id,total:15)
        assert(h.concentrationSaves.count == 1 && h.concentrationSpellID == a.id)
        let before = h
        do { _ = try h.resolveConcentrationSave(first.id,total:0); fatalError("Duplicate resolution accepted") } catch {}
        assert(h == before)
        do { _ = try h.rollConcentrationSave(h.concentrationSaves[0].id,dc:0); fatalError("Invalid DC accepted") } catch {}
        assert(h == before)
        _ = try h.resolveConcentrationSave(h.concentrationSaves[0].id,total:29)
        assert(h.concentrationSpellID == nil && h.pendingConcentrationSaves == nil)
        _ = try h.cast(a.id); h.damage(1); h.damage(1)
        _ = try h.resolveConcentrationSave(h.concentrationSaves[0].id,total:0)
        assert(h.concentrationSaves.isEmpty && h.pendingConcentrationSaves == nil)
        _ = try h.cast(a.id); h.damage(2); _ = try h.cast(b.id)
        assert(h.concentrationSpellID == b.id && h.pendingConcentrationSaves == nil)
        h.damage(2); _ = try h.cast(b.id); assert(h.pendingConcentrationSaves == nil)
        h.damage(2); h.longRest(); assert(h.concentrationSpellID == nil && h.pendingConcentrationSaves == nil)
        _ = try h.cast(a.id); h.damage(2); h.conditions = ["Stunned"]; h.reconcileConcentration()
        assert(h.concentrationSpellID == nil && h.pendingConcentrationSaves == nil)
        h.conditions = []; _ = try h.cast(a.id); h.damage(9999)
        assert(h.hp == 0 && h.concentrationSaves.isEmpty && h.pendingConcentrationSaves == nil)
        h.hp = 500; _ = try h.cast(a.id); h.damage(0); h.damage(-5)
        assert(h.hp == 500 && h.concentrationSaves.isEmpty)
        h.rulesEdition = "2014"; h.damage(81); assert(h.concentrationSaves.first!.dc == 40)
        h.concentrationSaveAdvantage = true
        assert(h.concentrationRollMode(.normal) == .advantage && h.concentrationRollMode(.disadvantage) == .normal)
        h.exhaustionLevel = 3; assert(h.concentrationRollMode(.normal) == .normal)
        h.concentrationSaveAdvantage = false; assert(h.concentrationRollMode(.normal) == .disadvantage)
        h.rulesEdition = "2024"; h.exhaustionLevel = 2
        h.bonuses = [Bonus(name:"Ward",target:"save.2",amount:100,dice:"1d4")]
        let expression = h.concentrationSaveExpression
        assert(expression.contains("1d4"))
        let result = try h.rollConcentrationSave(h.concentrationSaves[0].id)
        assert(result.expression == expression+"-4" && result.detail!.contains("maintained") && result.dice.count == 2)
        assert(h.pendingConcentrationSaves == nil && h.concentrationSpellID == a.id)
        h.damage(2); h.endConcentration(); assert(h.pendingConcentrationSaves == nil)
        let data = try JSONSerialization.jsonObject(with:JSONEncoder().encode(h)) as! [String:Any]
        var legacy = data; legacy.removeValue(forKey:"pendingConcentrationSaves"); legacy.removeValue(forKey:"concentrationSaveAdvantage")
        let decoded = try JSONDecoder().decode(Hero.self,from:JSONSerialization.data(withJSONObject:legacy))
        assert(decoded.concentrationSaves.isEmpty && decoded.concentrationSaveAdvantage == nil)
        print("PASS: concentration DC editions, temp HP, queued damage, persistence, duplicate/invalid resolution, success/failure, recast/rest/incapacitation/zero HP, advantage cancellation, modifiers and legacy saves")
    }
}
