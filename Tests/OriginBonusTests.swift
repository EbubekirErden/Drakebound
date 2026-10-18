import Foundation
@main struct OriginBonusTests {
    static func main() throws {
        let race=CompendiumEntry(category:.race,name:"Fixed ancestry",fields:[ReferenceField(name:"ability",text:"Charisma +2, Wisdom +1")])
        let bg=CompendiumEntry(category:.background,name:"Acolyte [2024]",fields:[ReferenceField(name:"trait",children:[ReferenceField(name:"name",text:"Ability Scores: Intelligence, Wisdom, Charisma"),ReferenceField(name:"text",text:"Increase one by 2 and another by 1, or all three by 1.")])])
        assert(GuideRules.backgroundAbilities(bg) == [3,4,5])
        var d=CharacterBuildDraft(); d.chooseOrigin(race)
        assert(d.originAdjustments == [0,0,0,0,0,0]) // Never apply legacy ancestry increases in 2024.
        d.chooseOrigin(bg);assert(d.originAbilityChoices == [3,4,5] && d.originBonusMethod == .twoOne)
        d.originAdjustments=[0,0,0,2,1,0];assert(d.originBonusProblems.isEmpty)
        let scores=d.result.scores;assert(scores == zip(d.generatedScores,d.originAdjustments).map(+))
        d.chooseOrigin(race);assert(d.originAdjustments == [0,0,0,2,1,0]) // Unrelated ancestry selection preserves background choices.
        d.originAdjustments=[2,0,0,0,1,0];assert(d.originBonusProblems.contains { $0.contains("background") })
        d.originAdjustments=[0,0,0,3,0,0];assert(!d.originBonusProblems.isEmpty)
        d.setOriginBonusMethod(.threeOnes);d.originAdjustments=[0,0,0,1,1,1];assert(d.originBonusProblems.isEmpty)
        d.abilityMethod = .manual;d.manualScores=[10,10,10,20,10,10];assert(d.originBonusProblems.contains { $0.contains("20") })
        d.setOriginBonusMethod(.custom);assert(d.originBonusProblems.isEmpty)
        d.hero.rulesEdition="2014";d.resetOriginBonuses();assert(d.originBonusMethod == .reference && d.originAdjustments == [0,0,0,0,1,2])
        d.manualScores=[10,10,10,10,10,10];assert(d.originBonusProblems.isEmpty)
        let flexible=CompendiumEntry(category:.race,name:"Mixed legacy ancestry",fields:race.fields+[ReferenceField(name:"trait",children:[ReferenceField(name:"name",text:"Ability Score Increases"),ReferenceField(name:"text",text:"Increase one ability score by 2 and a different score by 1, or increase three different scores by 1.")])])
        assert(GuideRules.flexibleAncestry(flexible) && GuideRules.fixedAncestryBonuses(flexible) == nil)
        d.chooseOrigin(flexible);assert(d.originBonusMethod == .twoOne && d.originAdjustments == [0,0,0,0,0,0])
        let human=CompendiumEntry(category:.race,name:"Human",fields:[ReferenceField(name:"ability",text:abilities.map { $0+" +1" }.joined(separator:", "))])
        assert(GuideRules.fixedAncestryBonuses(human) == Array(repeating:1,count:6))
        assert(GuideRules.fixedAncestryBonuses(CompendiumEntry(category:.race,name:"Ambiguous",fields:[ReferenceField(name:"ability",text:"Strength +2 or Wisdom +2")])) == nil)
        d.hero.rulesEdition="2024";d.chooseOrigin(CompendiumEntry(category:.background,name:"Old background",fields:[]));assert(d.originAbilityChoices == Array(0..<6))
        let old=Hero.sample;var level=CharacterBuildDraft(hero:old);level.originAdjustments=[2,1,0,0,0,0];assert(level.originBonusProblems.isEmpty && level.result.scores == old.scores)
        print("PASS: 2024 background restrictions/patterns/cap, legacy adaptation, fixed/flexible 2014 ancestry rules, explicit custom override, source changes, no double application, and level-up preservation")
    }
}
