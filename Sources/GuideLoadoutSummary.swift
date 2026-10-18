import Foundation

enum GuideLoadoutSummary {
    static func spells(_ spells:[Spell],for record:CharacterClassLevel,classes:[CharacterClassLevel])->[Spell] {
        let base=ClassProfile.named(record.name)?.name ?? record.name
        return spells.filter { spell in
            if let id=spell.sourceClassID { return id == record.id }
            if let name=spell.sourceClassName,!name.isEmpty { return (ClassProfile.named(name)?.name ?? name).caseInsensitiveCompare(base) == .orderedSame }
            return classes.count == 1
        }
    }
    static func unassignedSpells(_ spells:[Spell],classes:[CharacterClassLevel])->Int {
        let assigned=Set(classes.flatMap { self.spells(spells,for:$0,classes:classes) }.map(\.id))
        return spells.filter { !assigned.contains($0.id) }.count
    }
    static func quantity(_ items:[Item])->Int { items.reduce(0) { $0+$1.quantity } }
    static func weight(_ items:[Item])->Double { items.reduce(0) { $0+Double($1.quantity)*$1.weight } }
}
