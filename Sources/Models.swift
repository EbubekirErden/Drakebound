import Foundation

let abilities = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"]
let skills: [(String, Int)] = [("Acrobatics",1),("Animal Handling",4),("Arcana",3),("Athletics",0),("Deception",5),("History",3),("Insight",4),("Intimidation",5),("Investigation",3),("Medicine",4),("Nature",3),("Perception",4),("Performance",5),("Persuasion",5),("Religion",3),("Sleight of Hand",1),("Stealth",1),("Survival",4)]
func signed(_ n: Int) -> String { n >= 0 ? "+\(n)" : "\(n)" }

struct Spell: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var level: Int
    var school = "Evocation"
    var time = "1 action"
    var range = "60 feet"
    var duration = "Instantaneous"
    var components = "V, S"
    var text = ""
    var prepared = true
    var rolls: [NamedRoll]?
    var automaticRollID: UUID?
    var ritual: Bool?
    var usesSlot: Bool?
    var freeUses: Int?
    var freeRemaining: Int?
    var castingAbility: Int?
    var classes:String?
    var sourceClassID:UUID?
    var sourceClassName:String?
    var exemptFromClassLimit:Bool?
    var concentration:Bool?
    var resourceCost:ResourceCost?
}
struct Item: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var quantity = 1
    var weight = 0.0
    var equipped = false
    var notes = ""
    var bonuses: [Bonus]?
    var armorBase: Int?
    var armorAddsDexterity: Bool?
    var armorDexterityCap: Int?
    var requiresAttunement: Bool?
    var attuned: Bool?
    var rolls: [NamedRoll]?
    var kind: EquipmentKind?
    var sourceType: String?
    var timing:ActionTiming?
    var containerID: UUID?
}
struct Attack: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var ability = 0
    var proficient = true
    var addDamageModifier = true
    var damage = "1d8"
    var type = "Slashing"
    var isSpell: Bool?
    var description: String?
    var equipmentID:UUID?
    var timing:ActionTiming?
}
struct Hero: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "New adventurer"
    var ancestry = "Human"
    var characterClass = "Fighter"
    var background = "Soldier"
    var alignment = "Neutral good"
    var level = 1
    var scores = [15,14,13,12,10,8]
    var skillRanks: [String:Int] = [:]
    var saveProficiencies: [Int] = [0,2]
    var hp = 12 { didSet { if oldValue == 0 && hp > 0 { deathSuccesses = 0; deathFailures = 0 } } }
    var maxHP = 12
    var tempHP = 0
    var ac = 16
    var speed = 30
    var inspiration = false
    var hitDie = 10
    var hitDiceUsed = 0
    var deathSuccesses = 0
    var deathFailures = 0
    var conditions: [String] = []
    var castingAbility = 3
    var slots = [0,0,0,0,0,0,0,0,0]
    var usedSlots = [0,0,0,0,0,0,0,0,0]
    var spells: [Spell] = []
    var items: [Item] = []
    var attacks = [Attack(name:"Longsword")]
    var gold = 15
    var features = "Second Wind\nOnce per short or long rest, use a bonus action to regain 1d10 + fighter level hit points. Track use in your notes."
    var notes = ""
    var bonuses: [Bonus]?
    var counters: [ResourceCounter]?
    var portrait: Data?
    var journalEntries: [JournalEntry]?
    var creatures: [Creature]?
    var featureEntries: [CharacterFeature]?
    var hitDicePools: [HitDicePool]?
    var sourceXML: Data?
    var importReport: String?
    var bannerCrop: BannerCrop?
    var rulesEdition: String?
    var exhaustionLevel: Int?
    var fearSourceVisible: Bool?
    var invisibleToTarget: Bool?
    var classLevels: [CharacterClassLevel]?
    var advancementHistory: [AdvancementRecord]?
    var slotsRecoverOnShortRest: Bool?
    var trainingGrants:[TrainingGrant]?
    var ancestryFacts:[ReferenceField]?
    var backgroundFacts:[ReferenceField]?
    var equipmentContainers:[EquipmentContainer]?
    var pendingConcentrationSaves:[ConcentrationSave]?
    var concentrationSaveAdvantage:Bool?
    var concentrationSpellID:UUID?
    var actionUsage:[ActionUsage]?
    var favoriteActions:[SheetActionRef]?
    var proficiency: Int { 2 + (max(1, level)-1)/4 }
    func modifier(_ index: Int) -> Int { Int(floor(Double(effectiveScore(index)-10)/2)) }
    func skillBonus(_ name: String, _ ability: Int) -> Int { modifier(ability) + effectiveSkillRank(name) * proficiency + flat(["checks", "check.\(ability)", "skill.\(name)"]) }
    var passivePerception: Int { 10 + skillBonus("Perception",4) + testPenalty + (rollMode(for:.check) == .disadvantage ? -5:rollMode(for:.check) == .advantage ? 5:0) }
    var spellDC: Int { 8 + proficiency + modifier(castingAbility) + flat(["spellDC"]) }
    mutating func longRest() { recoverRest(full:false) }
    mutating func fullRest() { recoverRest(full:true) }
    private mutating func recoverRest(full:Bool) {
        endConcentration()
        if full { exhaustionLevel = 0 }
        else if (exhaustionLevel ?? 0) > 0 { exhaustionLevel = max(0,(exhaustionLevel ?? 0)-1) }
        hp = maximumHP; tempHP = 0; usedSlots = Array(repeating:0,count:9)
        hitDiceUsed = full || edition == "2024" ? 0:max(0, hitDiceUsed - max(1,level/2))
        deathSuccesses = 0; deathFailures = 0
        resetCounters(for:full ? .fullRest:.longRest)
        for i in spells.indices { if let maximum = spells[i].freeUses { spells[i].freeRemaining = maximum } }
        if hitDicePools != nil {
            var recover = full || edition == "2024" ? level:max(1,level/2)
            for i in hitDicePools!.indices { let amount = min(recover,hitDicePools![i].used); hitDicePools![i].used -= amount; recover -= amount }
            hitDiceUsed = hitDicePools!.reduce(0) { $0 + $1.used }
        }
    }
    mutating func damage(_ amount: Int) {
        guard amount > 0 else { return }
        let remaining = max(0, amount - tempHP)
        tempHP = max(0, tempHP - amount); hp = max(0, hp - remaining)
        if hp == 0 { endConcentration() }
        else { queueConcentrationSave(damage:amount) }
    }
    static var sample: Hero {
        var h = Hero()
        h.name = "Aelar Windrunner"; h.ancestry = "High elf"; h.characterClass = "Wizard"
        h.background = "Sage"; h.level = 5; h.scores = [8,14,14,18,12,10]
        h.hp = 28; h.maxHP = 32; h.ac = 12; h.hitDie = 6; h.saveProficiencies = [3,4]
        h.skillRanks = ["Arcana":1,"History":1,"Investigation":1,"Perception":1]
        h.slots = [4,3,2,0,0,0,0,0,0]; h.usedSlots = [1,0,0,0,0,0,0,0,0]
        h.spells = Array(starterSpells.prefix(6))
        h.attacks = [Attack(name:"Quarterstaff",damage:"1d6",type:"Bludgeoning"), Attack(name:"Fire bolt",ability:3,addDamageModifier:false,damage:"2d10",type:"Fire",isSpell:true)]
        h.items = [Item(name:"Quarterstaff",weight:4,equipped:true),Item(name:"Spellbook",weight:3),Item(name:"Explorer’s pack",weight:59),Item(name:"Arcane focus",weight:1,equipped:true),Item(name:"Healing potion",quantity:2,weight:0.5,notes:"Use your table’s rules for drinking a potion.")]
        h.gold = 85
        h.features = "Arcane Recovery\nOnce per day after a short rest, recover expended spell slots with a combined level of 3 or less. Choose the slots in your spellbook.\n\nFey Ancestry\nAdvantage on saving throws against being charmed; magic cannot put you to sleep.\n\nTrance\nElves meditate deeply for 4 hours a day."
        h.notes = "THE ROAD TO PHANDALIN\n\nA weathered map, a missing friend, and a promise to keep.\n\nAllies\n• Gundren — last seen on the Triboar Trail\n\nSession notes\n"
        return h
    }
}

