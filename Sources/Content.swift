import Foundation

struct JournalEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = "Untitled note"
    var description = ""
    var image: Data?
    var richText: Data?
    var pinned: Bool?
    var tags: [String]?
    var normalizedTags:[String] { Self.parseTags((tags ?? []).joined(separator:",")) }
    static func parseTags(_ text:String) -> [String] {
        var seen = Set<String>()
        return text.split(separator:",").compactMap { part in
            let tag = part.trimmingCharacters(in:.whitespacesAndNewlines).trimmingCharacters(in:CharacterSet(charactersIn:"#"))
            guard !tag.isEmpty,seen.insert(tag.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX"))).inserted else { return nil }
            return tag
        }
    }
    func matchesJournalSearch(_ search:String,tag:String? = nil) -> Bool {
        (tag == nil || normalizedTags.contains { $0.localizedCaseInsensitiveCompare(tag!) == .orderedSame }) &&
        (search.isEmpty || title.localizedCaseInsensitiveContains(search) || description.localizedCaseInsensitiveContains(search) || normalizedTags.contains { $0.localizedCaseInsensitiveContains(search) })
    }
}
struct CreatureAttack: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "Attack"
    var bonus = 2
    var damage = "1d6"
    var description: String?
    var timing:ActionTiming?
    var resolution:CreatureResolution?
}
enum CreatureImageLayout:String,Codable,CaseIterable { case banner="Banner",left="Left portrait",right="Right portrait" }
struct Creature: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "New creature"
    var kind = "Companion"
    var type = ""
    var hp = 10
    var maximumHP = 10
    var ac = 10
    var speed = 30
    var scores = [10,10,10,10,10,10]
    var attacks: [CreatureAttack] = []
    var description = ""
    var image: Data?
    var bannerCrop: BannerCrop?
    var imageLayout:CreatureImageLayout?
    var traits: [CharacterFeature]?
    var active: Bool?
    var isActive: Bool {
        get { active ?? true }
        set { active = newValue ? nil:false }
    }
    var isSummon: Bool { kind.caseInsensitiveCompare("Summon") == .orderedSame }
    func modifier(_ index: Int) -> Int { Int(floor(Double(scores[index]-10)/2)) }
    mutating func damage(_ amount: Int) { hp = max(0,hp-max(0,amount)) }
    mutating func heal(_ amount: Int) { hp = min(maximumHP,hp+max(0,amount)) }
}
extension Hero {
    mutating func migrateContent() {
        migrateRecognizedFeatureEffects()
        migrateEquipmentContainers()
        for i in attacks.indices where attacks[i].equipmentID == nil && attacks[i].isSpell != true {
            let matches = items.filter { $0.name.caseInsensitiveCompare(attacks[i].name) == .orderedSame }
            if matches.count == 1 { attacks[i].equipmentID = matches[0].id }
        }
        if spells.contains(where:{ $0.sourceClassID == nil }),let sourceXML,let root = try? XMLTree.parse(sourceXML) {
            let character = root.name == "character" ? root:root.nodes("character").first { $0.value("name") == name }
            for scope in character?.nodes("class") ?? [] {
                let names = Set(scope.nodes("spell").map { $0.value("name") })
                let className = scope.value("name")
                for i in spells.indices where spells[i].sourceClassID == nil && names.contains(spells[i].name) {
                    spells[i].sourceClassName = className
                    spells[i].sourceClassID = progressionClasses.first { $0.name == className }?.id
                }
            }
        }
        if sourceXML != nil && (items.contains { $0.kind == nil } || attacks.contains { $0.description == nil } || (creatures ?? []).contains { $0.traits == nil || $0.attacks.contains { $0.description == nil } }) { migrateReferenceMetadata() }
        if journalEntries == nil {
            journalEntries = notes.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? [] : [JournalEntry(title:"Earlier notes",description:notes)]
        }
        if featureEntries == nil { featureEntries = features.isEmpty ? [] : [CharacterFeature(name:"Features & traits",text:features)] }
        if featureEntries != nil { for i in featureEntries!.indices where featureEntries![i].category == .feat && featureEntries![i].source == name { featureEntries![i].source = "Feat" } }
        if let sourceXML, featureEntries?.contains(where:{ $0.category == nil }) == true, let root = try? XMLTree.parse(sourceXML) {
            let character = root.name == "character" ? root:root.nodes("character").first(where:{ $0.value("name") == name })
            var sources:[String:(FeatureCategory,String)] = [:]
            if let character {
                for scope in [character]+character.nodes("race")+character.nodes("class")+character.nodes("background") {
                    let category:FeatureCategory = scope.name == "race" ? .ancestry:scope.name == "class" ? .classFeature:scope.name == "background" ? .background:.feat
                    for feat in scope.nodes("feat") { sources[feat.value("name")+"\n"+feat.texts("text")] = (category,category == .feat ? "Feat":scope.value("name")) }
                }
            }
            for i in featureEntries!.indices where featureEntries![i].category == nil {
                if let match = sources[featureEntries![i].name+"\n"+featureEntries![i].text] { featureEntries![i].category = match.0; featureEntries![i].source = match.1 }
            }
        }
    }
}
func validateContent(_ hero: Hero) throws {
    let entries = hero.journalEntries ?? []; let creatures = hero.creatures ?? []
    guard Set(entries.map(\.id)).count == entries.count,
          Set(creatures.map(\.id)).count == creatures.count,
          hero.portrait == nil || hero.portrait!.count <= 5_000_000,
          entries.allSatisfy({ ($0.image == nil || $0.image!.count <= 5_000_000) && ($0.richText == nil || $0.richText!.count <= 5_000_000) }) else { throw CocoaError(.fileReadCorruptFile) }
    for c in creatures {
        if let crop = c.bannerCrop { guard crop.x.isFinite,crop.y.isFinite,crop.zoom.isFinite,(0...1).contains(crop.x),(0...1).contains(crop.y),(1...3).contains(crop.zoom) else { throw CocoaError(.fileReadCorruptFile) } }
        let traits = c.traits ?? []
        guard Set(traits.map(\.id)).count == traits.count,
              traits.allSatisfy({ ($0.counter == nil || ((1...999).contains($0.counter!.maximum) && (0...$0.counter!.maximum).contains($0.counter!.current))) && ($0.resourceCost == nil || (1...999).contains($0.resourceCost!.amount)) }) else { throw CocoaError(.fileReadCorruptFile) }
        guard (1...99999).contains(c.maximumHP), (0...99999).contains(c.hp), (0...50).contains(c.ac),
              (0...999).contains(c.speed), c.scores.count == 6, c.scores.allSatisfy({ (1...30).contains($0) }),
              c.image == nil || c.image!.count <= 5_000_000,
              Set(c.attacks.map(\.id)).count == c.attacks.count,
              c.attacks.allSatisfy({ (-100...100).contains($0.bonus) && (try? Dice.roll($0.damage)) != nil }) else { throw CocoaError(.fileReadCorruptFile) }
    }
}
