import Foundation

struct SpellChargeState:Codable,Equatable { var id:UUID; var remaining:Int? }
struct EquipmentPlayState:Codable,Equatable { var id:UUID; var quantity:Int; var equipped:Bool; var attuned:Bool? }
struct CreaturePlayState:Codable,Equatable { var id:UUID; var hp:Int; var active:Bool?; var traitUses:[CounterPlayState]? }
struct CounterPlayState:Codable,Equatable { var id:UUID; var current:Int }

// Deliberately excludes portraits, source XML, descriptions, and journal text.
struct CharacterPlayState:Codable,Equatable {
    var hp:Int; var tempHP:Int; var successes:Int; var failures:Int
    var inspiration:Bool; var hitDiceUsed:Int; var slots:[Int]
    var conditions:[String]; var exhaustion:Int?
    var concentration:UUID?; var pending:[ConcentrationSave]?
    var usage:[ActionUsage]?
    var pools:[HitDicePool]?
    var spells:[SpellChargeState]; var equipment:[EquipmentPlayState]
    var creatures:[CreaturePlayState]; var counters:[CounterPlayState]; var features:[CounterPlayState]
    var boundary:[String]
    init(_ h:Hero) {
        hp = h.hp; tempHP = h.tempHP; successes = h.deathSuccesses; failures = h.deathFailures
        inspiration = h.inspiration; hitDiceUsed = h.hitDiceUsed; slots = h.usedSlots
        conditions = h.conditions; exhaustion = h.exhaustionLevel
        concentration = h.concentrationSpellID; pending = h.pendingConcentrationSaves; pools = h.hitDicePools; usage = h.actionUsage
        spells = h.spells.map { SpellChargeState(id:$0.id,remaining:$0.freeRemaining) }
        equipment = h.items.map { EquipmentPlayState(id:$0.id,quantity:$0.quantity,equipped:$0.equipped,attuned:$0.attuned) }
        creatures = (h.creatures ?? []).map { CreaturePlayState(id:$0.id,hp:$0.hp,active:$0.active,traitUses:($0.traits ?? []).contains { $0.counter != nil } ? ($0.traits ?? []).compactMap { f in f.counter.map { CounterPlayState(id:f.id,current:$0.current) } }:nil) }
        counters = (h.counters ?? []).map { CounterPlayState(id:$0.id,current:$0.current) }
        features = (h.featureEntries ?? []).compactMap { f in f.counter.map { CounterPlayState(id:f.id,current:$0.current) } }
        // A setup edit forms an undo boundary, so a level-up cannot be partly reversed.
        boundary = [String(h.level),String(h.maxHP),String(h.hitDie),h.scores.description,h.slots.description,h.edition]
        boundary += (h.classLevels ?? []).map { "class:\($0.id):\($0.level)" }
        boundary += h.items.map { "item:\($0.id)" }
        boundary += (h.featureEntries ?? []).map { feature in
            "effects:"+feature.id.uuidString+":"+(feature.effectMode?.rawValue ?? "legacy")+":"+feature.resolvedEffects.map { effect in "\(effect.id):\(effect.target):\(effect.amount):\(effect.perLevel):\(effect.enabled)" }.joined(separator:";")
        }
        boundary += h.spells.map { "spell:\($0.id):\($0.freeUses ?? 0)" }
        boundary += (h.creatures ?? []).map { "creature:\($0.id):\($0.maximumHP)" }
        boundary += (h.counters ?? []).map { "counter:\($0.id):\($0.maximum)" }
        boundary += (h.featureEntries ?? []).compactMap { f in f.counter.map { "feature:\(f.id):\($0.maximum)" } }
        boundary += (h.creatures ?? []).flatMap { c in (c.traits ?? []).compactMap { f in f.counter.map { "creature-use:\(c.id):\(f.id):\($0.maximum)" } } }
        boundary += (h.hitDicePools ?? []).map { "pool:\($0.id):\($0.total):\($0.sides):\($0.name)" }
    }
    func restoring(_ current:Hero) -> Hero {
        var h = current
        h.hp = hp; h.tempHP = tempHP; h.deathSuccesses = successes; h.deathFailures = failures
        h.inspiration = inspiration; h.hitDiceUsed = hitDiceUsed; h.usedSlots = slots
        h.conditions = conditions; h.exhaustionLevel = exhaustion
        h.concentrationSpellID = concentration; h.pendingConcentrationSaves = pending; h.hitDicePools = pools; h.actionUsage = usage
        for state in spells { if let i = h.spells.firstIndex(where:{ $0.id == state.id }) { h.spells[i].freeRemaining = state.remaining } }
        for state in equipment { if let i = h.items.firstIndex(where:{ $0.id == state.id }) { h.items[i].quantity = state.quantity; h.items[i].equipped = state.equipped; h.items[i].attuned = state.attuned } }
        for state in creatures { if let i = h.creatures?.firstIndex(where:{ $0.id == state.id }) { h.creatures?[i].hp = state.hp; h.creatures?[i].active = state.active
            for use in state.traitUses ?? [] { if let fi = h.creatures?[i].traits?.firstIndex(where:{ $0.id == use.id }) { h.creatures?[i].traits?[fi].counter?.current = use.current } }
        } }
        for state in counters { if let i = h.counters?.firstIndex(where:{ $0.id == state.id }) { h.counters?[i].current = state.current } }
        for state in features { if let i = h.featureEntries?.firstIndex(where:{ $0.id == state.id }) { h.featureEntries?[i].counter?.current = state.current } }
        return h
    }
    func changes(from old:CharacterPlayState,hero:Hero) -> [String] {
        var lines:[String] = []
        if hp != old.hp { lines.append("HP \(old.hp) → \(hp)") }
        if tempHP != old.tempHP { lines.append("Temp HP \(old.tempHP) → \(tempHP)") }
        if successes != old.successes || failures != old.failures { lines.append("Death saves: \(successes) successes · \(failures) failures") }
        if inspiration != old.inspiration { lines.append(inspiration ? "Inspiration gained":"Inspiration spent") }
        for i in slots.indices where i < old.slots.count && slots[i] != old.slots[i] { lines.append("Level \(i+1) slots spent: \(old.slots[i]) → \(slots[i])") }
        if hitDiceUsed != old.hitDiceUsed { lines.append("Hit dice spent: \(old.hitDiceUsed) → \(hitDiceUsed)") }
        if concentration != old.concentration {
            let name = hero.spells.first { $0.id == concentration }?.name
            lines.append(name.map { "Concentration: "+$0 } ?? "Concentration ended")
        }
        if pending != old.pending { lines.append("Pending concentration saves: \((pending ?? []).count)") }
        if conditions != old.conditions { lines.append(conditions.isEmpty ? "Conditions cleared":"Conditions: "+conditions.joined(separator:", ")) }
        if exhaustion != old.exhaustion { lines.append("Exhaustion: \(old.exhaustion ?? 0) → \(exhaustion ?? 0)") }
        for state in spells { if let prior = old.spells.first(where:{ $0.id == state.id }),prior != state { let spell = hero.spells.first { $0.id == state.id }; lines.append("\(spell?.name ?? "Spell") free uses: \(prior.remaining ?? spell?.freeUses ?? 0) → \(state.remaining ?? spell?.freeUses ?? 0)") } }
        for state in equipment { if let prior = old.equipment.first(where:{ $0.id == state.id }),prior != state {
            let name = hero.items.first { $0.id == state.id }?.name ?? "Item"
            if prior.equipped != state.equipped { lines.append(name+(state.equipped ? " equipped":" stowed")) }
            if prior.attuned != state.attuned { lines.append(name+(state.attuned == true ? " attuned":" unattuned")) }
            if prior.quantity != state.quantity { lines.append("\(name) quantity: \(prior.quantity) → \(state.quantity)") }
        } }
        for state in creatures { if let prior = old.creatures.first(where:{ $0.id == state.id }),prior != state {
            let name = hero.creatures?.first { $0.id == state.id }?.name ?? "Creature"
            if (prior.active ?? true) != (state.active ?? true) { lines.append(name+((state.active ?? true) ? " activated":" dismissed")) }
            if prior.hp != state.hp { lines.append("\(name) HP: \(prior.hp) → \(state.hp)") }; if prior.traitUses != state.traitUses { lines.append(name+" action uses updated") }
        } }
        for state in counters { if let prior = old.counters.first(where:{ $0.id == state.id }),prior != state { lines.append("\(hero.counters?.first { $0.id == state.id }?.name ?? "Resource"): \(prior.current) → \(state.current)") } }
        for state in features { if let prior = old.features.first(where:{ $0.id == state.id }),prior != state { lines.append("\(hero.featureEntries?.first { $0.id == state.id }?.name ?? "Feature"): \(prior.current) → \(state.current)") } }
        return lines.isEmpty ? [usage != old.usage ? "Action use recorded":"Play state updated"]:lines
    }
}
struct CharacterActivity:Codable,Identifiable,Equatable {
    var id = UUID(); var heroID:UUID; var date = Date(); var title:String; var details:[String]
    var before:CharacterPlayState; var after:CharacterPlayState
    var undoable = true; var undone = false
}
enum ActivityError:LocalizedError { case stale
    var errorDescription:String? { "This change cannot be undone after a character setup edit. More recent play changes can still be undone." }
}
struct ActivityLedger:Codable,Equatable {
    var entries:[CharacterActivity] = []
    mutating func record(before:CharacterPlayState,hero:Hero,hint:String? = nil) {
        let after = CharacterPlayState(hero)
        guard before != after else { return }
        let undoable = before.boundary == after.boundary
        let details = after.changes(from:before,hero:hero)
        entries.insert(CharacterActivity(heroID:hero.id,title:undoable ? (hint ?? details[0]):"Character setup changed",details:undoable ? details:["Earlier changes remain in the log. Undo stops here to preserve your character setup."],before:before,after:after,undoable:undoable),at:0)
        var counts:[UUID:Int] = [:]
        entries = Array(entries.filter { counts[$0.heroID,default:0] += 1; return counts[$0.heroID]! <= 50 }.prefix(200))
    }
    func next(for id:UUID) -> CharacterActivity? { entries.first { $0.heroID == id && !$0.undone } }
    func canUndo(_ hero:Hero) -> Bool { guard let entry = next(for:hero.id) else { return false }; return entry.undoable && entry.after == CharacterPlayState(hero) }
    mutating func undo(_ hero:Hero) throws -> Hero {
        guard let index = entries.firstIndex(where:{ $0.heroID == hero.id && !$0.undone }),canUndo(hero) else { throw ActivityError.stale }
        let restored = entries[index].before.restoring(hero)
        try validate(Archive(heroes:[restored],library:[]))
        entries[index].undone = true
        return restored
    }
}