// Short original summaries; this is a starter library, not a full rules database.
let starterSpells = [
    Spell(name:"Fire bolt",level:0,range:"120 feet",text:"Make a ranged spell attack. On a hit, deal 1d10 fire damage. Damage increases at character levels 5, 11, and 17."),
    Spell(name:"Mage hand",level:0,school:"Conjuration",range:"30 feet",duration:"1 minute",text:"Create a spectral hand to manipulate light objects at a distance. It cannot attack or carry more than 10 pounds."),
    Spell(name:"Light",level:0,range:"Touch",duration:"1 hour",components:"V, M",text:"An object you touch sheds bright light for 20 feet and dim light for another 20 feet."),
    Spell(name:"Magic missile",level:1,range:"120 feet",text:"Create three darts of force. Each automatically hits a visible target for 1d4 + 1 force damage. Add a dart for each slot level above 1."),
    Spell(name:"Shield",level:1,school:"Abjuration",time:"1 reaction",range:"Self",duration:"1 round",text:"When hit by an attack or targeted by magic missile, gain +5 AC until your next turn begins, including against the triggering attack. Magic missile deals no damage to you."),
    Spell(name:"Misty step",level:2,school:"Conjuration",time:"1 bonus action",range:"Self",components:"V",text:"Teleport up to 30 feet to an unoccupied space you can see."),
    Spell(name:"Cure wounds",level:1,range:"Touch",text:"A creature you touch regains 1d8 + your spellcasting modifier hit points. Add 1d8 per slot level above 1. No effect on undead or constructs."),
    Spell(name:"Fireball",level:3,range:"150 feet",components:"V, S, M",text:"Creatures in a 20-foot-radius sphere make a Dexterity save. Deal 8d6 fire damage on a failure, half on a success. Add 1d6 per slot level above 3."),
    Spell(name:"Detect magic",level:1,school:"Divination",range:"Self",duration:"Concentration, up to 10 minutes",text:"Sense magic within 30 feet. An action reveals a visible magical aura and its school. Can be cast as a ritual."),
    Spell(name:"Healing word",level:1,time:"1 bonus action",range:"60 feet",components:"V",text:"One visible creature regains 1d4 + your spellcasting modifier hit points. Add 1d4 per slot level above 1. No effect on undead or constructs.")
]

