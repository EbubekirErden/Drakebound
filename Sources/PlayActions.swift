import Foundation

enum ResourceKind:String,Codable { case counter,feature }
struct ResourceRef:Codable,Hashable,Identifiable {
    var kind:ResourceKind
    var id:UUID
    var key:String { kind.rawValue+id.uuidString }
}
struct ResourceCost:Codable,Equatable { var resource:ResourceRef; var amount = 1 }
struct ResourceChoice:Identifiable { var ref:ResourceRef; var counter:ResourceCounter; var id:String { ref.key } }
enum SheetActionKind:String,Codable { case attack,attackDamage,spell,itemRoll,featureRoll,spellRoll,featureUse,creatureAttack,creatureDamage,creatureFeature }
struct SheetActionRef:Codable,Hashable,Identifiable {
    var kind:SheetActionKind
    var sourceID:UUID
    var rollID:UUID?
    var creatureID:UUID?
    var id:String { kind.rawValue+sourceID.uuidString+(rollID?.uuidString ?? "")+(creatureID?.uuidString ?? "") }
    var group:SheetActionRef {
        let parent:SheetActionKind
        switch kind { case .attackDamage:parent = .attack; case .creatureDamage:parent = .creatureAttack; case .spellRoll:parent = .spell; case .featureRoll:parent = .featureUse; default:parent = kind }
        return SheetActionRef(kind:parent,sourceID:sourceID,creatureID:creatureID)
    }
}
struct ActionUsage:Codable,Equatable { var action:SheetActionRef; var count = 1; var lastUsed = Date() }
struct SheetAction:Identifiable { var ref:SheetActionRef; var name:String; var subtitle:String; var id:String { ref.id } }
enum PlayError:LocalizedError {
    case missingAction,missingResource,notEnough(String),stowed
    var errorDescription:String? {
        switch self {
        case .missingAction:return "This action is no longer available."
        case .missingResource:return "A linked resource was removed. Edit this action to choose another counter or remove the link."
        case .notEnough(let name):return "Not enough uses remain in \(name). Restore uses or choose a different resource."
        case .stowed:return "Equip the linked item before using this action."
        }
    }
}
extension Spell {
    var requiresConcentration:Bool { concentration ?? (duration.localizedCaseInsensitiveContains("concentration") || duration.lowercased().hasPrefix("c,")) }
}
extension Hero {
    mutating func reconcileConcentration() { if isIncapacitated || hp == 0 || concentratingSpell == nil { endConcentration() } else { pendingConcentrationSaves = concentrationSaves.isEmpty ? nil:concentrationSaves } }
    var concentratingSpell:Spell? { spells.first { $0.id == concentrationSpellID } }
    var resourceChoices:[ResourceChoice] {
        (counters ?? []).map { ResourceChoice(ref:ResourceRef(kind:.counter,id:$0.id),counter:$0) } + (featureEntries ?? []).compactMap { f in f.counter.map { ResourceChoice(ref:ResourceRef(kind:.feature,id:f.id),counter:$0) } }
    }
    func resource(_ ref:ResourceRef) -> ResourceCounter? { resourceChoices.first { $0.ref == ref }?.counter }
    mutating func setResource(_ ref:ResourceRef,_ counter:ResourceCounter?) {
        if ref.kind == .counter {
            if let i = counters?.firstIndex(where:{ $0.id == ref.id }) { if let counter { counters?[i] = counter } else { counters?.remove(at:i) } }
        } else if let i = featureEntries?.firstIndex(where:{ $0.id == ref.id }) { featureEntries?[i].counter = counter }
    }
    func checkResources(_ costs:[ResourceCost]) throws {
        var totals:[ResourceRef:Int] = [:]
        for cost in costs { guard (1...999).contains(cost.amount) else { throw PlayError.missingResource }; totals[cost.resource,default:0] += cost.amount }
        for (ref,amount) in totals { guard let counter = resource(ref) else { throw PlayError.missingResource }; guard counter.current >= amount else { throw PlayError.notEnough(counter.name) } }
    }
    mutating func spendResources(_ costs:[ResourceCost]) { for cost in costs { if var counter = resource(cost.resource) { counter.current -= cost.amount; setResource(cost.resource,counter) } } }
    func resourceSummary(_ cost:ResourceCost) -> String { guard let c = resource(cost.resource) else { return "Missing resource" }; return "\(cost.amount) \(c.name) · \(c.current)/\(c.maximum)" }
    mutating func noteAction(_ ref:SheetActionRef) {
        var usage = actionUsage ?? []
        let old = usage.first { $0.action == ref }; usage.removeAll { $0.action == ref }
        usage.insert(ActionUsage(action:ref,count:min(100000,(old?.count ?? 0)+1)),at:0)
        actionUsage = Array(usage.prefix(100))
    }
    mutating func toggleFavorite(_ ref:SheetActionRef) { var all = favoriteActions ?? []; if all.contains(ref) { all.removeAll { $0 == ref } } else { all.append(ref) }; favoriteActions = all }
    func actionIsFavorite(_ ref:SheetActionRef) -> Bool { (favoriteActions ?? []).contains { $0.group == ref.group } }
    func actionHistory(_ ref:SheetActionRef) -> ActionUsage? {
        let entries = (actionUsage ?? []).filter { $0.action.group == ref.group }
        guard let latest = entries.max(by:{ $0.lastUsed < $1.lastUsed }) else { return nil }
        return ActionUsage(action:ref.group,count:entries.reduce(0) { $0 + $1.count },lastUsed:latest.lastUsed)
    }
    mutating func toggleActionFavorite(_ ref:SheetActionRef) {
        if actionIsFavorite(ref) { favoriteActions?.removeAll { $0.group == ref.group } }
        else { favoriteActions = (favoriteActions ?? []) + [ref.group] }
    }
    var sheetActions:[SheetAction] {
        var result = readyAttacks.map { SheetAction(ref:SheetActionRef(kind:.attack,sourceID:$0.id),name:$0.name,subtitle:$0.isSpell == true ? "Spell attack":"Weapon attack") }
        result += spells.filter { $0.prepared || $0.level == 0 }.map { SheetAction(ref:SheetActionRef(kind:.spell,sourceID:$0.id),name:$0.name,subtitle:($0.level == 0 ? "Cantrip":"Level \($0.level) spell")+($0.time.isEmpty ? "":" · "+$0.time)) }
        for item in items where item.quantity > 0 && !(item.rolls ?? []).isEmpty { result.append(SheetAction(ref:SheetActionRef(kind:.itemRoll,sourceID:item.id),name:item.name,subtitle:"Item · \(item.quantity) carried")) }
        for feature in featureEntries ?? [] where feature.counter != nil || feature.resourceCost != nil || !(feature.rolls ?? []).isEmpty {
            result.append(SheetAction(ref:SheetActionRef(kind:.featureUse,sourceID:feature.id),name:feature.name,subtitle:feature.counter.map { "Feature · \($0.current)/\($0.maximum) uses" } ?? "Feature"))
        }
        result += creatureActions
        return result
    }
    // Contextual shortcuts only; every imported variant remains in the source details.
    func quickRolls(_ ref:SheetActionRef) -> [NamedRoll] {
        switch ref.group.kind {
        case .spell:
            guard let spell = spells.first(where:{ $0.id == ref.sourceID }) else { return [] }
            let tier = cantripRoll(spell,at:level)?.minimumCharacterLevel
            return (spell.rolls ?? []).filter { roll in
                if let minimum = roll.minimumCharacterLevel { return minimum == tier }
                if let slot = roll.slotLevel { return slots[slot-1] > 0 }
                return true
            }
        case .itemRoll:return items.first { $0.id == ref.sourceID }?.rolls ?? []
        case .featureUse:return featureEntries?.first { $0.id == ref.sourceID }?.rolls ?? []
        default:return []
        }
    }
    func namedAction(_ ref:SheetActionRef) -> (NamedRoll,String,Spell?)? {
        switch ref.kind {
        case .itemRoll: guard let item = items.first(where:{ $0.id == ref.sourceID }),let roll = item.rolls?.first(where:{ $0.id == ref.rollID }) else { return nil }; return (roll,item.name,nil)
        case .featureRoll: guard let f = featureEntries?.first(where:{ $0.id == ref.sourceID }),let roll = f.rolls?.first(where:{ $0.id == ref.rollID }) else { return nil }; return (roll,f.name,nil)
        case .spellRoll: guard let s = spells.first(where:{ $0.id == ref.sourceID }),let roll = s.rolls?.first(where:{ $0.id == ref.rollID }) else { return nil }; return (roll,s.name,s)
        default:return nil
        }
    }
    mutating func performAction(_ ref:SheetActionRef,manual:RollMode = .normal,slot:Int? = nil,critical:Bool = false) throws -> RollResult {
        if ref.kind.isCreature { return try performCreatureAction(ref,mode:manual,critical:critical) }
        if ref.kind == .spell { guard let s = spells.first(where:{ $0.id == ref.sourceID }) else { throw PlayError.missingAction }; return try cast(s.id,mode:defaultCastMode(s),cantripLevel:s.level == 0 ? level:nil) }
        let result:RollResult
        if ref.kind == .attack || ref.kind == .attackDamage {
            guard let a = attacks.first(where:{ $0.id == ref.sourceID }) else { throw PlayError.missingAction }
            guard attackUnavailableReason(a) == nil else { throw PlayError.stowed }
            guard canAct else { throw ActionError.cannotAct }
            if ref.kind == .attackDamage {
                let damage = expression(a.damage,bonus:damageBonus(a),targets:attackTargets(a,damage:true))
                result = try Dice.roll(critical ? Dice.criticalExpression(damage):damage,label:a.name+(critical ? " · critical damage":" · damage"))
            }
            else { result = try performD20(expression("1d20",bonus:attackBonus(a),targets:attackTargets(a)),label:a.name+" · attack",kind:.attack,ability:a.ability,manual:manual) }
        } else if ref.kind == .featureUse {
            guard canAct else { throw ActionError.cannotAct }
            guard let f = featureEntries?.first(where:{ $0.id == ref.sourceID }),f.counter != nil || f.resourceCost != nil else { throw PlayError.missingAction }
            var costs = [f.resourceCost].compactMap { $0 }
            if f.counter != nil { costs.append(ResourceCost(resource:ResourceRef(kind:.feature,id:f.id))) }
            try checkResources(costs); spendResources(costs)
            result = RollResult(label:f.name,expression:"Feature used · "+costs.map { resourceSummary($0) }.joined(separator:" · "),dice:[],total:0,event:true)
        } else {
            guard let (roll,source,spell) = namedAction(ref) else { throw PlayError.missingAction }
            if ref.kind == .itemRoll,let item = items.first(where:{ $0.id == ref.sourceID }),item.quantity <= 0 { throw PlayError.stowed }
            let costs = [roll.resourceCost].compactMap { $0 }
            try checkResources(costs)
            result = try performNamedRoll(roll,source:source,spell:spell,slot:slot ?? spell?.level ?? 0,manual:manual)
            spendResources(costs)
        }
        noteAction(ref); return result
    }
}

