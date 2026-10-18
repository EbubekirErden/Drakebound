import Foundation
import CryptoKit

enum CompendiumCategory:String,Codable,CaseIterable {
    case spell = "Spells", item = "Equipment", monster = "Creatures", feat = "Feats", race = "Races", classEntry = "Classes", background = "Backgrounds"
    var tag:String { switch self { case .classEntry: return "class"; default: return ["Spells":"spell","Equipment":"item","Creatures":"monster","Feats":"feat","Races":"race","Backgrounds":"background"][rawValue]! } }
}
struct ReferenceField:Codable,Equatable {
    var name:String
    var text:String
    var attributes:[String:String]
    var children:[ReferenceField]
    init(_ node:XMLNode) { name = node.name; text = node.text.trimmingCharacters(in:.whitespacesAndNewlines); attributes = node.attributes; children = node.children.map(ReferenceField.init) }
    var readable:String {
        let heading = children.first(where:{ $0.name == "name" })?.text ?? (name == "autolevel" ? "Level \(attributes["level"] ?? "?")":"")
        let nested = children.filter { $0.name != "name" }.map(\.readable).filter { !$0.isEmpty }.joined(separator:"\n\n")
        if children.isEmpty { return text.isEmpty ? "":name == "text" || name == "description" ? text:"\(name): \(text)" }
        return [heading,text,nested].filter { !$0.isEmpty }.joined(separator:"\n\n")
    }
    var node:XMLNode { let n = XMLNode(name); n.text = text; n.attributes = attributes; n.children = children.map(\.node); return n }
}
struct CompendiumEntry:Codable,Identifiable,Equatable {
    var id = UUID()
    var category:CompendiumCategory
    var name:String
    var fields:[ReferenceField]
    var custom:Bool?
    var template:CompendiumTemplate?
    var identityKey:String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var data = (try? encoder.encode(fields)) ?? Data(id.uuidString.utf8)
        if let template { data.append((try? encoder.encode(template)) ?? Data()) }
        return category.tag+"|"+SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
    }
    func value(_ key:String) -> String { fields.first { $0.name == key }?.text ?? "" }
    var text:String { fields.filter { $0.name != "name" }.map(\.readable).filter { !$0.isEmpty }.joined(separator:"\n\n") }
    var summary:String {
        switch category {
        case .spell: return [Int(value("level")).map { $0 == 0 ? "Cantrip":"Level \($0)" } ?? "Reference",FightClubImport.school(value("school")),value("classes")].filter { !$0.isEmpty }.joined(separator:" · ")
        case .item: return [EquipmentKind.code(value("type")).rawValue,value("detail")].filter { !$0.isEmpty }.joined(separator:" · ")
        case .monster: return [value("type"),value("cr").isEmpty ? "":"CR \(value("cr"))"].filter { !$0.isEmpty }.joined(separator:" · ")
        case .feat: return value("prerequisite")
        case .race: return value("ability")
        case .classEntry: return "d\(value("hd")) hit die"
        case .background: return value("proficiency")
        }
    }
    var node:XMLNode { let n = XMLNode(category.tag); n.children = fields.map(\.node); return n }
    func spell() -> Spell? {
        if var spell = template?.spell { spell.id = id; spell.resourceCost = nil; spell.rolls = cleanResourceLinks(spell.rolls); return spell }
        guard category == .spell, let level = Int(value("level")), (0...9).contains(level) else { return nil }
        var warnings:[String] = []; var s = FightClubImport.spell(node,hero:Hero(),ability:nil,isCharacter:false,warnings:&warnings); s.id = id; return s
    }
    func item() -> Item {
        if var item = template?.item { item.id = UUID(); item.quantity = 1; item.equipped = false; item.attuned = false; item.containerID = nil; item.rolls = cleanResourceLinks(item.rolls); return item }
        var item = Item(name:name,weight:Double(value("weight")) ?? 0,notes:fields.filter { !["name","type","weight"].contains($0.name) }.map(\.readable).filter { !$0.isEmpty }.joined(separator:"\n\n"))
        item.kind = EquipmentKind.code(value("type")); item.sourceType = value("type")
        item.weight = max(0,min(100000,item.weight.isFinite ? item.weight:0))
        var warnings:[String] = []; item.rolls = FightClubImport.readRolls(node,hero:Hero(),warnings:&warnings)
        return item
    }
    func creature() -> Creature {
        if var creature = template?.creature { creature.id = UUID(); creature.hp = creature.maximumHP; return creature }
        func firstNumber(_ text:String,_ fallback:Int) -> Int {
            let digits = text.drop(while:{ !$0.isNumber }).prefix(while:\.isNumber); return Int(digits) ?? fallback
        }
        let hp = max(1,min(99999,firstNumber(value("hp"),1)))
        var c = Creature(name:name,kind:"Reference",type:[value("size"),value("type"),value("cr").isEmpty ? "":"CR \(value("cr"))"].filter { !$0.isEmpty }.joined(separator:" · "),hp:hp,maximumHP:hp,ac:max(0,min(50,firstNumber(value("ac"),10))),speed:max(0,min(999,firstNumber(value("speed"),0))),scores:["str","dex","con","int","wis","cha"].map { max(1,min(30,Int(value($0)) ?? 10)) },description:text)
        c.attacks = node.children.filter { ["action","trait","legendary","reaction"].contains($0.name) }.flatMap { action in action.nodes("attack").compactMap { attack in
            let parts = attack.text.split(separator:"|",omittingEmptySubsequences:false).map(String.init)
            guard parts.count >= 3, let bonus = Int(parts[1]), (-100...100).contains(bonus), (try? Dice.roll(parts[2])) != nil else { return nil }
            return CreatureAttack(name:parts[0].isEmpty ? action.value("name"):parts[0],bonus:bonus,damage:parts[2],description:action.texts("text"),timing:action.name == "reaction" ? .reaction:action.name == "legendary" ? .legendaryAction:action.name == "trait" ? .other:.action)
        } }
        c.traits = node.children.filter { ["trait","action","legendary","reaction"].contains($0.name) && $0.nodes("attack").isEmpty }.map { CharacterFeature(name:$0.value("name"),text:$0.texts("text"),category:.other,source:name,timing:$0.name == "reaction" ? .reaction:$0.name == "legendary" ? .legendaryAction:$0.name == "action" ? .action:nil) }
        return c
    }
}
struct CompendiumImportResult { var entries:[CompendiumEntry]; var repairedAmpersands:Int }
enum CompendiumImport {
    static func read(_ data:Data) throws -> CompendiumImportResult {
        guard data.count <= 100_000_000, let string = String(data:data,encoding:.utf8) else { throw CocoaError(.fileReadTooLarge) }
        let regex = try NSRegularExpression(pattern:"&(?!amp;|lt;|gt;|quot;|apos;|#[0-9]+;|#x[0-9a-fA-F]+;)")
        let range = NSRange(string.startIndex...,in:string)
        let repairs = regex.numberOfMatches(in:string,range:range)
        let sanitized = regex.stringByReplacingMatches(in:string,range:range,withTemplate:"&amp;")
        let root = try XMLTree.parse(Data(sanitized.utf8),limit:110_000_000)
        guard root.name == "compendium" else { throw CocoaError(.fileReadCorruptFile) }
        let entries = root.children.compactMap { node -> CompendiumEntry? in
            guard let category = CompendiumCategory.allCases.first(where:{ $0.tag == node.name }), !node.value("name").isEmpty else { return nil }
            return CompendiumEntry(category:category,name:node.value("name"),fields:node.children.map(ReferenceField.init))
        }
        guard !entries.isEmpty, entries.count <= 100000 else { throw CocoaError(.fileReadCorruptFile) }
        return CompendiumImportResult(entries:entries,repairedAmpersands:repairs)
    }
    static func merged(_ existing:[CompendiumEntry],_ incoming:[CompendiumEntry]) -> [CompendiumEntry] {
        var result = existing; var keys = Set(existing.map(\.identityKey))
        for entry in incoming where keys.insert(entry.identityKey).inserted { result.append(entry) }
        return result
    }
}