struct RollResult: Identifiable { var id = UUID(); var label: String; var expression: String; var dice: [Int]; var total: Int; var sides: [Int] = []; var event = false; var detail: String?; var keptD20: Int?; var keptD20Index: Int? }
enum Dice {
    static func criticalExpression(_ expression:String) throws -> String {
        let clean = expression.lowercased().filter { !$0.isWhitespace }
        // Validate the original expression before transforming signed dice terms.
        _ = try roll(clean)
        let regex = try NSRegularExpression(pattern:"([+-]?)([0-9]+)d([0-9]+)")
        let ns = clean as NSString
        var result = clean
        for match in regex.matches(in:clean,range:NSRange(location:0,length:ns.length)).reversed() {
            let sign = ns.substring(with:match.range(at:1))
            let count = Int(ns.substring(with:match.range(at:2)))!
            let sides = ns.substring(with:match.range(at:3))
            // Keep each term within the same 100-die safety limit as ordinary rolls.
            let term = count <= 50 ? "\(sign)\(count*2)d\(sides)":"\(sign)\(count)d\(sides)\(sign == "-" ? "-":"+")\(count)d\(sides)"
            result = (result as NSString).replacingCharacters(in:match.range,with:term)
        }
        return result
    }
    static func roll(_ expression: String, label: String = "Custom roll") throws -> RollResult {
        let clean = expression.lowercased().filter { !$0.isWhitespace }
        let regex = try NSRegularExpression(pattern:"([+-]?)([0-9]+d[0-9]+|[0-9]+)")
        let ns = clean as NSString
        let matches = regex.matches(in:clean,range:NSRange(location:0,length:ns.length))
        guard !matches.isEmpty, matches.map({ ns.substring(with:$0.range) }).joined() == clean else { throw CocoaError(.formatting) }
        var total = 0; var dice: [Int] = []; var sides: [Int] = []
        for m in matches {
            let sign = ns.substring(with:m.range(at:1)) == "-" ? -1 : 1
            let token = ns.substring(with:m.range(at:2))
            if token.contains("d") {
                let parts = token.split(separator:"d").compactMap { Int($0) }
                guard parts.count == 2, (1...100).contains(parts[0]), (2...1000).contains(parts[1]) else { throw CocoaError(.formatting) }
                for _ in 0..<parts[0] { let die = Int.random(in:1...parts[1]); dice.append(die * sign); sides.append(parts[1]); total += die * sign }
            } else { guard let value = Int(token), value <= 100000 else { throw CocoaError(.formatting) }; total += sign * value }
        }
        return RollResult(label:label,expression:clean,dice:dice,total:total,sides:sides)
    }
}

