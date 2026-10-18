import Foundation

struct NamedRoll: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "Roll"
    var expression = "1d20"
    var slotLevel: Int?
    var minimumCharacterLevel: Int?
    var kind: D20Kind?
    var ability: Int?
    var resourceCost:ResourceCost?
}
enum FeatureCategory:String,Codable,CaseIterable { case ancestry = "Race / ancestry", classFeature = "Class", feat = "Feat", background = "Background", other = "Other" }
struct CharacterFeature: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "New feature"
    var text = ""
    var rolls: [NamedRoll]?
    var counter: ResourceCounter?
    var category: FeatureCategory?
    var source: String?
    var training:[TrainingGrant]?
    var timing:ActionTiming?
    var resourceCost:ResourceCost?
    var parentFeatureID:UUID?
    var effectMode:FeatureEffectMode?
    var effects:[FeatureEffect]?
}
struct HitDicePool: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var sides: Int
    var total: Int
    var used = 0
}
enum CastMode: String, CaseIterable { case slot = "Spell slot", ritual = "Ritual", free = "Without slot" }
enum ActionError: LocalizedError {
    case noSlots, noFreeUses, notRitual, invalidRoll(String), missingSpell, cannotAct
    var errorDescription: String? {
        switch self {
        case .noSlots: return "No spell slots remain at the required level or higher. Take a long rest, restore a slot, or choose a configured ritual/free use."
        case .noFreeUses: return "No free uses remain. Restore uses with a long rest, or edit this spell’s free-use settings."
        case .notRitual: return "This spell is not marked as a ritual."
        case .invalidRoll(let text): return "Invalid roll: \(text). Use dice notation and tokens such as {spell}, {int}, {prof}, {level}, or {slot}."
        case .missingSpell: return "This spell is no longer in the spellbook."
        case .cannotAct: return "An active condition prevents actions. Remove the condition when it ends; casting and attacks have not consumed resources."
        }
    }
}
extension Hero {
    func cantripRoll(_ spell:Spell,at characterLevel:Int) -> NamedRoll? {
        guard spell.level == 0 else { return nil }
        return (spell.rolls ?? []).filter { $0.minimumCharacterLevel != nil && $0.minimumCharacterLevel! <= characterLevel }.max { $0.minimumCharacterLevel! < $1.minimumCharacterLevel! }
    }
    func resolveRoll(_ expression: String, spell: Spell? = nil, slot: Int = 0) throws -> String {
        var result = expression.lowercased()
        let casting = spell?.castingAbility ?? castingAbility
        let values: [String:Int] = ["str":modifier(0),"dex":modifier(1),"con":modifier(2),"int":modifier(3),"wis":modifier(4),"cha":modifier(5),"prof":proficiency,"spell":modifier(casting),"attack":proficiency+modifier(casting)+flat(["attack","spellAttack"]),"dc":8+proficiency+modifier(casting)+flat(["spellDC"]),"level":level,"slot":slot]
        for (key,value) in values { result = result.replacingOccurrences(of:"{\(key)}",with:String(value)) }
        result = result.replacingOccurrences(of:"%0",with:String(modifier(casting)))
        for _ in 0..<3 { result = result.replacingOccurrences(of:"+-",with:"-").replacingOccurrences(of:"--",with:"+").replacingOccurrences(of:"-+",with:"-").replacingOccurrences(of:"++",with:"+") }
        guard (try? Dice.roll(result)) != nil else { throw ActionError.invalidRoll(expression) }
        return result
    }
    func availableSlot(for spell: Spell) -> Int? { (max(1,spell.level)...9).first { slots[$0-1] > usedSlots[$0-1] } }
    func defaultCastMode(_ spell: Spell) -> CastMode { spell.usesSlot == false ? .free:.slot }
    mutating func cast(_ id: UUID, mode: CastMode = .slot, at chosenLevel: Int? = nil,cantripLevel:Int? = nil) throws -> RollResult {
        guard canAct else { throw ActionError.cannotAct }
        guard let index = spells.firstIndex(where:{ $0.id == id }) else { throw ActionError.missingSpell }
        let spell = spells[index]
        var castLevel = spell.level
        if spell.level > 0 {
            switch mode {
            case .slot:
                guard let candidate = chosenLevel ?? availableSlot(for:spell), (spell.level...9).contains(candidate), slots[candidate-1] > usedSlots[candidate-1] else { throw ActionError.noSlots }
                castLevel = candidate
            case .ritual: guard spell.ritual == true else { throw ActionError.notRitual }
            case .free:
                guard spell.usesSlot == false || (spell.freeUses ?? 0) > 0 else { throw ActionError.noFreeUses }
                if let maximum = spell.freeUses, maximum > 0, (spell.freeRemaining ?? maximum) <= 0 { throw ActionError.noFreeUses }
            }
        }
        // Resolve and validate before consuming any resource.
        let automatic = (spell.level == 0 && cantripLevel != nil ? cantripRoll(spell,at:cantripLevel!):nil) ?? (spell.rolls ?? []).first { $0.id == spell.automaticRollID }
        let resolved = try automatic.map { try resolveRoll($0.expression,spell:spell,slot:castLevel) }
        let costs = [spell.resourceCost,automatic?.resourceCost].compactMap { $0 }
        try checkResources(costs)
        var result = try automatic.map { try performNamedRoll($0,source:spell.name,spell:spell,slot:castLevel) } ?? RollResult(label:"Cast \(spell.name)",expression:spell.level == 0 ? "Cantrip cast · no spell slot required" : mode == .slot ? "Level \(castLevel) slot" : mode == .ritual ? "Ritual · add ritual casting time" : "Free use · no slot",dice:[],total:0,event:true)
        spendResources(costs)
        if spell.level > 0 {
            if mode == .slot { usedSlots[castLevel-1] += 1 }
            else if mode == .free, let maximum = spell.freeUses, maximum > 0 { spells[index].freeRemaining = (spell.freeRemaining ?? maximum)-1 }
        }
        if resolved != nil { result.label += spell.level > 0 ? " · \(mode == .slot ? "slot \(castLevel)":mode.rawValue)" : " · cantrip, no slot" }
        if spell.requiresConcentration {
            let previous = concentratingSpell?.name
            pendingConcentrationSaves = nil
            concentrationSpellID = spell.id
            result.detail = "Concentration: "+spell.name+(previous != nil && previous != spell.name ? " · replaces "+previous!:"")
        }
        noteAction(SheetActionRef(kind:.spell,sourceID:spell.id))
        return result
    }
    mutating func spendHitDie(_ poolID: UUID) throws -> RollResult {
        try spendHitDice(poolID,count:1)
    }
    mutating func spendHitDice(_ poolID:UUID?,count:Int) throws -> RollResult {
        let poolIndex = hitDicePools?.firstIndex { $0.id == poolID }
        let hasPools = !(hitDicePools ?? []).isEmpty
        guard count > 0, count <= 20, !hasPools || poolIndex != nil else { throw CocoaError(.formatting) }
        let available = poolIndex.map { hitDicePools![$0].total-hitDicePools![$0].used } ?? level-hitDiceUsed
        guard count <= available else { throw CocoaError(.formatting) }
        let sides = poolIndex.map { hitDicePools![$0].sides } ?? hitDie
        let rolls = try (0..<count).map { _ in try Dice.roll("1d\(sides)\(signed(modifier(2)))") }
        let healing = rolls.reduce(0) { $0+max(0,$1.total) }
        if let i = poolIndex { hitDicePools![i].used += count; hitDiceUsed = hitDicePools!.reduce(0) { $0+$1.used } }
        else { hitDiceUsed += count }
        hp = min(maximumHP,hp+healing)
        return RollResult(label:"Hit dice · healing",expression:"\(count) × (1d\(sides)\(signed(modifier(2))))",dice:rolls.flatMap(\.dice),total:healing,sides:Array(repeating:sides,count:count),detail:"Each die adds CON; minimum 0 healing per die")
    }
}
func validRolls(_ rolls: [NamedRoll]?, hero: Hero, spell: Spell? = nil) -> Bool {
    let all = rolls ?? []
    return Set(all.map(\.id)).count == all.count && all.allSatisfy { ($0.resourceCost == nil || (1...999).contains($0.resourceCost!.amount)) && ($0.minimumCharacterLevel == nil || (1...20).contains($0.minimumCharacterLevel!)) && ($0.slotLevel == nil || (1...9).contains($0.slotLevel!)) && !$0.name.trimmingCharacters(in:.whitespaces).isEmpty && ($0.kind == nil || $0.expression.lowercased().hasPrefix("1d20")) && ($0.ability == nil || (0...5).contains($0.ability!)) && (try? hero.resolveRoll($0.expression,spell:spell,slot:max(1,spell?.level ?? 1))) != nil }
}
func validateActions(_ hero: Hero) throws {
    let saves = hero.pendingConcentrationSaves ?? []
    guard Set(saves.map(\.id)).count == saves.count, saves.allSatisfy({ $0.damage > 0 && (1...100000).contains($0.dc) }) else { throw CocoaError(.fileReadCorruptFile) }
    guard hero.spells.allSatisfy({ $0.resourceCost == nil || (1...999).contains($0.resourceCost!.amount) }), (hero.featureEntries ?? []).allSatisfy({ $0.resourceCost == nil || (1...999).contains($0.resourceCost!.amount) }), (hero.actionUsage ?? []).allSatisfy({ (1...100000).contains($0.count) }) else { throw CocoaError(.fileReadCorruptFile) }
    if let crop = hero.bannerCrop { guard crop.x.isFinite, crop.y.isFinite, crop.zoom.isFinite, (0...1).contains(crop.x), (0...1).contains(crop.y), (1...3).contains(crop.zoom) else { throw CocoaError(.fileReadCorruptFile) } }
    guard (0...6).contains(hero.exhaustionLevel ?? 0), hero.rulesEdition == nil || ["2014","2024"].contains(hero.rulesEdition!) else { throw CocoaError(.fileReadCorruptFile) }
    guard hero.spells.allSatisfy({ validRolls($0.rolls,hero:hero,spell:$0) && ($0.castingAbility == nil || (0...5).contains($0.castingAbility!)) && (0...999).contains($0.freeUses ?? 0) && (0...($0.freeUses ?? 999)).contains($0.freeRemaining ?? 0) }),
          hero.items.allSatisfy({ validRolls($0.rolls,hero:hero) }),
          (hero.featureEntries ?? []).allSatisfy({ validRolls($0.rolls,hero:hero) && ($0.counter == nil || ((1...999).contains($0.counter!.maximum) && (0...$0.counter!.maximum).contains($0.counter!.current))) }),
          (hero.hitDicePools ?? []).allSatisfy({ [6,8,10,12].contains($0.sides) && (1...20).contains($0.total) && (0...$0.total).contains($0.used) }),
          hero.sourceXML == nil || hero.sourceXML!.count <= 40_000_000 else { throw CocoaError(.fileReadCorruptFile) }
}
