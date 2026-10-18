import Foundation

final class XMLNode {
    let name: String
    var text = ""
    var children: [XMLNode] = []
    var attributes: [String:String] = [:]
    init(_ name: String) { self.name = name }
    func nodes(_ name:String) -> [XMLNode] { children.filter { $0.name == name } }
    func first(_ name:String) -> XMLNode? { children.first { $0.name == name } }
    func value(_ name:String) -> String { first(name)?.text.trimmingCharacters(in:.whitespacesAndNewlines) ?? "" }
    func int(_ name:String,_ fallback:Int = 0) -> Int { Int(value(name)) ?? fallback }
    func texts(_ name:String) -> String { nodes(name).map { $0.text.trimmingCharacters(in:.whitespacesAndNewlines) }.joined(separator:"\n\n") }
}
final class XMLTree: NSObject, XMLParserDelegate {
    var root: XMLNode?
    var stack: [XMLNode] = []
    static func parse(_ data:Data,limit:Int = 40_000_000) throws -> XMLNode {
        guard data.count <= limit else { throw CocoaError(.fileReadTooLarge) }
        let prefix = String(data:data,encoding:.utf8)?.uppercased() ?? ""
        guard !prefix.contains("<!DOCTYPE"), !prefix.contains("<!ENTITY") else { throw CocoaError(.fileReadCorruptFile) }
        let tree = XMLTree(); let parser = XMLParser(data:data); parser.shouldResolveExternalEntities = false; parser.delegate = tree
        guard parser.parse(), let root = tree.root else { throw parser.parserError ?? CocoaError(.fileReadCorruptFile) }
        return root
    }
    func parser(_ parser:XMLParser,didStartElement elementName:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]) { let node = XMLNode(elementName); node.attributes = attributes; if let parent = stack.last { parent.children.append(node) } else { root = node }; stack.append(node) }
    func parser(_ parser:XMLParser,foundCharacters string:String) { stack.last?.text += string }
    func parser(_ parser:XMLParser,foundCDATA CDATABlock:Data) { stack.last?.text += String(data:CDATABlock,encoding:.utf8) ?? "" }
    func parser(_ parser:XMLParser,didEndElement elementName:String,namespaceURI:String?,qualifiedName:String?) { _ = stack.popLast() }
}
struct FightClubImportResult {
    var heroes: [Hero] = []
    var spells: [Spell] = []
    var warnings: [String] = []
}
enum FightClubImport {
    static func numbers(_ value:String) -> [Int] { value.split(separator:",").map { Int($0.trimmingCharacters(in:.whitespacesAndNewlines)) ?? 0 } }
    static func school(_ code:String) -> String { ["1":"Abjuration","2":"Conjuration","3":"Divination","4":"Enchantment","5":"Evocation","6":"Illusion","7":"Necromancy","8":"Transmutation","A":"Abjuration","C":"Conjuration","D":"Divination","EN":"Enchantment","EV":"Evocation","I":"Illusion","N":"Necromancy","T":"Transmutation"][code] ?? code }
    static func readRolls(_ node:XMLNode,hero:Hero,spell:Spell? = nil,warnings:inout [String]) -> [NamedRoll] {
        let raw = node.nodes("roll").map { $0.text.trimmingCharacters(in:.whitespacesAndNewlines) }
        return raw.enumerated().compactMap { i,expression in
            let expression = expression.replacingOccurrences(of:"%0",with:"{spell}")
            guard (try? hero.resolveRoll(expression,spell:spell)) != nil else { warnings.append("\(node.value("name")): unsupported roll ‘\(expression)’ retained in the original XML."); return nil }
            let slot = spell != nil && spell!.level > 0 && raw.count == 10-spell!.level ? spell!.level+i:nil
            let tier = spell?.level == 0 && raw.count == 4 ? [1,5,11,17][i]:nil
            return NamedRoll(name:slot != nil ? "Slot \(slot!)" : tier != nil ? "Character level \(tier!)+" : raw.count == 1 ? "Roll":"XML roll \(i+1)",expression:expression,slotLevel:slot,minimumCharacterLevel:tier)
        }
    }
    static func spell(_ node:XMLNode,hero:Hero,ability:Int?,isCharacter:Bool,warnings:inout [String]) -> Spell {
        let level = node.int("level")
        var s = Spell(name:node.value("name"),level:level,school:school(node.value("school")),time:node.value("time"),range:node.value("range"),duration:node.value("duration"),components:node.value("components"),text:node.texts("text"),prepared:!isCharacter || level == 0 || node.int("prepared") == 1)
        if ["yes","true","1"].contains(node.value("concentration").lowercased()) { s.concentration = true }
        s.castingAbility = ability
        let lists = node.value("classes").isEmpty ? node.nodes("sclass").map { $0.text.trimmingCharacters(in:.whitespacesAndNewlines) }.joined(separator:", "):node.value("classes")
        s.classes = lists.isEmpty ? nil:lists
        if s.components.isEmpty { s.components = [node.int("v") == 1 ? "V":nil,node.int("s") == 1 ? "S":nil,node.int("m") == 1 ? "M":nil].compactMap { $0 }.joined(separator:", ") }
        let materials = node.value("materials").isEmpty ? node.value("material"):node.value("materials")
        if !materials.isEmpty && SpellComponents(s.components).material.isEmpty { s.components = SpellComponents(s.components).settingMaterial(materials) }
        s.ritual = node.int("ritual") == 1
        if s.name.localizedCaseInsensitiveContains("free once") { s.usesSlot = false; s.freeUses = 1; s.freeRemaining = 1; warnings.append("\(s.name): imported as one free use per long rest from its explicit name; verify its recharge rule.") }
        s.rolls = readRolls(node,hero:hero,spell:s,warnings:&warnings)
        // XML lists may include both damage and secondary effects. Do not guess which to roll on cast.
        return s
    }
    static func read(_ data:Data) throws -> FightClubImportResult {
        let root = try XMLTree.parse(data)
        var result = FightClubImportResult()
        if root.name == "compendium" {
            for node in root.nodes("spell") { result.spells.append(spell(node,hero:Hero(),ability:nil,isCharacter:false,warnings:&result.warnings)) }
            guard !result.spells.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            return result
        }
        let characters = root.name == "character" ? [root] : root.nodes("character")
        guard !characters.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        var images: [String:Data] = [:]
        for node in root.nodes("imageData") {
            if let image = Data(base64Encoded:node.value("encoded"),options:.ignoreUnknownCharacters), image.count <= 5_000_000 { images[node.value("uid")] = image }
            else { result.warnings.append("An embedded image exceeded the size limit or could not be decoded.") }
        }
        for node in characters {
            var warnings: [String] = []
            var h = Hero(); h.name = node.value("name"); h.sourceXML = data
            let race = node.first("race"); let classes = node.nodes("class"); let background = node.first("background")
            let scopes = [node] + node.nodes("race") + classes + node.nodes("background")
            h.ancestry = race?.value("name") ?? ""; h.background = background?.value("name") ?? ""; h.alignment = background?.value("align") ?? ""
            h.level = classes.reduce(0) { $0 + max(1,$1.int("level",1)) }; if h.level == 0 { h.level = max(1,node.int("level",1)) }
            h.characterClass = classes.map { "\($0.value("name")) \(max(1,$0.int("level",1)))" }.joined(separator:" / ")
            h.scores = numbers(node.value("abilities")); guard h.scores.count == 6 else { throw CocoaError(.fileReadCorruptFile) }
            h.maxHP = node.int("hpMax",1); h.hp = node.int("hpCurrent",h.maxHP); h.tempHP = node.int("hpTemp")
            h.speed = race?.int("speed",30) ?? 30; h.spells = []; h.attacks = []; h.items = []; h.bonuses = []; h.counters = []; h.featureEntries = []; h.features = ""; h.notes = ""
            h.castingAbility = classes.compactMap { Int($0.value("spellAbility")) }.first ?? race?.int("spellAbility",3) ?? 3
            h.portrait = images[node.first("imageData")?.value("uid") ?? ""]
            let allCurrent = scopes + scopes.flatMap { $0.nodes("feat") }
            h.saveProficiencies = []
            for scope in allCurrent {
                for proficiency in scope.nodes("proficiency") {
                    guard let value = Int(proficiency.text.trimmingCharacters(in:.whitespacesAndNewlines)) else { warnings.append("Text proficiency in \(scope.value("name")) requires review."); continue }
                    if (0...5).contains(value) { if !h.saveProficiencies.contains(value) { h.saveProficiencies.append(value) } }
                    else if (100..<118).contains(value) { h.skillRanks[skills[value-100].0] = 1 }
                    else { warnings.append("Unsupported proficiency code \(value) retained in original XML.") }
                }
                for mod in scope.nodes("mod") {
                    let source = mod.value("name").isEmpty ? (scope.value("name").isEmpty ? "Imported modifier":scope.value("name")):mod.value("name")
                    guard let value = Int(mod.value("value")) else { warnings.append("\(source): modifier without a numeric value needs review."); continue }
                    let category = mod.int("category"); let type = mod.int("type",-1)
                    var target: String?
                    if category == 1 && (0...5).contains(type) { target = "score.\(type)" }
                    else if category == 4 && skills.indices.contains(type) { target = "skill.\(skills[type].0)" }
                    else if category == 0 && type == 12 { target = "initiative" }
                    if let target { h.bonuses?.append(Bonus(name:source,target:target,amount:value)) }
                    else { warnings.append("\(source): modifier category \(category), type \(type), value \(value) not applied; preserved in original XML.") }
                }
                if scope.name == "feat" {
                    let parent = scopes.first { $0.children.contains(where:{ $0 === scope }) }
                    let category:FeatureCategory = parent?.name == "race" ? .ancestry : parent?.name == "class" ? .classFeature : parent?.name == "background" ? .background : .feat
                    let feature = CharacterFeature(name:scope.value("name"),text:scope.texts("text"),rolls:readRolls(scope,hero:h,warnings:&warnings),category:category,source:category == .feat ? "Feat":parent?.value("name"))
                    h.featureEntries?.append(feature)
                }
                for tracker in scope.nodes("tracker") {
                    let formula = tracker.value("formula"); let maximum = Int(formula) ?? max(1,tracker.int("value",1))
                    if Int(formula) == nil { warnings.append("\(tracker.value("label")): tracker formula ‘\(formula)’ uses the saved value as a fixed maximum; review after leveling.") }
                    h.counters?.append(ResourceCounter(name:tracker.value("label"),current:min(maximum,max(0,tracker.int("value",maximum))),maximum:max(1,maximum),reset:tracker.int("resetType") == 1 ? .shortRest:tracker.int("resetType") == 2 ? .longRest:.manual))
                }
            }
            h.ac = 10+h.modifier(1)
            let slots = numbers(node.value("slots")); let remaining = numbers(node.value("slotsCurrent"))
            if slots.count >= 10 {
                h.slots = Array(slots[1...9]); h.usedSlots = (1...9).map { max(0,slots[$0] - (remaining.indices.contains($0) ? remaining[$0]:slots[$0])) }
            } else { warnings.append("Character slot array missing or incomplete; slot totals need review.") }
            h.hitDicePools = classes.map { c in
                let name = c.value("name"); let n = max(1,c.int("level",1)); let raw = c.int("hd",-1)
                let conventional = name.lowercased().contains("wizard") || name.lowercased().contains("sorcerer") ? 6 : name.lowercased().contains("barbarian") ? 12 : ["fighter","paladin","ranger"].contains(where:{ name.lowercased().contains($0) }) ? 10:8
                let sides = [1:6,2:8,3:10,4:12,6:6,8:8,10:10,12:12][raw] ?? conventional
                return HitDicePool(name:name,sides:sides,total:n,used:max(0,n-c.int("hdCurrent",n)))
            }
            h.hitDie = h.hitDicePools?.first?.sides ?? 6; h.hitDiceUsed = h.hitDicePools?.reduce(0) { $0 + $1.used } ?? 0
            for scope in scopes {
                let ability = Int(scope.value("spellAbility")) ?? h.castingAbility
                for node in scope.nodes("spell") {
                    var importedSpell = spell(node,hero:h,ability:ability,isCharacter:true,warnings:&warnings)
                    if scope.name == "class" { importedSpell.sourceClassName = scope.value("name"); importedSpell.sourceClassID = h.hitDicePools?.first { $0.name == scope.value("name") }?.id }
                    h.spells.append(importedSpell)
                }
            }
            var itemScopes:[(XMLNode,UUID?,String)] = node.nodes("item").map { ($0,nil,"") }
            h.equipmentContainers = []
            for container in node.nodes("container") {
                let label = container.value("label").isEmpty ? container.value("name"):container.value("label")
                let storage = EquipmentContainer(name:label.isEmpty ? "Container":label)
                h.equipmentContainers!.append(storage)
                itemScopes.append((container,nil,""))
                itemScopes += container.nodes("item").map { ($0,storage.id,storage.name) }
            }
            h.gold = 0
            for (entry,storageID,container) in itemScopes {
                let name = entry.value("name"); if name.isEmpty { continue }
                if entry.int("type") == 15 && name.lowercased().contains("gp") { h.gold += entry.int("quantity",1); continue }
                let detail = entry.value("detail"); let slot = entry.int("slot")
                var item = Item(name:name,quantity:max(0,entry.int("quantity",1)),weight:Double(entry.value("weight")) ?? 0,equipped:slot >= 2,notes:([container.isEmpty ? "":"Container: \(container)",detail,entry.texts("text")].filter { !$0.isEmpty }).joined(separator:"\n\n"))
                item.containerID = storageID
                item.sourceType = entry.value("type"); item.kind = EquipmentKind.characterCode(entry.value("type")) ?? .gear
                item.requiresAttunement = detail.localizedCaseInsensitiveContains("attunement"); item.attuned = entry.int("attuned") == 1
                if item.requiresAttunement == true { warnings.append("\(name): requires attunement; verify equipped and attuned state.") }
                let ac = entry.int("ac"); let type = entry.int("type")
                if type == 4 && ac > 0 { item.bonuses = [Bonus(name:name,target:"ac",amount:ac)] }
                else if (1...3).contains(type), ac > 0 { item.armorBase = ac; item.armorAddsDexterity = type != 3; item.armorDexterityCap = type == 2 ? 2:20 }
                item.rolls = readRolls(entry,hero:h,warnings:&warnings)
                for mod in entry.nodes("mod") { warnings.append("\(name): item modifier ‘\(mod.value("type")) / \(mod.value("value"))’ needs review; armor and shield AC were imported separately.") }
                let damage = entry.value("damage1H")
                if !damage.isEmpty, (try? Dice.roll(damage)) != nil {
                    let ability = name.lowercased().contains("dagger") ? (h.modifier(1) > h.modifier(0) ? 1:0):0
                    h.attacks.append(Attack(name:name,ability:ability,damage:damage,type:[1:"Bludgeoning",2:"Piercing",3:"Slashing"][entry.int("damageType")] ?? "Imported",description:([detail,entry.texts("text")].filter { !$0.isEmpty }).joined(separator:"\n\n"),equipmentID:item.id))
                }
                h.items.append(item)
            }
            h.creatures = node.nodes("monster").map { monster in
                var c = Creature(name:monster.value("label").isEmpty ? monster.value("name"):monster.value("label"),kind:"Summon",type:monster.value("type"),hp:monster.int("hpCurrent",1),maximumHP:max(1,monster.int("hpMax",1)),ac:monster.int("ac",10),speed:monster.int("speed"),scores:numbers(monster.value("abilities")))
                if c.scores.count != 6 { c.scores = Array(repeating:10,count:6); warnings.append("\(c.name): ability array unavailable; default scores need review.") }
                c.image = images[monster.first("imageData")?.value("uid") ?? ""]
                if monster.first("ac") == nil { warnings.append("\(c.name): no AC value in the XML; AC defaults to 10 and needs review.") }
                c.description = ([monster.texts("text")] + (monster.nodes("trait")+monster.nodes("action")).map { "\($0.value("name"))\n\($0.texts("text"))" }).joined(separator:"\n\n")
                c.attacks = monster.nodes("action").flatMap { action in action.nodes("attack").compactMap { attack in (try? Dice.roll(attack.value("damage"))) == nil ? nil:CreatureAttack(name:action.value("name"),bonus:attack.int("attackBonus"),damage:attack.value("damage"),description:action.texts("text")) } }
                c.traits = (monster.nodes("trait")+monster.nodes("action").filter { $0.nodes("attack").isEmpty }).map { CharacterFeature(name:$0.value("name"),text:$0.texts("text"),category:.other,source:c.name) }
                return c
            }
            h.features = (h.featureEntries ?? []).map { "\($0.name)\n\($0.text)" }.joined(separator:"\n\n")
            warnings += ["Missing class levels default to 1; verify the imported multiclass levels and per-class hit dice.","Current proficiency flags and numeric modifiers are preserved; verify starting-class save proficiencies and expertise after leveling.","Only current character features are imported. Future autolevel templates are retained in the original XML but not activated.","Repeated spell rolls are preserved as separate choices, including slot/tier labels when unambiguous. No damage formula is chosen automatically.","Conditional and descriptive rules are retained as text; they do not activate automatically. Equipment slot codes and attunement should be checked."]
            h.importReport = "Fight Club character import\n\n\(h.name) · level \(h.level)\n\(h.spells.count) spells · \(h.items.count) equipment entries · \(h.featureEntries?.count ?? 0) features · \(h.counters?.count ?? 0) counters · \(h.creatures?.count ?? 0) creatures\n\nReview\n" + warnings.map { "• \($0)" }.joined(separator:"\n")
            h.journalEntries = [JournalEntry(title:"Fight Club import review",description:h.importReport!)]
            try validate(Archive(heroes:[h],library:[]))
            result.heroes.append(h); result.warnings += warnings
        }
        return result
    }
}