struct Archive: Codable { var version = 1; var heroes: [Hero]; var library: [Spell]; var compendium:[CompendiumEntry]? }
func validate(_ archive: Archive) throws {
    guard archive.version == 1, !archive.heroes.isEmpty,
          Set(archive.heroes.map(\.id)).count == archive.heroes.count else { throw CocoaError(.fileReadCorruptFile) }
    for h in archive.heroes {
        try validateInventory(h)
        try validateContent(h)
        try validateActions(h)
        try validateProgression(h)
        let allBonuses = (h.bonuses ?? []) + h.items.flatMap { $0.bonuses ?? [] }
        guard allBonuses.allSatisfy({ b in (-100...100).contains(b.amount) && (baseBonusTargets.contains(where:{ $0.0 == b.target }) || b.target.hasPrefix("attack.") || b.target.hasPrefix("damage.")) && (b.dice.isEmpty || (allowsBonusDice(b.target) && (try? Dice.roll(b.dice)) != nil)) }),
              (h.counters ?? []).allSatisfy({ (1...999).contains($0.maximum) && (0...$0.maximum).contains($0.current) }),
              h.items.allSatisfy({ ($0.armorBase == nil || (0...30).contains($0.armorBase!)) && ($0.armorDexterityCap == nil || (0...20).contains($0.armorDexterityCap!)) }) else { throw CocoaError(.fileReadCorruptFile) }
        guard h.scores.count == 6, h.slots.count == 9, h.usedSlots.count == 9,
              (1...20).contains(h.level), (0...5).contains(h.castingAbility), h.maxHP > 0,
              h.scores.allSatisfy({ (1...30).contains($0) }),
              h.skillRanks.values.allSatisfy({ (0...2).contains($0) }),
              h.saveProficiencies.allSatisfy({ (0...5).contains($0) }),
              [6,8,10,12].contains(h.hitDie), (0...20).contains(h.hitDiceUsed),
              (0...100000).contains(h.hp), (0...999).contains(h.tempHP), h.maxHP <= 999,
              h.items.allSatisfy({ (0...999).contains($0.quantity) && $0.weight.isFinite && (0...100000).contains($0.weight) }),
              h.attacks.allSatisfy({ (0...5).contains($0.ability) }),
              h.spells.allSatisfy({ (0...9).contains($0.level) }),
              h.slots.allSatisfy({ (0...20).contains($0) }),
              h.usedSlots.allSatisfy({ (0...20).contains($0) }) else { throw CocoaError(.fileReadCorruptFile) }
    }
    guard archive.library.allSatisfy({ (0...9).contains($0.level) }) else { throw CocoaError(.fileReadCorruptFile) }
}

final class SpellXML: NSObject, XMLParserDelegate {
    func schoolName(_ code: String) -> String { let trimmed = code.trimmingCharacters(in:.whitespacesAndNewlines); return ["A":"Abjuration","C":"Conjuration","D":"Divination","EN":"Enchantment","EV":"Evocation","I":"Illusion","N":"Necromancy","T":"Transmutation"][trimmed] ?? trimmed }
    var spells: [Spell] = []; var fields: [String:String] = [:]; var key = ""; var inside = false
    func parser(_ parser: XMLParser,didStartElement elementName:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]) {
        if elementName == "spell" { inside = true; fields = [:] }; key = elementName
    }
    func parser(_ parser: XMLParser,foundCharacters string:String) { if inside { fields[key,default:""] += string } }
    func parser(_ parser: XMLParser,didEndElement elementName:String,namespaceURI:String?,qualifiedName:String?) {
        if elementName == "text", inside { fields["text", default: ""] += "\n" }
        if elementName == "spell" {
            if let name = fields["name"]?.trimmingCharacters(in:.whitespacesAndNewlines), !name.isEmpty, let level = Int(fields["level",default:"0"].trimmingCharacters(in:.whitespacesAndNewlines)), (0...9).contains(level) {
                spells.append(Spell(name:name,level:level,school:schoolName(fields["school"] ?? ""),time:fields["time"] ?? "",range:fields["range"] ?? "",duration:fields["duration"] ?? "",components:fields["components"] ?? "",text:fields["text"] ?? ""))
            }; inside = false
        }
    }
}
