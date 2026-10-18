import Foundation

enum OriginBonusMethod:String,CaseIterable {
    case reference = "Ancestry reference"
    case twoOne = "+2 and +1"
    case threeOnes = "+1 to three abilities"
    case custom = "Custom / table rule"
}
extension GuideRules {
    static func backgroundAbilities(_ entry:CompendiumEntry?) -> [Int]? {
        guard let entry else { return nil }
        var texts=entry.fields.filter { ["ability","abilities","abilityscores"].contains($0.name.lowercased()) }.map(\.text)
        texts += entry.fields.compactMap { field in
            guard let title=field.children.first(where:{ $0.name == "name" })?.text,title.lowercased().hasPrefix("ability scores:") else { return nil }
            return String(title.dropFirst("Ability Scores:".count))
        }
        let found=(0..<6).filter { i in texts.contains { $0.range(of:"\\b"+abilities[i]+"\\b",options:[.regularExpression,.caseInsensitive]) != nil } }
        return found.count == 3 ? found:nil
    }
    static func flexibleAncestry(_ entry:CompendiumEntry?) -> Bool {
        guard let entry else { return false }
        return entry.fields.contains { field in
            let title=field.children.first { $0.name == "name" }?.text.lowercased() ?? ""
            guard title.hasPrefix("ability score increase") else { return false }
            let text=field.children.filter { $0.name != "name" }.map(\.readable).joined(separator:" ").lowercased()
            return text.contains("three") && (text.contains("different") || text.contains("one ability"))
        }
    }
    static func fixedAncestryBonuses(_ entry:CompendiumEntry?) -> [Int]? {
        guard let entry,!flexibleAncestry(entry) else { return nil }
        let value=entry.value("ability")
        guard let regex=try? NSRegularExpression(pattern:"(Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma)\\s*\\+([1-4])",options:.caseInsensitive) else { return nil }
        let ns=value as NSString,matches=regex.matches(in:value,range:NSRange(location:0,length:ns.length))
        guard !matches.isEmpty else { return nil }
        // Parse only an unambiguous complete fixed list, never choose between conflicting prose alternatives.
        let residue=regex.stringByReplacingMatches(in:value,range:NSRange(location:0,length:ns.length),withTemplate:"").trimmingCharacters(in:CharacterSet(charactersIn:",; \n\t"))
        guard residue.isEmpty else { return nil }
        var result=Array(repeating:0,count:6)
        for match in matches {
            guard let i=abilities.firstIndex(where:{ $0.caseInsensitiveCompare(ns.substring(with:match.range(at:1))) == .orderedSame }),result[i] == 0,let amount=Int(ns.substring(with:match.range(at:2))) else { return nil }
            result[i]=amount
        }
        return result
    }
}
extension CharacterBuildDraft {
    var originAbilityChoices:[Int] { hero.edition == "2024" ? GuideRules.backgroundAbilities(backgroundTemplate) ?? Array(0..<6):Array(0..<6) }
    var originBonusSource:String { hero.edition == "2024" ? "Background · "+(backgroundTemplate?.name ?? hero.background):"Ancestry · "+(ancestryTemplate?.name ?? hero.ancestry) }
    mutating func resetOriginBonuses() {
        guard !isLevelUp else { return }
        originAdjustments=Array(repeating:0,count:6)
        if hero.edition == "2024" { originBonusMethod = .twoOne }
        else if let fixed=GuideRules.fixedAncestryBonuses(ancestryTemplate) { originBonusMethod = .reference;originAdjustments=fixed }
        else { originBonusMethod = GuideRules.flexibleAncestry(ancestryTemplate) ? .twoOne:.custom }
    }
    mutating func setOriginBonusMethod(_ method:OriginBonusMethod) {
        originBonusMethod=method
        if method == .reference,let fixed=GuideRules.fixedAncestryBonuses(ancestryTemplate) { originAdjustments=fixed }
        else { originAdjustments=Array(repeating:0,count:6) }
    }
    var originBonusProblems:[String] {
        guard !isLevelUp else { return [] }
        if originBonusMethod == .custom { return [] }
        var problems:[String]=[]
        let positive=originAdjustments.filter { $0 > 0 }.sorted()
        if originBonusMethod == .twoOne && (positive != [1,2] || originAdjustments.contains(where:{ $0 < 0 })) { problems.append("Origin ability increases must be +2 to one ability and +1 to a different ability.") }
        if originBonusMethod == .threeOnes && (positive != [1,1,1] || originAdjustments.contains(where:{ $0 < 0 })) { problems.append("Origin ability increases must be +1 to three different abilities.") }
        if hero.edition == "2024" && originBonusMethod == .reference { problems.append("2024 origin ability increases come from the background, not the ancestry.") }
        if hero.edition == "2024" && (0..<6).contains(where:{ originAdjustments[$0] != 0 && !originAbilityChoices.contains($0) }) { problems.append("Choose origin ability increases from your background’s listed abilities.") }
        if (0..<6).contains(where:{ originAdjustments[$0] > 0 && generatedScores[$0]+originAdjustments[$0] > 20 }) { problems.append("Origin ability increases cannot raise an ability score above 20.") }
        return problems
    }
}
