import Foundation
extension CompendiumCategory {
    var singular:String { switch self { case .spell:return "Spell"; case .item:return "Item"; case .monster:return "Creature"; case .feat:return "Feature"; case .race:return "Ancestry"; case .classEntry:return "Class"; case .background:return "Background" } }
}

struct CompendiumTemplate:Codable,Equatable {
    var spell:Spell?
    var item:Item?
    var creature:Creature?
    var feature:CharacterFeature?
}
enum TemplateFactory {
    static func spell(_ input:Spell) -> CompendiumEntry {
        var spell = input
        spell.sourceClassID = nil; spell.sourceClassName = nil; spell.prepared = false; spell.freeRemaining = spell.freeUses
        spell.resourceCost = nil; spell.rolls = cleanResourceLinks(spell.rolls)
        let fields = [ReferenceField(name:"name",text:spell.name),ReferenceField(name:"level",text:String(spell.level)),ReferenceField(name:"school",text:spell.school),ReferenceField(name:"classes",text:spell.classes ?? ""),ReferenceField(name:"text",text:spell.text)]
        return CompendiumEntry(category:.spell,name:spell.name,fields:fields,custom:true,template:CompendiumTemplate(spell:spell))
    }
    static func item(_ input:Item) -> CompendiumEntry {
        var item = input; item.quantity = 1; item.equipped = false; item.attuned = false; item.containerID = nil
        item.rolls = cleanResourceLinks(item.rolls)
        let type = [EquipmentKind.gear:"G",.melee:"M",.ranged:"R",.lightArmor:"LA",.mediumArmor:"MA",.heavyArmor:"HA",.shield:"S",.wondrous:"W",.potion:"P",.staff:"ST",.wand:"WD",.valuables:"$",.ring:"RG",.ammunition:"A",.rod:"RD",.scroll:"SC"][item.equipmentKind] ?? "G"
        return CompendiumEntry(category:.item,name:item.name,fields:[ReferenceField(name:"name",text:item.name),ReferenceField(name:"type",text:type),ReferenceField(name:"weight",text:String(item.weight)),ReferenceField(name:"text",text:item.notes)],custom:true,template:CompendiumTemplate(item:item))
    }
    static func creature(_ input:Creature) -> CompendiumEntry {
        var c = input; c.hp = c.maximumHP; c.active = nil
        var fields = [ReferenceField(name:"name",text:c.name),ReferenceField(name:"type",text:c.type),ReferenceField(name:"ac",text:String(c.ac)),ReferenceField(name:"hp",text:String(c.maximumHP)),ReferenceField(name:"speed",text:String(c.speed)),ReferenceField(name:"text",text:c.description)]
        fields += zip(["str","dex","con","int","wis","cha"],c.scores).map { ReferenceField(name:$0,text:String($1)) }
        return CompendiumEntry(category:.monster,name:c.name,fields:fields,custom:true,template:CompendiumTemplate(creature:c))
    }
    static func feature(_ input:CharacterFeature) -> CompendiumEntry {
        var f = input; f.parentFeatureID = nil; if let maximum = f.counter?.maximum { f.counter?.current = maximum }
        f.resourceCost = nil; f.rolls = cleanResourceLinks(f.rolls)
        return CompendiumEntry(category:.feat,name:f.name,fields:[ReferenceField(name:"name",text:f.name),ReferenceField(name:"text",text:f.text)],custom:true,template:CompendiumTemplate(feature:f))
    }
}
func cleanResourceLinks(_ rolls:[NamedRoll]?) -> [NamedRoll]? { rolls?.map { var r = $0; r.resourceCost = nil; return r } }
struct TemplateTrait:Identifiable {
    var id = UUID()
    var name = ""
    var text = ""
    var level = 1
    var subclass = ""
    var optional = false
}
struct ReferenceTemplateDraft {
    var category:CompendiumCategory
    var name = ""
    var values:[String:String]
    var traits:[TemplateTrait] = [TemplateTrait()]
    init(category:CompendiumCategory) {
        self.category = category
        values = category == .race ? ["size":"M","type":"Humanoid","speed":"30"]:category == .classEntry ? ["hd":"8","numSkills":"2","proficiency":"","spellAbility":"Intelligence"]:[:]
    }
    var issues:[String] {
        var result:[String] = []
        if name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { result.append("Enter a name.") }
        if traits.isEmpty || traits.contains(where:{ $0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || $0.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }) { result.append("Add at least one feature with a title and description.") }
        if category == .race {
            if !["T","S","M","L","H","G"].contains(values["size"] ?? "") { result.append("Choose a size.") }
            if values["type",default:""].trimmingCharacters(in:.whitespaces).isEmpty { result.append("Enter a creature type.") }
            if !(0...300).contains(Int(values["speed"] ?? "") ?? -1) { result.append("Enter a speed from 0 to 300 feet.") }
        }
        if category == .background && values["proficiency",default:""].isEmpty { result.append("Choose the background’s skill training.") }
        if category == .classEntry && ![6,8,10,12].contains(Int(values["hd"] ?? "") ?? 0) { result.append("Choose a hit die.") }
        return result
    }
    var entry:CompendiumEntry {
        var fields = [ReferenceField(name:"name",text:name)] + values.keys.sorted().filter { !values[$0,default:""].isEmpty }.map { ReferenceField(name:$0,text:values[$0]!) }
        for trait in traits {
            let children = [ReferenceField(name:"name",text:trait.name),ReferenceField(name:"text",text:trait.text)]
            if category == .classEntry {
                var attributes:[String:String] = [:]
                if trait.optional { attributes["optional"] = "YES" }; if !trait.subclass.isEmpty { attributes["subclass"] = trait.subclass }
                fields.append(ReferenceField(name:"autolevel",attributes:["level":String(trait.level)],children:[ReferenceField(name:"feature",attributes:attributes,children:children)]))
            } else { fields.append(ReferenceField(name:"trait",children:children)) }
        }
        return CompendiumEntry(category:category,name:name,fields:fields,custom:true)
    }
}
