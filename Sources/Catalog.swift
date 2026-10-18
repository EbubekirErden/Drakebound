import Foundation

enum EquipmentKind:String,Codable,CaseIterable {
    case gear = "Gear", melee = "Melee weapon", ranged = "Ranged weapon", ammunition = "Ammunition", lightArmor = "Light armor", mediumArmor = "Medium armor", heavyArmor = "Heavy armor", shield = "Shield", wondrous = "Wondrous item", potion = "Potion", ring = "Ring", rod = "Rod", staff = "Staff", wand = "Wand", scroll = "Scroll", valuables = "Valuables", material = "Material", other = "Other"
    static func code(_ code:String) -> EquipmentKind {
        ["G":.gear,"M":.melee,"R":.ranged,"A":.ammunition,"LA":.lightArmor,"MA":.mediumArmor,"HA":.heavyArmor,"S":.shield,"W":.wondrous,"P":.potion,"RG":.ring,"RD":.rod,"ST":.staff,"WD":.wand,"SC":.scroll,"$":.valuables][code] ?? .other
    }
    static func characterCode(_ code:String) -> EquipmentKind? {
        ["1":.lightArmor,"2":.mediumArmor,"3":.heavyArmor,"4":.shield,"5":.melee,"9":.staff,"10":.wand,"14":.wondrous,"15":.valuables][code]
    }
}
extension Item {
    var equipmentKind:EquipmentKind { kind ?? (armorBase == nil ? .gear:armorAddsDexterity == false ? .heavyArmor:armorDexterityCap == 2 ? .mediumArmor:.lightArmor) }
}
enum PreparationFilter:String,CaseIterable { case all = "All", prepared = "Prepared", unprepared = "Unprepared"
    func includes(_ spell:Spell) -> Bool { self == .all || (self == .prepared ? spell.prepared:!spell.prepared) }
}
extension CompendiumEntry {
    var subcategory:String {
        switch category {
        case .spell: return Int(value("level")).map { $0 == 0 ? "Cantrips":"Level \($0)" } ?? "References"
        case .item: return EquipmentKind.code(value("type")).rawValue
        case .monster: return value("type").components(separatedBy:"(")[0].trimmingCharacters(in:.whitespacesAndNewlines).localizedCapitalized
        case .race: return value("size").isEmpty ? "Other":"Size \(value("size"))"
        default: return "All"
        }
    }
    func featureCopies(through level:Int = 20) -> [CharacterFeature] {
        if var feature = template?.feature { feature.id = UUID(); feature.parentFeatureID = nil; feature.resourceCost = nil; feature.rolls = cleanResourceLinks(feature.rolls); return [feature] }
        let category:FeatureCategory = self.category == .classEntry ? .classFeature:self.category == .race ? .ancestry:self.category == .background ? .background:self.category == .feat ? .feat:.other
        if self.category == .classEntry {
            return fields.filter { $0.name == "autolevel" && (Int($0.attributes["level"] ?? "1") ?? 1) <= level }.flatMap { field in
                field.children.filter { $0.name == "feature" }.map { feature in CharacterFeature(name:feature.children.first(where:{ $0.name == "name" })?.text ?? "Class feature",text:feature.children.filter { $0.name != "name" }.map(\.readable).joined(separator:"\n\n"),category:category,source:"\(name) · Level \(field.attributes["level"] ?? "?")") }
            }
        }
        let traits = fields.filter { $0.name == "trait" || $0.name == "feature" }
        if !traits.isEmpty { return traits.map { field in CharacterFeature(name:field.children.first(where:{ $0.name == "name" })?.text ?? name,text:field.children.filter { $0.name != "name" }.map(\.readable).joined(separator:"\n\n"),category:category,source:name) } }
        return [CharacterFeature(name:name,text:text,category:category,source:"Compendium")]
    }
}
extension Hero {
    mutating func migrateReferenceMetadata() {
        guard let sourceXML, let root = try? XMLTree.parse(sourceXML), let character = root.name == "character" ? root:root.nodes("character").first(where:{ $0.value("name") == name }) else { return }
        let sourceItems = character.nodes("item")+character.nodes("container").flatMap { $0.nodes("item") }
        for i in items.indices where items[i].kind == nil {
            let node = sourceItems.first { $0.value("name") == items[i].name }
            items[i].sourceType = node?.value("type"); items[i].kind = node.flatMap { EquipmentKind.characterCode($0.value("type")) } ?? items[i].equipmentKind
        }
        for i in attacks.indices where attacks[i].description == nil { attacks[i].description = items.first { $0.name == attacks[i].name }?.notes ?? "" }
        if creatures != nil {
            for i in creatures!.indices {
                guard let monster = character.nodes("monster").first(where:{ ($0.value("label").isEmpty ? $0.value("name"):$0.value("label")) == creatures![i].name }) else { continue }
                for a in creatures![i].attacks.indices where creatures![i].attacks[a].description == nil {
                    let description = monster.nodes("action").first { $0.value("name") == creatures![i].attacks[a].name }?.texts("text") ?? ""
                    creatures![i].attacks[a].description = description
                }
                if creatures![i].traits == nil { creatures![i].traits = (monster.nodes("trait")+monster.nodes("action").filter { $0.nodes("attack").isEmpty }).map { CharacterFeature(name:$0.value("name"),text:$0.texts("text"),category:.other) } }
            }
        }
    }
}
