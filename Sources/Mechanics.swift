import Foundation

struct Bonus: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "New bonus"
    var target = "ac"
    var amount = 1
    var dice = ""
    var enabled = true
}
enum CounterReset: String, Codable, CaseIterable {
    case manual = "Manual", shortRest = "Short rest", longRest = "Long rest", fullRest = "Full rest"
}
struct ResourceCounter: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "New resource"
    var current = 1
    var maximum = 1
    var reset = CounterReset.manual
    var resetOn: [CounterReset]?
    var restEvents: [CounterReset] {
        get { resetOn ?? (reset == .shortRest ? [.shortRest,.longRest,.fullRest] : reset == .longRest ? [.longRest,.fullRest] : reset == .fullRest ? [.fullRest] : []) }
        set { resetOn = newValue.filter { $0 != .manual } }
    }
    var resetSummary: String { restEvents.isEmpty ? "Manual reset" : restEvents.map(\.rawValue).joined(separator:" · ") }
}

let baseBonusTargets: [(String,String)] = [
    ("ac","Armor class"),("maxHP","Maximum HP"),("speed","Speed"),("initiative","Initiative"),
    ("attack","All attack rolls"),("weaponAttack","Weapon attack rolls"),("spellAttack","Spell attack rolls"),
    ("damage","All attack damage"),("weaponDamage","Weapon damage"),("spellDamage","Spell attack damage"),
    ("spellDC","Spell save DC"),("checks","All ability / skill checks"),("saves","All saving throws")
] + abilities.enumerated().flatMap { i,name in [("score.\(i)","\(name) score"),("check.\(i)","\(name) checks"),("save.\(i)","\(name) saves")] } + skills.map { ("skill.\($0.0)","\($0.0) checks") }

func allowsBonusDice(_ target: String) -> Bool {
    !["ac","maxHP","speed","spellDC"].contains(target) && !target.hasPrefix("score.")
}
extension Hero {
    var activeBonuses: [Bonus] {
        (bonuses ?? []).filter(\.enabled) + items.filter { $0.equipped && $0.quantity > 0 && (!($0.requiresAttunement ?? false) || ($0.attuned ?? false)) }.flatMap { ($0.bonuses ?? []).filter(\.enabled) }
    }
    func flat(_ targets: [String]) -> Int { activeBonuses.filter { targets.contains($0.target) }.reduce(0) { $0 + $1.amount } }
    func effectiveScore(_ i: Int) -> Int { min(30,max(1,scores[i] + flat(["score.\(i)"]))) }
    var armorClass: Int {
        let armors = items.filter { $0.equipped && $0.quantity > 0 && $0.armorBase != nil && (!($0.requiresAttunement ?? false) || ($0.attuned ?? false)) }
        let base = armors.map { item in
            (item.armorBase ?? 10) + ((item.armorAddsDexterity ?? false) ? min(modifier(1),item.armorDexterityCap ?? 20) : 0)
        }.max() ?? ac
        return max(0,base + flat(["ac"]))
    }
    var maximumHP: Int { let base = max(1,maxHP + flat(["maxHP"])); return edition == "2014" && (exhaustionLevel ?? 0) >= 4 ? max(1,base/2):base }
    var movement: Int {
        if movementPrevented { return 0 }
        let base = max(0,speed + flat(["speed"]))
        return edition == "2024" ? max(0,base-5*(exhaustionLevel ?? 0)) : (exhaustionLevel ?? 0) >= 2 ? base/2:base
    }
    var initiative: Int { modifier(1) + flat(["initiative","checks","check.1"]) }
    func saveBonus(_ i: Int) -> Int { modifier(i) + (isSaveProficient(i) ? proficiency:0) + flat(["saves","save.\(i)"]) }
    var spellAttack: Int { proficiency + modifier(castingAbility) + flat(["attack","spellAttack"]) }
    func attackTargets(_ a: Attack, damage: Bool = false) -> [String] {
        let prefix = damage ? "damage" : "attack"
        return [prefix, (a.isSpell ?? false) ? (damage ? "spellDamage":"spellAttack") : (damage ? "weaponDamage":"weaponAttack"), "\(prefix).\(a.id.uuidString)"]
    }
    func attackBonus(_ a: Attack) -> Int { modifier(a.ability) + (a.proficient ? proficiency:0) + flat(attackTargets(a)) }
    func damageBonus(_ a: Attack) -> Int { (a.addDamageModifier ? modifier(a.ability):0) + flat(attackTargets(a,damage:true)) }
    func expression(_ base: String, bonus: Int, targets: [String]) -> String {
        base + signed(bonus) + activeBonuses.filter { targets.contains($0.target) && !$0.dice.isEmpty }.map { b in
            let clean = b.dice.filter { !$0.isWhitespace }; return clean.hasPrefix("-") || clean.hasPrefix("+") ? clean : "+" + clean
        }.joined()
    }
    mutating func resetCounters(for rest: CounterReset) {
        guard rest != .manual else { return }
        if rest == .shortRest && slotsRecoverOnShortRest == true { usedSlots = Array(repeating:0,count:9) }
        if counters != nil { for i in counters!.indices where counters![i].restEvents.contains(rest) { counters![i].current = counters![i].maximum } }
        if featureEntries != nil { for i in featureEntries!.indices { if let counter = featureEntries![i].counter, counter.restEvents.contains(rest) { featureEntries![i].counter?.current = counter.maximum } } }
    }
}
