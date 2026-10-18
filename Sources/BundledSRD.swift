import Foundation

/// App resources stay separate from user-authored compendium records and character archives.
struct BundledSRD {
    let entries:[CompendiumEntry]
    let spells:[Spell]
    static func load(directory:URL) throws -> BundledSRD {
        let entries=try JSONDecoder().decode([CompendiumEntry].self,from:Data(contentsOf:directory.appendingPathComponent("srd-compendium.json")))
        guard entries.count > 1000,Set(entries.map(\.id)).count == entries.count else { throw CocoaError(.fileReadCorruptFile) }
        let spells=entries.compactMap { entry -> Spell? in
            guard var spell=entry.spell() else { return nil }
            if spell.rolls != nil { for i in spell.rolls!.indices { spell.rolls![i].id=guideID(entry.id.uuidString+"-srd-roll-\(i)") } }
            return spell
        }
        return BundledSRD(entries:entries,spells:spells)
    }
    static func load(bundle:Bundle = .main) throws -> BundledSRD {
        guard let directory=bundle.resourceURL?.appendingPathComponent("SRD"),FileManager.default.fileExists(atPath:directory.appendingPathComponent("srd-compendium.json").path) else { throw CocoaError(.fileNoSuchFile) }
        return try load(directory:directory)
    }
    static let empty=BundledSRD(entries:[],spells:[])
    func merging(entries saved:[CompendiumEntry]) -> [CompendiumEntry] {
        let ids=Set(saved.map(\.id));return saved+entries.filter { !ids.contains($0.id) }
    }
    func merging(spells saved:[Spell]) -> [Spell] {
        let ids=Set(saved.map(\.id));return saved+spells.filter { !ids.contains($0.id) }
    }
    func userEntries(_ records:[CompendiumEntry]) -> [CompendiumEntry] {
        let canonical=Dictionary(uniqueKeysWithValues:entries.map { ($0.id,$0) })
        return records.filter { canonical[$0.id] != $0 }
    }
    func userSpells(_ records:[Spell]) -> [Spell] {
        let canonical=Dictionary(uniqueKeysWithValues:spells.map { ($0.id,$0) })
        return records.filter { canonical[$0.id] != $0 }
    }
}
