import Foundation

enum CreatureResolution:String,Codable,CaseIterable { case attack = "Attack roll",damage = "Save / damage only" }
extension SheetActionKind {
    var isCreature:Bool { self == .creatureAttack || self == .creatureDamage || self == .creatureFeature }
}
extension Hero {
    var creatureActions:[SheetAction] {
        (creatures ?? []).filter(\.isActive).flatMap { creature in
            creature.attacks.map { attack in
                SheetAction(ref:SheetActionRef(kind:.creatureAttack,sourceID:attack.id,creatureID:creature.id),name:attack.name,subtitle:creature.name+" · "+(attack.timing ?? .action).rawValue)
            } + (creature.traits ?? []).filter { $0.timing != nil || $0.counter != nil || $0.resourceCost != nil }.map { feature in
                SheetAction(ref:SheetActionRef(kind:.creatureFeature,sourceID:feature.id,creatureID:creature.id),name:feature.name,subtitle:creature.name+" · "+(feature.timing ?? .other).rawValue)
            }
        }
    }
    func creatureSource(_ ref:SheetActionRef) -> Creature? { (creatures ?? []).first { $0.id == ref.creatureID } }
    func creatureAttack(_ ref:SheetActionRef) -> CreatureAttack? { guard ref.group.kind == .creatureAttack else { return nil }; return creatureSource(ref)?.attacks.first { $0.id == ref.sourceID } }
    func creatureFeature(_ ref:SheetActionRef) -> CharacterFeature? { guard ref.group.kind == .creatureFeature else { return nil }; return creatureSource(ref)?.traits?.first { $0.id == ref.sourceID } }
    mutating func performCreatureAction(_ ref:SheetActionRef,mode:RollMode,critical:Bool = false) throws -> RollResult {
        guard let ci = creatures?.firstIndex(where:{ $0.id == ref.creatureID }),let creature = creatures?[ci],creature.isActive,creature.hp > 0 else { throw PlayError.missingAction }
        let result:RollResult
        if let attack = creatureAttack(ref) {
            if ref.kind == .creatureDamage {
                guard !critical || attack.resolution != .damage else { throw PlayError.missingAction }
                result = try Dice.roll(critical ? Dice.criticalExpression(attack.damage):attack.damage,label:creature.name+" · "+attack.name+(critical ? " · critical damage":" · damage"))
            } else {
                guard attack.resolution != .damage else { throw PlayError.missingAction }
                result = try Dice.d20("1d20"+signed(attack.bonus),label:creature.name+" · "+attack.name+" · attack",mode:mode)
            }
        } else if let feature = creatureFeature(ref),let fi = creature.traits?.firstIndex(where:{ $0.id == ref.sourceID }) {
            let costs = [feature.resourceCost].compactMap { $0 }
            try checkResources(costs)
            if let counter = feature.counter, counter.current <= 0 { throw PlayError.notEnough(counter.name) }
            spendResources(costs)
            if let counter = feature.counter { creatures?[ci].traits?[fi].counter?.current = counter.current-1 }
            result = RollResult(label:creature.name+" · "+feature.name,expression:(feature.timing ?? .other).rawValue+" used",dice:[],total:0,event:true)
        } else { throw PlayError.missingAction }
        noteAction(ref); return result
    }
}
