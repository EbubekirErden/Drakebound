import Foundation

@main struct ConditionTests {
    static func main() throws {
        var h = Hero.sample
        h.rulesEdition = "2014"
        h.conditions = ["Poisoned"]
        assert(h.rollMode(for:.attack) == .disadvantage && h.rollMode(for:.check) == .disadvantage)
        assert(h.rollMode(for:.save) == .normal && h.passivePerception == 9)
        h.conditions += ["Invisible"]; h.invisibleToTarget = true
        assert(h.rollMode(for:.attack) == .normal)
        h.conditions = ["Restrained"]
        assert(h.movement == 0 && h.rollMode(for:.save,ability:1) == .disadvantage)
        assert(h.rollMode(for:.save,ability:2) == .normal)
        h.conditions = ["Frightened"]; h.fearSourceVisible = false
        assert(h.rollMode(for:.attack) == .normal)
        h.fearSourceVisible = true; assert(h.rollMode(for:.attack) == .disadvantage)
        h.conditions = ["Paralyzed"]
        let failure = try h.performD20("1d20+3",label:"DEX save",kind:.save,ability:1)
        assert(failure.event && failure.expression.contains("Automatic failure"))
        let before = h.usedSlots
        do { _ = try h.cast(h.spells[0].id); fatalError("Incapacitated caster succeeded") } catch ActionError.cannotAct { }
        assert(h.usedSlots == before)
        h.conditions = ["Stunned"]; assert(h.movement == 0)
        h.rulesEdition = "2024"; assert(h.movement == 30 && h.rollMode(for:.initiative) == .disadvantage)
        h.conditions = ["Invisible"]; assert(h.rollMode(for:.initiative) == .advantage)
        h.conditions = []; h.exhaustionLevel = 2
        assert(h.testPenalty == -4 && h.movement == 20 && h.maximumHP == 32)
        let check = try h.performD20("1d20+7",label:"Arcana",kind:.check)
        assert(check.expression == "1d20+7-4")
        h.rulesEdition = "2014"; assert(h.testPenalty == 0 && h.movement == 15 && h.rollMode(for:.check) == .disadvantage)
        h.exhaustionLevel = 4; assert(h.maximumHP == 16 && h.rollMode(for:.save) == .disadvantage)
        h.longRest(); assert(h.exhaustionLevel == 3 && h.maximumHP == 32)
        h.rulesEdition = "2024"; h.exhaustionLevel = 0; h.hitDiceUsed = 5; h.longRest(); assert(h.hitDiceUsed == 0)
        for _ in 0..<200 {
            let advantage = try Dice.d20("1d20+3+1d4",label:"ADV",mode:.advantage)
            assert(advantage.dice.count == 3 && advantage.keptD20 == max(advantage.dice[0],advantage.dice[1]))
            assert(advantage.dice[advantage.keptD20Index!] == advantage.keptD20)
            assert(advantage.total == advantage.keptD20! + 3 + advantage.dice[2])
            let disadvantage = try Dice.d20("1d20-1",label:"DIS",mode:.disadvantage)
            assert(disadvantage.total == min(disadvantage.dice[0],disadvantage.dice[1])-1)
        }
        assert(Dice.bounds("1d4") == 1...4)
        assert(Dice.bounds("2d6+4-1d4") == 2...15)
        assert(Dice.bounds("bad dice") == nil)
        let cantrip = try h.cast(h.spells[0].id)
        assert(cantrip.event && cantrip.expression == "Cantrip cast · no spell slot required")
        let named = NamedRoll(name:"Attack",expression:"1d20+{attack}",kind:.attack)
        h.conditions = ["Poisoned"]
        let namedResult = try h.performNamedRoll(named,source:"Feature")
        assert(namedResult.detail?.contains("DIS") == true)
        h.bannerCrop = BannerCrop(x:0.25,y:0.7,zoom:1.8)
        let copy = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(h))
        assert(copy.bannerCrop == h.bannerCrop && copy.conditions == h.conditions)
        try validate(Archive(heroes:[h],library:[]))
        h.bannerCrop?.zoom = 9
        do { try validate(Archive(heroes:[h],library:[])); fatalError("Invalid crop accepted") } catch { }
        var recovery = Hero.sample
        recovery.counters = [ResourceCounter(name:"Short only",current:0,maximum:2,resetOn:[.shortRest]),ResourceCounter(name:"Long only",current:0,maximum:3,resetOn:[.longRest]),ResourceCounter(name:"Full only",current:0,maximum:4,resetOn:[.fullRest]),ResourceCounter(name:"Manual",current:0,maximum:5)]
        recovery.featureEntries = [CharacterFeature(name:"Feature uses",counter:ResourceCounter(current:0,maximum:2,resetOn:[.fullRest]))]
        recovery.resetCounters(for:.shortRest)
        assert(recovery.counters!.map(\.current) == [2,0,0,0])
        recovery.counters![0].current = 0
        recovery.longRest()
        assert(recovery.counters!.map(\.current) == [0,3,0,0] && recovery.featureEntries![0].counter!.current == 0)
        recovery.counters![1].current = 0; recovery.exhaustionLevel = 4; recovery.hitDiceUsed = 5
        recovery.fullRest()
        assert(recovery.counters!.map(\.current) == [0,0,4,0] && recovery.featureEntries![0].counter!.current == 2)
        assert(recovery.exhaustionLevel == 0 && recovery.hitDiceUsed == 0 && recovery.hp == recovery.maximumHP)
        let archived = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(recovery))
        assert(archived.counters == recovery.counters && archived.featureEntries == recovery.featureEntries)
        recovery.hp = 1
        recovery.hitDicePools = [HitDicePool(name:"Wizard",sides:6,total:3),HitDicePool(name:"Fighter",sides:10,total:2)]
        let poolID = recovery.hitDicePools![1].id
        let hitRoll = try recovery.spendHitDice(poolID,count:2)
        assert(hitRoll.dice.count == 2 && recovery.hitDicePools![0].used == 0 && recovery.hitDicePools![1].used == 2 && recovery.hitDiceUsed == 2)
        assert(recovery.hp == min(recovery.maximumHP,1+hitRoll.total))
        let stableEncoder = JSONEncoder(); stableEncoder.outputFormatting = [.sortedKeys]
        let state = try stableEncoder.encode(recovery)
        do { _ = try recovery.spendHitDice(poolID,count:1); fatalError("Spent unavailable dice") } catch { }
        let afterFailure = try stableEncoder.encode(recovery); assert(afterFailure == state)
        recovery.hitDicePools = nil; recovery.hitDiceUsed = 0; recovery.scores[2] = 1; recovery.hp = 1
        let lowCON = try recovery.spendHitDice(nil,count:3)
        assert(lowCON.total == lowCON.dice.reduce(0) { $0+max(0,$1-5) } && recovery.hitDiceUsed == 3)
        print("PASS: independent short/long/full/manual recovery, feature counters, legacy reset preservation, complete recovery, batch multiclass hit dice, per-die healing minimum, atomic spending, and kept-die index")
        print("PASS: 2014/2024 conditions, context toggles, ADV/DIS cancellation and kept dice, automatic failed saves, casting restrictions, exhaustion/rest effects, cantrip wording, roll ranges, typed custom rolls, and crop persistence")
    }
}
