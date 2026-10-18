import Foundation

extension Hero {
    func abilityCheckBonus(_ index:Int) -> Int { modifier(index)+flat(["checks","check.\(index)"]) }
    private func effectLines(_ targets:[String]) -> [String] {
        activeBonuses.filter { targets.contains($0.target) }.map { bonus in
            var parts:[String] = []
            if bonus.amount != 0 { parts.append(signed(bonus.amount)) }
            if !bonus.dice.isEmpty { parts.append(bonus.dice+" on the roll") }
            return bonus.name+": "+(parts.isEmpty ? "+0":parts.joined(separator:" · "))
        }
    }
    func scoreExplanation(_ index:Int) -> String {
        ([abilities[index]+" ability score","Base score: \(scores[index])"]+effectLines(["score.\(index)"])+["Effective score: \(effectiveScore(index))","Ability modifier: \(signed(modifier(index)))"]).joined(separator:"\n")
    }
    private func d20Explanation(_ title:String,ability:Int,rank:Int,targets:[String],total:Int,sources:[String] = [],rollHint:Bool = true) -> String {
        var lines = [title,abilities[ability]+" modifier: "+signed(modifier(ability))]
        if rank > 0 { lines.append((rank == 2 ? "Expertise (2 × proficiency)":"Proficiency")+": "+signed(rank*proficiency)) }
        if !sources.isEmpty { lines.append("Training: "+sources.joined(separator:", ")) }
        lines += effectLines(targets)
        if testPenalty != 0 { lines.append("Exhaustion: "+signed(testPenalty)) }
        lines.append("Total modifier: "+signed(total+testPenalty))
        if rollHint { lines.append("Click to roll · hold or right-click for advantage / disadvantage") }
        return lines.joined(separator:"\n")
    }
    func checkExplanation(_ index:Int) -> String { d20Explanation(abilities[index]+" ability check",ability:index,rank:0,targets:["checks","check.\(index)"],total:abilityCheckBonus(index)) }
    func saveExplanation(_ index:Int) -> String { d20Explanation(abilities[index]+" saving throw",ability:index,rank:isSaveProficient(index) ? 1:0,targets:["saves","save.\(index)"],total:saveBonus(index),sources:trainingSources("save.\(index)")) }
    func skillExplanation(_ name:String,ability:Int) -> String { d20Explanation(name+" skill check",ability:ability,rank:effectiveSkillRank(name),targets:["checks","check.\(ability)","skill."+name],total:skillBonus(name,ability),sources:trainingSources("skill."+name)) }
    var initiativeExplanation:String { d20Explanation("Initiative check",ability:1,rank:0,targets:["initiative","checks","check.1"],total:initiative) }
    func attackExplanation(_ attack:Attack) -> String { d20Explanation(attack.name+" attack roll",ability:attack.ability,rank:attackIsProficient(attack) ? 1:0,targets:attackTargets(attack),total:attackBonus(attack)) }
    var spellAttackExplanation:String { d20Explanation("Spell attack roll",ability:castingAbility,rank:1,targets:["attack","spellAttack"],total:spellAttack,rollHint:false) }
    func damageExplanation(_ attack:Attack) -> String {
        var lines = [attack.name+" damage","Base formula: "+attack.damage]
        if attack.addDamageModifier { lines.append(abilities[attack.ability]+" modifier: "+signed(modifier(attack.ability))) }
        lines += effectLines(attackTargets(attack,damage:true))
        lines.append("Roll: "+expression(attack.damage,bonus:damageBonus(attack),targets:attackTargets(attack,damage:true)))
        return lines.joined(separator:"\n")
    }
    var armorClassExplanation:String {
        let armors = items.filter { $0.equipped && $0.quantity > 0 && $0.armorBase != nil && (!($0.requiresAttunement ?? false) || ($0.attuned ?? false)) }
        func base(_ item:Item) -> Int { (item.armorBase ?? 10)+((item.armorAddsDexterity ?? false) ? min(modifier(1),item.armorDexterityCap ?? 20):0) }
        var lines = ["Armor class"]
        if let armor = armors.max(by:{ base($0) < base($1) }) {
            lines.append(armor.name+" base: \(armor.armorBase ?? 10)")
            if armor.armorAddsDexterity == true { lines.append("Dexterity (cap \(armor.armorDexterityCap ?? 20)): "+signed(min(modifier(1),armor.armorDexterityCap ?? 20))) }
        } else { lines.append("Configured base AC: \(ac)") }
        lines += effectLines(["ac"]); lines.append("Total AC: \(armorClass)")
        return lines.joined(separator:"\n")
    }
    var spellDCExplanation:String { (["Spell save DC","Base: 8","Proficiency: "+signed(proficiency),abilities[castingAbility]+" modifier: "+signed(modifier(castingAbility))]+effectLines(["spellDC"])+["Total DC: \(spellDC)"]).joined(separator:"\n") }
}
