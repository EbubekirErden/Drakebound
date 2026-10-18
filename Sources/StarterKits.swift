import Foundation
struct StarterKit:Identifiable {
    var id:String;var name:String;var source:String;var items:[(String,Int)];var gold=0;var groupID:String?
}
extension GuideCatalog {
    func startingKits(classEntry:CompendiumEntry?,background:CompendiumEntry?,edition:String) -> [StarterKit] {
        var kits:[StarterKit]=[]
        // Explicit 2024 packs are distinct from the 2014 imported references.
        if edition == "2024" {
            kits += [StarterKit(id:"2024-explorer",name:"Explorer’s Pack",source:"2024 equipment",items:[("Backpack",1),("Bedroll",1),("Oil",2),("Rations",10),("Rope",1),("Tinderbox",1),("Torch",10),("Waterskin",1)]),StarterKit(id:"2024-priest",name:"Priest’s Pack",source:"2024 equipment",items:[("Backpack",1),("Blanket",1),("Holy Water",1),("Lamp",1),("Rations",7),("Robe",1),("Tinderbox",1)]),StarterKit(id:"2024-scholar",name:"Scholar’s Pack",source:"2024 equipment",items:[("Backpack",1),("Book",1),("Ink",1),("Ink Pen",1),("Lamp",1),("Oil",10),("Parchment",10),("Tinderbox",1)])]
        }
        for pack in items where pack.value("detail").lowercased().contains("equipment pack") && !kits.contains(where:{ $0.name.replacingOccurrences(of:"’",with:"'") == pack.name }) {
            let text=pack.fields.filter { $0.name == "text" }.map(\.text).joined(separator:"\n")
            let lines=text.components(separatedBy:.newlines).filter { $0.contains("•") }
            var parts:[(String,Int)]=[]
            for line in lines {
                var name=line.components(separatedBy:"•").last!.trimmingCharacters(in:.whitespaces)
                name=name.replacingOccurrences(of:"^(?:a|an) ",with:"",options:.regularExpression)
                let words=name.split(separator:" ",maxSplits:1)
                let quantity=words.first.flatMap { Int($0) } ?? 1
                if words.count == 2 && Int(words[0]) != nil { name=String(words[1]) }
                name=name.replacingOccurrences(of:"days of rations",with:"Rations").replacingOccurrences(of:"blocks of incense",with:"Incense")
                if !name.isEmpty { parts.append((name,quantity)) }
            }
            if !parts.isEmpty { kits.append(StarterKit(id:pack.id.uuidString,name:pack.name,source:pack.sourceDescription,items:parts)) }
        }
        for entry in [classEntry,background].compactMap({ $0 }) {
            let features=entry.category == .classEntry ? GuideRules.classChoices(entry,from:1,through:1).map(\.feature):GuideRules.originFeatures(entry)
            for feature in features {
                var text=feature.text
                if let range=text.range(of:"Starting Equipment:",options:.caseInsensitive) { text=String(text[range.upperBound...]).components(separatedBy:"\n\n").first ?? "" }
                else if feature.name.localizedCaseInsensitiveContains("Starting Equipment") {} else { continue }
                guard let a=text.range(of:"(A)"),let b=text.range(of:"(B)"),a.lowerBound < b.lowerBound else { continue }
                let options=[("A",String(text[a.upperBound..<b.lowerBound])),("B",String(text[b.upperBound...]).components(separatedBy:"\n\n").first ?? "")]
                for (letter,raw) in options {
                    var contents:[(String,Int)]=[],gold=0
                    let cleaned=raw.replacingOccurrences(of:"; or",with:"").replacingOccurrences(of:";",with:"").trimmingCharacters(in:.whitespacesAndNewlines)
                    for piece in cleaned.components(separatedBy:",") {
                        let part=piece.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"^and ",with:"",options:.regularExpression)
                        if let match=part.range(of:"^[0-9]+ GP\\.?$",options:[.regularExpression,.caseInsensitive]) { gold += Int(part[match].filter(\.isNumber)) ?? 0 }
                        else if !part.isEmpty {
                            let words=part.split(separator:" ",maxSplits:1)
                            if words.count == 2,let amount=Int(words[0]) { contents.append((String(words[1]),amount)) } else { contents.append((part,1)) }
                        }
                    }
                    if !contents.isEmpty || gold > 0 { kits.append(StarterKit(id:entry.id.uuidString+letter,name:entry.name+" · Option "+letter,source:feature.name,items:contents,gold:gold,groupID:entry.id.uuidString)) }
                }
            }
        }
        return kits
    }
    func kitItem(_ name:String,quantity:Int,edition:String) -> Item {
        func normalize(_ value:String) -> String { value.replacingOccurrences(of:" [2024]",with:"").replacingOccurrences(of:"’",with:"'").lowercased() }
        let candidates=items.filter { normalize($0.name) == normalize(name) }
        let entry=candidates.first { edition == "2024" ? $0.sourceMark == .revised:$0.sourceMark != .revised } ?? candidates.first
        var item=entry?.item() ?? Item(name:name)
        if let entry,let ac=Int(entry.value("ac")) {
            let type=entry.value("type")
            if type == "S" { item.bonuses=[Bonus(name:item.name,target:"ac",amount:ac)] }
            else if ["LA","MA","HA"].contains(type) { item.armorBase=ac;item.armorAddsDexterity=type != "HA";item.armorDexterityCap=type == "MA" ? 2:nil }
        }
        item.quantity=quantity
        return item
    }
}
extension CharacterBuildDraft {
    mutating func applyStarterKit(_ kit:StarterKit,catalog:GuideCatalog) {
        guard !appliedStarterKits.contains(kit.id),kit.groupID.map({ group in !appliedStarterKits.contains("group:"+group) }) ?? true else { return }
        let container:EquipmentContainer?=kit.items.isEmpty ? nil:EquipmentContainer(name:kit.name)
        if let container { hero.equipmentContainers=(hero.equipmentContainers ?? [])+[container] }
        for (name,quantity) in kit.items {
            if let pack=catalog.startingKits(classEntry:nil,background:nil,edition:hero.edition).first(where:{ $0.name.replacingOccurrences(of:"’",with:"'") == name.replacingOccurrences(of:"’",with:"'") }) {
                for (part,count) in pack.items { var item=catalog.kitItem(part,quantity:count*quantity,edition:hero.edition);item.containerID=container?.id;hero.items.append(item) }
            } else { var item=catalog.kitItem(name,quantity:quantity,edition:hero.edition);item.containerID=container?.id;hero.items.append(item) }
        }
        hero.gold += kit.gold;appliedStarterKits.insert(kit.id);if let group=kit.groupID { appliedStarterKits.insert("group:"+group) }
    }
}
