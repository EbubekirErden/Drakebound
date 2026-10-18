import Foundation

struct AbilityImprovementChoice:Equatable {
    var increases=[0,0,0,0,0,0]
    var feat:CharacterFeature?
}
extension CharacterBuildDraft {
    static func isAbilityImprovement(_ feature:CharacterFeature) -> Bool { feature.category == .classFeature && feature.name.localizedCaseInsensitiveContains("Ability Score Improvement") }
    var improvementFeatures:[CharacterFeature] { selectedFeatures.filter(Self.isAbilityImprovement) }
    var improvementTotals:[Int] { (0..<6).map { i in improvementFeatures.reduce(0) { $0+(abilityImprovements[$1.id]?.increases[i] ?? 0) } } }
    func improvementProblem(_ choice:AbilityImprovementChoice,for id:UUID) -> String? {
        guard choice.increases.count == 6,choice.increases.allSatisfy({ (0...2).contains($0) }) else { return "Choose valid ability increases." }
        let total=choice.increases.reduce(0,+)
        if choice.feat == nil && total != 2 { return "Assign two ability points: +2 to one score or +1 to two scores." }
        if choice.feat != nil && total > 1 { return "Record only the one ability point explicitly granted by this feat, or leave all increases at zero." }
        let base=isLevelUp ? original!.scores:zip(generatedScores,originAdjustments).map(+)
        for i in 0..<6 where choice.increases[i] > 0 {
            let other=improvementFeatures.filter { $0.id != id }.reduce(0) { $0+(abilityImprovements[$1.id]?.increases[i] ?? 0) }
            if base[i]+other+choice.increases[i] > 20 { return "This ability increase cannot raise a score above 20." }
        }
        return nil
    }
    mutating func configureImprovement(_ feature:CharacterFeature,choice:AbilityImprovementChoice) throws {
        if let problem=improvementProblem(choice,for:feature.id) { throw GuideError.invalid(problem) }
        abilityImprovements[feature.id]=choice
    }
    func improvementSummary(_ feature:CharacterFeature) -> String {
        guard let choice=abilityImprovements[feature.id] else { return "Choose ability increases or a feat" }
        let points=(0..<6).filter { choice.increases[$0] > 0 }.map { String(abilities[$0].prefix(3))+" "+signed(choice.increases[$0]) }.joined(separator:" · ")
        return [choice.feat?.name,points.isEmpty ? nil:points].compactMap { $0 }.joined(separator:" · ")
    }
    var improvementProblems:[String] {
        improvementFeatures.compactMap { feature in
            guard let choice=abilityImprovements[feature.id] else { return "Configure the ability improvement choice for \(feature.source ?? feature.name)." }
            return improvementProblem(choice,for:feature.id)
        }
    }
}

