import Foundation

struct TrainingGrant:Codable,Identifiable,Equatable {
    var id = UUID()
    var target:String
    var rank = 1
    var source:String
}
extension Hero {
    var allTraining:[TrainingGrant] { (trainingGrants ?? []) + (featureEntries ?? []).flatMap { feature in (feature.training ?? []).map { var grant = $0; grant.source = feature.name; return grant } } }
    func effectiveSkillRank(_ name:String) -> Int { max(skillRanks[name] ?? 0,allTraining.filter { $0.target == "skill."+name }.map(\.rank).max() ?? 0) }
    func isSaveProficient(_ index:Int) -> Bool { saveProficiencies.contains(index) || allTraining.contains { $0.target == "save.\(index)" && $0.rank > 0 } }
    func trainingSources(_ target:String) -> [String] {
        var sources = allTraining.filter { $0.target == target }.map(\.source)
        if target.hasPrefix("skill."),(skillRanks[String(target.dropFirst(6))] ?? 0) > 0 { sources.insert("Existing / manual training",at:0) }
        if target.hasPrefix("save."),let i = Int(target.dropFirst(5)),saveProficiencies.contains(i) { sources.insert("Starting / manual training",at:0) }
        return Array(Set(sources)).sorted()
    }
    func linkedEquipment(_ attack:Attack) -> Item? {
        guard attack.isSpell != true else { return nil }
        if let id = attack.equipmentID { return items.first { $0.id == id } }
        let matching = items.filter { $0.name.caseInsensitiveCompare(attack.name) == .orderedSame }
        return matching.count == 1 ? matching[0]:nil
    }
    func attackUnavailableReason(_ attack:Attack) -> String? {
        if let item = linkedEquipment(attack) { return !item.equipped || item.quantity == 0 ? "Unequipped":nil }
        return attack.equipmentID != nil ? "Item missing":nil
    }
}
struct GuideSubclass:Identifiable,Equatable {
    var name:String
    var level:Int
    var feature:CharacterFeature
    var id:String { name }
}
struct GuideClassChoice:Identifiable {
    var feature:CharacterFeature
    var optional:Bool
    var subclass:String?
    var level:Int
    var id:UUID { feature.id }
}
extension GuideRules {
    static func featMinimumLevel(_ entry:CompendiumEntry) -> Int {
        let text = entry.value("prerequisite")
        guard let match = text.range(of:"(?i)level\\s*(\\d+)|\\b\\d+(?:st|nd|rd|th)[- ]level",options:.regularExpression) else { return entry.name.localizedCaseInsensitiveContains("Ability Score Improvement") ? 4:1 }
        return Int(text[match].filter(\.isNumber)) ?? 1
    }
    static func isASI(_ entry:CompendiumEntry?,className:String,level:Int,edition:String = "2014") -> Bool {
        if let entry {
            let nodes = entry.fields.filter { $0.name == "autolevel" && Int($0.attributes["level"] ?? "0") == level }
            return nodes.contains { field in field.attributes["scoreImprovement"]?.uppercased() == "YES" || field.children.contains { child in child.name == "feature" && child.children.contains { $0.name == "name" && $0.text.localizedCaseInsensitiveContains("Ability Score Improvement") } } }
        }
        guard let profile = ClassProfile.named(className) else { return false }
        return ([4,8,12,16].contains(level) || (level == 19 && edition != "2024" && !className.contains("2024"))) || (profile.name == "Fighter" && [6,14].contains(level)) || (profile.name == "Rogue" && level == 10)
    }
    static func subclassHeading(_ name:String) -> String? {
        let clean = name.replacingOccurrences(of:"^Level \\d+:\\s*",with:"",options:.regularExpression)
        guard let split = clean.firstIndex(of:":") else { return nil }
        let prefix = String(clean[..<split]).lowercased()
        let prefixes = ["subclass","arcane tradition","martial archetype","roguish archetype","artificer specialist","divine domain","druid circle","otherworldly patron","sacred oath","sorcerous origin","bard college","primal path","monastic tradition","ranger archetype"]
        guard prefixes.contains(where:{ prefix.contains($0) }) else { return nil }
        let title = clean[clean.index(after:split)...].trimmingCharacters(in:.whitespacesAndNewlines)
        return title.isEmpty ? nil:title
    }
    static func subclasses(_ entry:CompendiumEntry) -> [GuideSubclass] {
        var seen = Set<String>()
        return classChoices(entry,from:1,through:20).compactMap { choice in
            guard let name = subclassHeading(choice.feature.name),seen.insert(name).inserted else { return nil }
            return GuideSubclass(name:name,level:choice.level,feature:choice.feature)
        }
    }
    static func classChoices(_ entry:CompendiumEntry,from:Int,through:Int) -> [GuideClassChoice] {
        var choices:[GuideClassChoice] = []
        for (index,field) in entry.fields.enumerated() where field.name == "autolevel" {
            let level = Int(field.attributes["level"] ?? "1") ?? 1
            guard (from...max(from,through)).contains(level),level <= through else { continue }
            var group:String?
            for (childIndex,node) in field.children.enumerated() where node.name == "feature" {
                let name = node.children.first { $0.name == "name" }?.text ?? "Class feature"
                let optional = node.attributes["optional"]?.uppercased() == "YES"
                if let heading = subclassHeading(name) { group = heading }
                else if !optional { group = nil }
                let explicit = node.attributes["subclass"]
                let suffix = name.range(of:"\\((.+)\\)\\s*$",options:.regularExpression).map { String(name[$0]).trimmingCharacters(in:CharacterSet(charactersIn:"() ")) }
                let feature = CharacterFeature(id:guideID(entry.id.uuidString+"-\(index)-\(childIndex)"),name:name,text:node.children.filter { $0.name != "name" }.map(\.readable).joined(separator:"\n\n"),category:.classFeature,source:"\(entry.name) · Level \(level)")
                choices.append(GuideClassChoice(feature:feature,optional:optional,subclass:explicit ?? (subclassHeading(name) != nil ? group:optional ? (suffix ?? group):nil),level:level))
            }
        }
        return choices
    }
    static func belongs(_ choice:GuideClassChoice,to subclass:String) -> Bool {
        guard !subclass.isEmpty,let group = choice.subclass else { return false }
        func words(_ value:String) -> Set<String> { Set(value.lowercased().components(separatedBy:CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty && !["school","of","the","magic","wizard","hb","ua"].contains($0) }) }
        return group.caseInsensitiveCompare(subclass) == .orderedSame || (!words(group).isEmpty && words(group).isSubset(of:words(subclass))) || (!words(subclass).isEmpty && words(subclass).isSubset(of:words(group)))
    }
    static func originFeatures(_ entry:CompendiumEntry) -> [CharacterFeature] {
        featureChoices(entry,from:1,through:20).filter { !isOriginMetadata($0.name) }
    }
    static func isOriginMetadata(_ name:String) -> Bool { ["size","creature type","speed","age","alignment","ability score increase","ability score increases"].contains(name.lowercased()) }
    static func originFacts(_ entry:CompendiumEntry) -> [ReferenceField] {
        var fields = entry.fields.filter { $0.children.isEmpty && !["name","text","description"].contains($0.name) && !$0.text.isEmpty }
        for trait in entry.fields where !trait.children.isEmpty {
            let name = trait.children.first { $0.name == "name" }?.text ?? ""
            guard isOriginMetadata(name) else { continue }
            let key = ["creature type":"type","ability score increase":"ability","ability score increases":"ability"][name.lowercased()] ?? name.lowercased()
            fields.removeAll { $0.name == key }
            fields.append(ReferenceField(name:key,text:trait.children.filter { $0.name != "name" }.map(\.readable).joined(separator:"\n")))
        }
        return fields
    }
    static func training(_ entry:CompendiumEntry) -> [TrainingGrant] {
        let values = entry.value("proficiency").components(separatedBy:",").map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }
        return skills.map(\.0).filter(values.contains).map { TrainingGrant(id:guideID(entry.id.uuidString+"-skill-"+$0),target:"skill."+$0,source:entry.name) }
    }
}
extension ReferenceField {
    init(name:String,text:String = "",attributes:[String:String] = [:],children:[ReferenceField] = []) { self.name = name; self.text = text; self.attributes = attributes; self.children = children }
}
