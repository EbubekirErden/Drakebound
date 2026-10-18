import Foundation

struct CompendiumPick:Identifiable {
    var id:UUID { entry?.id ?? spell!.id }
    var name:String { entry?.name ?? spell!.name }
    var entry:CompendiumEntry?
    var spell:Spell?
    init(_ entry:CompendiumEntry) { self.entry = entry }
    init(spell:Spell) { self.spell = spell }
}
struct CompendiumAddRequest:Identifiable {
    var id = UUID()
    var picks:[CompendiumPick]
    var throughLevel:Int?
}
struct CompendiumAddSummary {
    var spells = 0; var items = 0; var creatures = 0; var features = 0; var skipped = 0; var needsReview = 0
    var total:Int { spells+items+creatures+features }
    var text:String {
        let parts = [(spells,"spells"),(items,"items"),(creatures,"creatures"),(features,"features")].filter { $0.0 > 0 }.map { "\($0.0) \($0.0 == 1 ? String($0.1.dropLast()):$0.1)" }
        return (parts.isEmpty ? "No new entries":parts.joined(separator:", "))+(skipped > 0 ? " · \(skipped) duplicates skipped":"")+(needsReview > 0 ? " · \(needsReview) spells need level review":"")
    }
}
enum CompendiumTransfer {
    static func applying(_ picks:[CompendiumPick],to original:Hero,through level:Int) throws -> (Hero,CompendiumAddSummary) {
        guard !picks.isEmpty,picks.count <= 200,(1...20).contains(level) else { throw CocoaError(.fileReadCorruptFile) }
        var hero = original; var summary = CompendiumAddSummary(); var seen:Set<UUID> = []
        for pick in picks where seen.insert(pick.id).inserted {
            if let spell = pick.spell ?? pick.entry.flatMap({ $0.category == .spell ? $0.spell():nil }) {
                if hero.spells.contains(where:{ $0.name.caseInsensitiveCompare(spell.name) == .orderedSame && $0.level == spell.level && $0.text == spell.text }) { summary.skipped += 1; continue }
                var copy = spell; copy.id = UUID(); copy.sourceClassID = nil; copy.sourceClassName = nil; copy.resourceCost = nil; copy.rolls = cleanResourceLinks(copy.rolls); copy.freeRemaining = copy.freeUses
                hero.spells.append(copy); summary.spells += 1
            } else if let entry = pick.entry {
                switch entry.category {
                case .spell:summary.needsReview += 1 // Missing XML level is not silently treated as a cantrip.
                case .item:hero.items.append(entry.item()); summary.items += 1
                case .monster:hero.creatures = (hero.creatures ?? [])+[entry.creature()]; summary.creatures += 1
                default:
                    var existing = hero.featureEntries ?? []
                    for feature in entry.featureCopies(through:level) {
                        if existing.contains(where:{ $0.name == feature.name && $0.source == feature.source && $0.text == feature.text }) { summary.skipped += 1 }
                        else { existing.append(feature); summary.features += 1 }
                    }
                    hero.replaceFeatures(existing)
                }
            }
        }
        try validate(Archive(heroes:[hero],library:[]))
        return (hero,summary)
    }
}