struct ClassSpellAllowance {
    var cantrips:Int?
    var prepared:Int?
    var known:Int?
    var knownLabel="Known"
    var maximumLevel:Int?
}
extension GuideRules {
    static func spellAllowance(_ record:CharacterClassLevel,entry:CompendiumEntry?,hero:Hero) -> ClassSpellAllowance {
        let name=ClassProfile.named(record.name)?.name ?? record.name,l=record.level
        var result=ClassSpellAllowance(cantrips:entry.flatMap { importedCantrips($0,at:l) })
        if let slots=entry.flatMap({ importedSlots($0,at:l) }),let i=slots.lastIndex(where:{ $0 > 0 }) { result.maximumLevel=i+1 }
        else if record.casting == .full { result.maximumLevel=min(9,(l+1)/2) }
        else if record.casting == .pact { result.maximumLevel=min(5,(l+1)/2) }
        else if record.casting == .half || record.casting == .halfUp { result.maximumLevel=min(5,(l+3)/4) }
        func importedCount(_ labels:[String]) -> Int? {
            guard let entry else { return nil }
            for feature in featureChoices(entry,from:1,through:l) where feature.name.localizedCaseInsensitiveContains("Spellcasting") || feature.name.localizedCaseInsensitiveContains("Pact Magic") {
                for label in labels {
                    guard let range=feature.text.range(of:label,options:.caseInsensitive) else { continue }
                    let table=String(feature.text[range.upperBound...]);var rows:[Int:Int]=[:]
                    for line in table.components(separatedBy:.newlines) {
                        let parts=line.split(separator:"|").map { $0.trimmingCharacters(in:.whitespaces) }
                        if parts.count == 2,let level=Int(parts[0]),let count=Int(parts[1]),(1...20).contains(level),(0...100).contains(count) { rows[level]=count }
                    }
                    if rows.count >= 3,let value=rows[l] { return value }
                }
            };return nil
        }
        result.prepared=importedCount(["Spells Prepared:","Prepared Spells:"])
        result.known=importedCount(["Spells Known:","Known Spells:"])
        if hero.edition == "2024" && name == "Cleric" && result.prepared == nil { result.prepared=[4,5,6,7,9,10,11,12,14,15,16,16,17,17,18,18,19,20,21,22][min(19,max(0,l-1))] }
        if hero.edition == "2014" {
            if ["Cleric","Druid","Wizard"].contains(name) { let ability=name == "Wizard" ? 3:4;result.prepared=max(1,l+hero.modifier(ability)) }
            if name == "Paladin" && l >= 2 { result.prepared=max(1,l/2+hero.modifier(5)) }
            if name == "Artificer" { result.prepared=max(1,l/2+hero.modifier(3)) }
        }
        if name == "Wizard" { result.known=6+max(0,l-1)*2;result.knownLabel="Spellbook minimum" }
        if result.cantrips == nil && ["Cleric","Druid","Wizard","Sorcerer","Bard","Warlock"].contains(name) {
            let start=["Cleric":3,"Druid":2,"Wizard":3,"Sorcerer":4,"Bard":2,"Warlock":2][name]!
            result.cantrips=start+(l>=4 ? 1:0)+(l>=10 ? 1:0)
        }
        return result
    }
    // Only recognized complete spell records are recovered. Missing-level invocations and other features stay in review.
    static func recognizedCantrip(_ entry:CompendiumEntry) -> Bool {
        guard entry.category == .spell,entry.value("level").isEmpty,!entry.value("school").isEmpty,!entry.value("time").isEmpty,!entry.value("range").isEmpty else { return false }
        let name=entry.name.replacingOccurrences(of:" [2024]",with:"").lowercased()
        let known=Set(["acid splash","blade ward","chill touch","dancing lights","druidcraft","eldritch blast","elementalism","fire bolt","friends","guidance","light","mage hand","mending","message","minor illusion","poison spray","prestidigitation","produce flame","ray of frost","resistance","sacred flame","shillelagh","shocking grasp","spare the dying","starry wisp","thaumaturgy","thorn whip","true strike","toll the dead","word of radiance"])
        return known.contains(name) || entry.text.contains("Cantrip Upgrade:")
    }
    static func spellNameKey(_ name:String) -> String { name.replacingOccurrences(of:" [2024]",with:"").lowercased() }
    static func spellBelongs(_ spell:Spell,to className:String) -> Bool {
        let base=ClassProfile.named(className)?.name ?? className
        return (spell.classes ?? "").components(separatedBy:",").contains { token in
            token.replacingOccurrences(of:" [2024]",with:"").trimmingCharacters(in:.whitespacesAndNewlines).caseInsensitiveCompare(base) == .orderedSame
        }
    }
}

struct FeatureOutlineRow:Identifiable {
    var feature:CharacterFeature
    var depth:Int
    var id:UUID { feature.id }
}
enum SelectionRules {
    static func parentOptions(for feature:CharacterFeature,in features:[CharacterFeature]) -> [CharacterFeature] {
        features.filter { candidate in
            guard candidate.id != feature.id else { return false }
            var visited=Set<UUID>(),current:CharacterFeature?=candidate
            while let node=current {
                if node.id == feature.id || !visited.insert(node.id).inserted { return false }
                current=features.first { $0.id == node.parentFeatureID }
            }
            return true
        }
    }
    static func outline(_ features:[CharacterFeature]) -> [FeatureOutlineRow] {
        var result:[FeatureOutlineRow]=[],seen=Set<UUID>()
        func append(_ feature:CharacterFeature,_ depth:Int) {
            guard seen.insert(feature.id).inserted else { return }
            result.append(FeatureOutlineRow(feature:feature,depth:depth))
            for child in features where child.parentFeatureID == feature.id { append(child,depth+1) }
        }
        for feature in features where !features.contains(where:{ $0.id == feature.parentFeatureID }) { append(feature,0) }
        for feature in features where !seen.contains(feature.id) { append(feature,0) }
        return result
    }
    // The browser is a view of the library: saved custom entries and character copies stay untouched.
    static func browserSpells(_ spells:[Spell],entries:[UUID:CompendiumEntry]) -> [Spell] {
        var result:[Spell]=[],positions:[String:Int]=[:]
        for spell in spells {
            let key=spell.name.replacingOccurrences(of:"’",with:"'").trimmingCharacters(in:.whitespacesAndNewlines).lowercased()+"|"+String(spell.level)
            if entries[spell.id]?.custom == true { result.append(spell);continue }
            if let i=positions[key] {
                let prior=result[i]
                var chosen=entries[spell.id] != nil && entries[prior.id] == nil ? spell:prior
                chosen.classes=Array(Set([prior.classes,spell.classes].compactMap { $0 }.flatMap { $0.components(separatedBy:",") }.map { $0.trimmingCharacters(in:.whitespaces) }.filter { !$0.isEmpty })).sorted().joined(separator:", ")
                result[i]=chosen
            } else { positions[key]=result.count;result.append(spell) }
        }
        return result
    }
}
