import Foundation

struct GuideCatalog {
    var entries:[UUID:CompendiumEntry]
    var classes:[CompendiumEntry]; var ancestries:[CompendiumEntry]; var backgrounds:[CompendiumEntry]; var feats:[CompendiumEntry]; var items:[CompendiumEntry]
    var spells:[Spell]
    var unleveledSpells:[CompendiumEntry]
    var spellClasses:[UUID:String]
    init(compendium:[CompendiumEntry],library:[Spell]) {
        entries = Dictionary(compendium.map { ($0.id,$0) },uniquingKeysWith:{ first,_ in first })
        func list(_ category:CompendiumCategory) -> [CompendiumEntry] { compendium.filter { $0.category == category }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
        classes = list(.classEntry); ancestries = list(.race); backgrounds = list(.background); feats = list(.feat); items = list(.item)
        let lists = Dictionary(compendium.filter { $0.category == .spell }.map { ($0.id,$0.value("classes")) },uniquingKeysWith:{ first,_ in first })
        let groupedNames = Dictionary(grouping:compendium.filter { $0.category == .spell && !$0.value("classes").isEmpty },by:{ $0.name.lowercased() })
        let listsByName = groupedNames.mapValues { entries in Array(Set(entries.map { $0.value("classes") })).sorted().joined(separator:", ") }
        spells = library.map { input in
            var spell = input
            if (spell.classes ?? "").isEmpty { let exact = lists[spell.id] ?? ""; spell.classes = exact.isEmpty ? listsByName[spell.name.lowercased()]:exact }
            return spell
        }.sorted { $0.level == $1.level ? $0.name.localizedStandardCompare($1.name) == .orderedAscending:$0.level < $1.level }
        unleveledSpells = list(.spell).filter { Int($0.value("level")) == nil }
        spellClasses = Dictionary(compendium.filter { $0.category == .spell }.map { ($0.id,$0.value("classes")) },uniquingKeysWith:{ first,_ in first })
    }
    func classReference(_ name:String,edition:String) -> CompendiumEntry? {
        classes.first { $0.name.caseInsensitiveCompare(name) == .orderedSame } ?? classes.first { $0.name == name+(edition == "2024" ? " [2024]":"") }
    }
}