// Read-only costs for the default Cast / Use buttons and independent custom rolls.
extension Hero {
    func actionCostDetails(_ ref:SheetActionRef) -> String {
        if ref.group.kind == .spell,let spell = spells.first(where:{ $0.id == ref.sourceID }) {
            var lines:[String] = []
            if spell.level == 0 { lines.append("Cast: no spell slot") }
            else if spell.usesSlot == false {
                lines.append((spell.freeUses ?? 0) > 0 ? "Cast: 1 free use · \(spell.freeRemaining ?? spell.freeUses ?? 0)/\(spell.freeUses ?? 0) remaining":"Cast: no spell slot")
            } else if let slot = availableSlot(for:spell) {
                lines.append("Default cast: 1 level \(slot) slot · \(slots[slot-1]-usedSlots[slot-1])/\(slots[slot-1]) remaining")
            } else { lines.append("Cast: no available spell slot") }
            let automatic = (spell.level == 0 ? cantripRoll(spell,at:level):nil) ?? (spell.rolls ?? []).first { $0.id == spell.automaticRollID }
            let costs = [spell.resourceCost,automatic?.resourceCost].compactMap { $0 }
            if !costs.isEmpty { lines.append("Cast also spends: "+summarizeCosts(costs)) }
            lines.append("The cast menu lets you choose other available casting options.")
            return lines.joined(separator:"\n")
        }
        if ref.group.kind == .featureUse,let feature = featureEntries?.first(where:{ $0.id == ref.sourceID }) {
            var costs = [feature.resourceCost].compactMap { $0 }
            if feature.counter != nil { costs.append(ResourceCost(resource:ResourceRef(kind:.feature,id:feature.id))) }
            return costs.isEmpty ? "No Use cost configured. Custom rolls have their own costs.":"Use spends: "+summarizeCosts(costs)
        }
        return "Custom rolls spend only their configured resources. They do not cast a spell or spend a slot."
    }
    func summarizeCosts(_ costs:[ResourceCost]) -> String {
        var grouped:[ResourceCost] = []
        for cost in costs {
            if let i = grouped.firstIndex(where:{ $0.resource == cost.resource }) { grouped[i].amount += cost.amount }
            else { grouped.append(cost) }
        }
        return grouped.map { resourceSummary($0) }.joined(separator:" · ")
    }
}


