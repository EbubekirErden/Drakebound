import Foundation
@main struct CurrencyTests {
    static func main() throws {
        assert(CurrencyBalance.parse("12.50") == 1250 && CurrencyBalance.parse("0,01") == 1)
        assert(CurrencyBalance.parse("3.5") == 350 && CurrencyBalance.parse(" 2 ") == 200)
        for invalid in ["-1","1.001","NaN","inf","1e2","","999999999999999999999999999"] { assert(CurrencyBalance.parse(invalid) == nil) }
        assert(CurrencyBalance.format(105) == "1.05")
        var hero=Hero.sample;hero.gold=42
        assert(hero.currencyBalances[0].minorUnits == 4200)
        try hero.changeCurrency("gp",amount:125,operation:.spend)
        assert(hero.gold == 40 && hero.goldMinorUnits == 75)
        try hero.changeCurrency("gp",amount:25,operation:.add)
        assert(hero.gold == 41 && hero.goldMinorUnits == 0)
        try hero.changeCurrency("sp",amount:350,operation:.set)
        let gems=try hero.addCurrency(named:"Moon gems")
        try hero.changeCurrency(gems,amount:1,operation:.add)
        let snapshot=hero
        do { try hero.changeCurrency(gems,amount:2,operation:.spend);fatalError("Overspent custom currency") } catch CurrencyError.insufficient {}
        assert(hero == snapshot)
        do { _=try hero.addCurrency(named:"GP");fatalError("Duplicated standard currency") } catch CurrencyError.duplicate {}
        do { _=try hero.addCurrency(named:"moon GEMS");fatalError("Duplicated custom currency") } catch CurrencyError.duplicate {}
        try validate(Archive(heroes:[hero],library:[]))
        let restored=try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(hero));assert(restored == hero)
        var legacy=hero;legacy.currencies=nil;legacy.goldMinorUnits=nil
        let old=try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(legacy));assert(old.gold == 41 && old.currencyBalances[0].minorUnits == 4100)
        hero.currencies?.append(CurrencyBalance(id:"gp",name:"fake"));do { try validateCurrency(hero);fatalError("Invalid wallet accepted") } catch {}
        var creature=Creature();creature.imageLayout = .right
        let copy=try JSONDecoder().decode(Creature.self,from:JSONEncoder().encode(creature));assert(copy.imageLayout == .right && copy.image == creature.image)
        print("PASS: exact decimal parsing, standard/custom balances, atomic spend/add/set, duplicate validation, legacy GP preservation, backup round trip, and creature layout persistence")
    }
}