enum ActionTiming:String,Codable,CaseIterable {
    case action = "Action",bonusAction = "Bonus action",reaction = "Reaction",legendaryAction = "Legendary action",other = "Other / unspecified"
    static func castingTime(_ text:String) -> ActionTiming {
        let time = text.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        // Only the casting-time prefix identifies timing; a reaction trigger may mention other actions.
        if time.hasPrefix("bonus action") || time.hasPrefix("1 bonus action") { return .bonusAction }
        if time.hasPrefix("reaction") || time.hasPrefix("1 reaction") { return .reaction }
        if time == "action" || time == "1 action" || time.hasPrefix("1 action,") { return .action }
        return .other
    }
}
extension Hero {
    func actionTiming(_ ref:SheetActionRef) -> ActionTiming {
        switch ref.group.kind {
        case .creatureAttack:return creatureAttack(ref)?.timing ?? .action
        case .creatureFeature:return creatureFeature(ref)?.timing ?? .other
        case .spell:return spells.first { $0.id == ref.sourceID }.map { ActionTiming.castingTime($0.time) } ?? .other
        case .attack:return attacks.first { $0.id == ref.sourceID }?.timing ?? .action
        case .itemRoll:return items.first { $0.id == ref.sourceID }?.timing ?? .other
        case .featureUse:return featureEntries?.first { $0.id == ref.sourceID }?.timing ?? .other
        default:return .other
        }
    }
    mutating func setCreatureActive(_ id:UUID,_ active:Bool) {
        guard let index = creatures?.firstIndex(where:{ $0.id == id }) else { return }
        creatures?[index].isActive = active
    }
}
