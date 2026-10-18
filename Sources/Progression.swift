import Foundation
import CryptoKit

enum CastingProgression:String,Codable,CaseIterable {
    case none = "None", full = "Full caster", half = "Half caster", halfUp = "Half, round up", third = "Third caster", pact = "Pact Magic", custom = "Custom"
    func contribution(_ level:Int,edition:String) -> Int {
        switch self { case .full:return level; case .half:return edition == "2024" ? (level+1)/2:level/2; case .halfUp:return (level+1)/2; case .third:return level/3; default:return 0 }
    }
}
struct CharacterClassLevel:Codable,Identifiable,Equatable {
    var id = UUID()
    var name:String
    var level:Int
    var hitDie:Int
    var referenceID:UUID?
    var subclass = ""
    var casting = CastingProgression.none
}
struct AdvancementRecord:Codable,Identifiable,Equatable {
    var id = UUID()
    var date = Date()
    var level:Int
    var className:String
    var classLevel:Int
    var summary:String
}
struct ClassProfile:Identifiable {
    var name:String; var die:Int; var saves:[Int]; var casting:Int; var progression:CastingProgression
    var id:String { name }
    static let all:[ClassProfile] = [
        .init(name:"Barbarian",die:12,saves:[0,2],casting:4,progression:.none),.init(name:"Bard",die:8,saves:[1,5],casting:5,progression:.full),
        .init(name:"Cleric",die:8,saves:[4,5],casting:4,progression:.full),.init(name:"Druid",die:8,saves:[3,4],casting:4,progression:.full),
        .init(name:"Fighter",die:10,saves:[0,2],casting:3,progression:.none),.init(name:"Monk",die:8,saves:[0,1],casting:4,progression:.none),
        .init(name:"Paladin",die:10,saves:[4,5],casting:5,progression:.half),.init(name:"Ranger",die:10,saves:[0,1],casting:4,progression:.half),
        .init(name:"Rogue",die:8,saves:[1,3],casting:3,progression:.none),.init(name:"Sorcerer",die:6,saves:[2,5],casting:5,progression:.full),
        .init(name:"Warlock",die:8,saves:[4,5],casting:5,progression:.pact),.init(name:"Wizard",die:6,saves:[3,4],casting:3,progression:.full),
        .init(name:"Artificer",die:8,saves:[2,3],casting:3,progression:.halfUp)
    ]
    static func named(_ name:String) -> ClassProfile? { all.first { name.caseInsensitiveCompare($0.name) == .orderedSame || name.lowercased().hasPrefix($0.name.lowercased()+" [") } }
}
enum AbilityGeneration:String,CaseIterable { case standard = "Standard array", pointBuy = "Point buy", rolled = "Roll 4d6", manual = "Manual" }
enum HPGrowth:String,CaseIterable { case average = "Fixed", rolled = "Roll", manual = "Manual" }

struct CharacterBuildDraft {
    let original:Hero?
    var hero:Hero
    var existingClasses:[CharacterClassLevel]
    var selectedClassID:UUID
    var chosenClass:CharacterClassLevel
    var ancestryReference:UUID?
    var backgroundReference:UUID?
    var classTemplate:CompendiumEntry?
    var ancestryTemplate:CompendiumEntry?
    var backgroundTemplate:CompendiumEntry?
    var classSkillChoices:Set<String> = []
    var trainingAdditions:[TrainingGrant] = []
    var defaultClassFeatureIDs:Set<UUID> = []
    var abilityOverrideReason = ""
    var featInsteadOfASI = false
    var selectedFeatures:[CharacterFeature] = []
    var abilityMethod = AbilityGeneration.standard
    var abilityPool = [15,14,13,12,10,8]
    var assignments = [0,1,2,3,4,5]
    var manualScores = [8,8,8,8,8,8]
    var originAdjustments = [0,0,0,0,0,0]
    var rollDetails:[String] = []
    var hpMethod = HPGrowth.average
    var hpDieResult = 1
    var hasHPRoll = false
    var hpAdjustment = 0
    var increaseCurrentHP = true
    var autoUnarmoredAC = true
    var trainingNotes = ""
    var startingLevel = 1
    var isLevelUp:Bool { original != nil }
    var newLevel:Int { original.map { $0.level+1 } ?? startingLevel }
    var classLevel:Int { (existingClasses.first { $0.id == selectedClassID }?.level ?? 0) + (isLevelUp ? 1:startingLevel) }
    var asiAvailable:Bool { GuideRules.isASI(classTemplate,className:chosenClass.name,level:classLevel,edition:hero.edition) }
    var featChoiceAvailable:Bool {
        asiAvailable || (hero.edition == "2024" && classLevel == 19 && ClassProfile.named(chosenClass.name) != nil) || (classTemplate.map { GuideRules.classChoices($0,from:classLevel,through:classLevel).contains { $0.feature.name.localizedCaseInsensitiveContains("Epic Boon") } } ?? false)
    }
    var startingSkillCount:Int { Int(classTemplate?.value("numSkills") ?? "") ?? (ClassProfile.named(chosenClass.name)?.name == "Rogue" ? 4:ClassProfile.named(chosenClass.name)?.name == "Bard" ? 3:2) }
    var requiredOriginIDs:Set<UUID> { Set([ancestryTemplate,backgroundTemplate].compactMap { $0 }.flatMap { GuideRules.originFeatures($0).map(\.id) }) }
    mutating func chooseOrigin(_ entry:CompendiumEntry) {
        let category:FeatureCategory = entry.category == .race ? .ancestry:.background
        selectedFeatures.removeAll { $0.category == category }
        if entry.category == .race {
            ancestryTemplate = entry; ancestryReference = entry.id; hero.ancestry = entry.name
            if let speed = Int(entry.value("speed")) { hero.speed = speed }
        } else { backgroundTemplate = entry; backgroundReference = entry.id; hero.background = entry.name }
        selectedFeatures += GuideRules.originFeatures(entry)
    }
    var subclassRequirement:Int? {
        guard let entry = classTemplate,!chosenClass.subclass.isEmpty else { return nil }
        return GuideRules.subclasses(entry).first { $0.name.caseInsensitiveCompare(chosenClass.subclass) == .orderedSame }?.level
    }
    mutating func chooseSubclass(_ name:String) {
        if let entry = classTemplate,let option = GuideRules.subclasses(entry).first(where:{ $0.name.caseInsensitiveCompare(name) == .orderedSame }),classLevel < option.level { return }
        chosenClass.subclass = name
        syncClassDefaults()
    }
    mutating func syncClassDefaults() {
        selectedFeatures.removeAll { defaultClassFeatureIDs.contains($0.id) }
        defaultClassFeatureIDs = []
        guard let entry = classTemplate else { return }
        for choice in GuideRules.classChoices(entry,from:isLevelUp ? classLevel:1,through:classLevel) {
            let name = choice.feature.name.lowercased()
            let starting = classLevel >= 1 && !isLevelUp && (name.hasPrefix("starting ") || name.contains("as a level 1 character"))
            let multiclass = isLevelUp && classLevel == 1 && name.contains("multiclass")
            let standard = !choice.optional && choice.subclass == nil
            let subclass = GuideRules.belongs(choice,to:chosenClass.subclass)
            if starting || multiclass || standard || subclass {
                if !selectedFeatures.contains(where:{ $0.id == choice.id }) && !(original?.featureEntries ?? []).contains(where:{ $0.name == choice.feature.name && $0.text == choice.feature.text }) { selectedFeatures.append(choice.feature) }
                defaultClassFeatureIDs.insert(choice.id)
            }
        }
    }
    init(hero original:Hero? = nil) {
        self.original = original
        var h = original ?? Hero()
        if original == nil {
            h.name = ""; h.ancestry = ""; h.background = ""; h.alignment = "Neutral"; h.rulesEdition = "2024"
            h.features = ""; h.featureEntries = []; h.attacks = []; h.items = []; h.gold = 0; h.ac = 10; h.skillRanks = [:]
            h.journalEntries = []; h.counters = []; h.bonuses = []
        }
        hero = h
        existingClasses = original?.progressionClasses ?? []
        let first = existingClasses.first ?? CharacterClassLevel(name:"Fighter",level:0,hitDie:10)
        chosenClass = first; selectedClassID = first.id
        autoUnarmoredAC = original == nil || h.ac == 10+h.modifier(1)
    }
    var resultingClasses:[CharacterClassLevel] {
        var result = existingClasses
        var choice = chosenClass; choice.id = selectedClassID; choice.level = classLevel
        if let i = result.firstIndex(where:{ $0.id == selectedClassID }) { result[i] = choice } else { result.append(choice) }
        return result
    }
    var pointCost:Int { manualScores.reduce(0) { $0 + ([8:0,9:1,10:2,11:3,12:4,13:5,14:7,15:9][$1] ?? 100) } }
    var generatedScores:[Int] { abilityMethod == .standard || abilityMethod == .rolled ? assignments.map { abilityPool[$0] }:manualScores }
    mutating func assign(_ poolIndex:Int,to index:Int) {
        guard let other = assignments.firstIndex(of:poolIndex) else { return }
        assignments.swapAt(index,other)
    }
    mutating func changeAbilityMethod(_ method:AbilityGeneration) {
        let prior = generatedScores
        abilityMethod = method
        if method == .standard { abilityPool = [15,14,13,12,10,8]; assignments = Array(0..<6); rollDetails = [] }
        if method == .pointBuy { manualScores = Array(repeating:8,count:6) }
        if method == .manual { manualScores = prior }
        if method == .rolled { abilityPool = Array(repeating:8,count:6); assignments = Array(0..<6); rollDetails = [] }
    }
    mutating func rollAbilities() throws -> [RollResult] {
        var results:[RollResult] = []; var pool:[Int] = []; var details:[String] = []
        for i in 0..<6 {
            var roll = try Dice.roll("4d6",label:"Ability score \(i+1)")
            let dropped = roll.dice.min() ?? 1; let total = roll.total-dropped
            details.append(roll.dice.map(String.init).joined(separator:", ")+" · drop \(dropped) = \(total)")
            roll.total = total; roll.detail = "4d6, drop lowest \(dropped)"; results.append(roll); pool.append(total)
        }
        abilityPool = pool; assignments = Array(0..<6); rollDetails = details; return results
    }
    mutating func prioritizeAbilities() {
        let name = ClassProfile.named(chosenClass.name)?.name ?? "Fighter"
        let order = ["Barbarian":[0,2,1,4,5,3],"Bard":[5,1,2,4,3,0],"Cleric":[4,2,0,1,5,3],"Druid":[4,2,1,3,5,0],"Fighter":[0,2,1,4,5,3],"Monk":[1,4,2,0,3,5],"Paladin":[0,5,2,4,1,3],"Ranger":[1,4,2,0,3,5],"Rogue":[1,2,3,4,5,0],"Sorcerer":[5,2,1,4,3,0],"Warlock":[5,2,1,4,3,0],"Wizard":[3,2,1,4,5,0],"Artificer":[3,2,1,4,5,0]][name]!
        if abilityMethod == .pointBuy {
            let values = [15,14,14,10,10,8]
            for (rank,index) in order.enumerated() { manualScores[index] = values[rank] }
        } else {
            let poolOrder = abilityPool.indices.sorted { abilityPool[$0] == abilityPool[$1] ? $0 < $1:abilityPool[$0] > abilityPool[$1] }
            for (rank,index) in order.enumerated() { assignments[index] = poolOrder[rank] }
        }
    }
    var result:Hero {
        var h = hero
        h.name = h.name.trimmingCharacters(in:.whitespacesAndNewlines)
        h.level = newLevel; h.classLevels = resultingClasses
        h.characterClass = resultingClasses.map { "\($0.name) \($0.level)" }.joined(separator:" / ")
        h.featureEntries = (h.featureEntries ?? []) + selectedFeatures
        h.trainingGrants = (h.trainingGrants ?? []) + trainingAdditions
        if !isLevelUp {
            h.trainingGrants! += classSkillChoices.sorted().map { TrainingGrant(id:guideID(h.id.uuidString+"-class-"+$0),target:"skill."+$0,source:chosenClass.name+" · starting class") }
            h.trainingGrants! += hero.saveProficiencies.map { TrainingGrant(id:guideID(h.id.uuidString+"-save-\($0)"),target:"save.\($0)",source:chosenClass.name+" · starting class") }
            h.saveProficiencies = []
            for entry in [ancestryTemplate,backgroundTemplate].compactMap({ $0 }) { h.trainingGrants! += GuideRules.training(entry) }
            h.ancestryFacts = ancestryTemplate.map(GuideRules.originFacts); h.backgroundFacts = backgroundTemplate.map(GuideRules.originFacts)
        }
        if !trainingNotes.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
            h.featureEntries!.append(CharacterFeature(id:guideID("training-"+h.id.uuidString+"-\(newLevel)"),name:"Languages & training",text:trainingNotes,category:.other,source:isLevelUp ? "Level \(newLevel)":"Character creation"))
        }
        if !isLevelUp { h.scores = zip(generatedScores,originAdjustments).map(+) }
        let con = h.modifier(2)
        if let old = original {
            let die = hpMethod == .average ? chosenClass.hitDie/2+1:hpDieResult
            h.maxHP = old.maxHP + max(1,die+con) + (con-old.modifier(2))*old.level + hpAdjustment
            let delta = h.maximumHP-old.maximumHP
            h.hp = min(h.maximumHP,max(0,old.hp + (increaseCurrentHP ? delta:0)))
        } else {
            h.maxHP = max(1,chosenClass.hitDie+con) + (startingLevel-1)*max(1,chosenClass.hitDie/2+1+con) + hpAdjustment
            h.hp = h.maximumHP
        }
        if autoUnarmoredAC { h.ac = 10+h.modifier(1) }
        h.hitDie = resultingClasses.first?.hitDie ?? chosenClass.hitDie
        let oldPools = original?.hitDicePools ?? []
        var remainingUsed = original?.hitDiceUsed ?? 0
        h.hitDicePools = resultingClasses.map { c in
            let prior = oldPools.first { $0.id == c.id } ?? oldPools.first { $0.name == c.name }
            let used = min(c.level,prior?.used ?? min(c.level,remainingUsed)); remainingUsed = max(0,remainingUsed-used)
            return HitDicePool(id:c.id,name:c.name,sides:c.hitDie,total:c.level,used:used)
        }
        h.hitDiceUsed = h.hitDicePools!.reduce(0) { $0+$1.used }
        return h
    }
    var problems:[String] {
        var list:[String] = []
        if hero.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { list.append("Give your character a name.") }
        if chosenClass.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { list.append("Choose or name a class.") }
        if let required = subclassRequirement,classLevel < required { list.append("The selected subclass requires \(chosenClass.name) class level \(required).") }
        if !isLevelUp && hero.ancestry.isEmpty { list.append("Choose an ancestry or complete a custom ancestry.") }
        if !isLevelUp && hero.background.isEmpty { list.append("Choose a background or complete a custom background.") }
        if !isLevelUp && classSkillChoices.count != startingSkillCount { list.append("Choose \(startingSkillCount) class skills in Training.") }
        if isLevelUp,let old = original,hero.scores != old.scores,abilityOverrideReason.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
            if !asiAvailable { list.append("No ability improvement is granted at this class level.") }
            else if featInsteadOfASI { list.append("Choose an ability improvement or another feat, rather than both.") }
            else {
                let delta = zip(hero.scores,old.scores).map { $0-$1 }
                if delta.contains(where:{ $0 < 0 }) || delta.reduce(0,+) > 2 { list.append("An ASI grants up to two ability points without lowering other scores.") }
                if (0..<6).contains(where:{ hero.scores[$0] != old.scores[$0] && result.effectiveScore($0) > 20 }) { list.append("Ability Score Improvement cannot raise a score above 20.") }
            }
        }
        if existingClasses.contains(where:{ $0.id != selectedClassID && $0.name.caseInsensitiveCompare(chosenClass.name) == .orderedSame }) { list.append("This class already has levels. Select the existing class to advance it.") }
        if newLevel > 20 { list.append("This character is already at level 20.") }
        if isLevelUp && existingClasses.reduce(0,{ $0+$1.level }) != original!.level { list.append("Existing class levels must total \(original!.level).") }
        if !isLevelUp && abilityMethod == .pointBuy && pointCost > 27 { list.append("Point buy exceeds 27 points by \(pointCost-27).") }
        if !isLevelUp && abilityMethod == .rolled && rollDetails.isEmpty { list.append("Roll your six ability scores.") }
        if !result.scores.allSatisfy({ (1...30).contains($0) }) { list.append("Final ability scores must be between 1 and 30.") }
        if !(1...999).contains(result.maxHP) { list.append("Maximum HP must be between 1 and 999.") }
        if hpMethod == .rolled && isLevelUp && !hasHPRoll { list.append("Roll your HP die, or choose Manual to enter a roll.") }
        if hpMethod != .average && isLevelUp && !(1...chosenClass.hitDie).contains(hpDieResult) { list.append("HP die result must be between 1 and \(chosenClass.hitDie). Use the adjustment field for extra HP.") }
        if zip(hero.slots,hero.usedSlots).contains(where:{ $0 < $1 }) { list.append("Slot totals cannot be lower than already-expended slots.") }
        return list
    }
    func finalized() throws -> Hero {
        guard problems.isEmpty else { throw GuideError.invalid(problems.joined(separator:"\n")) }
        var h = result
        let summary = changeSummary.joined(separator:"\n")
        h.advancementHistory = (h.advancementHistory ?? []) + [AdvancementRecord(level:newLevel,className:chosenClass.name,classLevel:classLevel,summary:summary)]
        h.journalEntries = (h.journalEntries ?? []) + [JournalEntry(title:isLevelUp ? "Level \(newLevel) · \(chosenClass.name) \(classLevel)":"Character creation",description:summary)]
        try validate(Archive(heroes:[h],library:[])); return h
    }
    var changeSummary:[String] {
        let h = result
        var lines = ["\(chosenClass.name) → class level \(classLevel)","Total level: \(original?.level ?? 0) → \(newLevel)","Maximum HP: \(original?.maximumHP ?? 0) → \(h.maximumHP)","Proficiency: \(signed(original?.proficiency ?? 0)) → \(signed(h.proficiency))"]
        for i in 0..<6 where original == nil || original!.effectiveScore(i) != h.effectiveScore(i) { lines.append("\(abilities[i]): \(original.map { String($0.effectiveScore(i)) } ?? "—") → \(h.effectiveScore(i))") }
        for i in 0..<9 where original?.slots[i] != h.slots[i] && (h.slots[i] > 0 || (original?.slots[i] ?? 0) > 0) { lines.append("Level \(i+1) slots: \(original?.slots[i] ?? 0) → \(h.slots[i])") }
        if let original {
            for spell in original.spells where !h.spells.contains(where:{ $0.id == spell.id }) { lines.append("Remove spell: \(spell.name)") }
            for item in original.items where !h.items.contains(where:{ $0.id == item.id }) { lines.append("Remove equipment: \(item.name)") }
            for spell in h.spells { if let old = original.spells.first(where:{ $0.id == spell.id }),old.prepared != spell.prepared { lines.append("\(spell.name): \(spell.prepared ? "Prepared":"Unprepared")") } }
            if h.saveProficiencies != original.saveProficiencies { lines.append("Saving throw proficiencies: \(h.saveProficiencies.map { abilities[$0] }.joined(separator:", "))") }
            if h.bonuses != original.bonuses { lines.append("Explicit bonuses updated: \((h.bonuses ?? []).count) configured") }
            if h.counters != original.counters { lines.append("Resource counters updated: \((h.counters ?? []).count) configured") }
            if h.armorClass != original.armorClass { lines.append("Armor class: \(original.armorClass) → \(h.armorClass)") }
        }
        lines += selectedFeatures.map { "Feature: \($0.name)" }
        lines += h.spells.filter { spell in !(original?.spells.contains { $0.id == spell.id } ?? false) }.map { "Spell: \($0.name)" }
        lines += h.items.filter { item in !(original?.items.contains { $0.id == item.id } ?? false) }.map { "Equipment: \($0.name) ×\($0.quantity)" }
        for name in skills.map(\.0) where (original?.skillRanks[name] ?? 0) != (h.skillRanks[name] ?? 0) { lines.append("\(name): rank \(original?.skillRanks[name] ?? 0) → \(h.skillRanks[name] ?? 0)") }
        return lines
    }
}
enum GuideError:LocalizedError {
    case invalid(String), changed
    var errorDescription:String? { switch self { case .invalid(let message):return message; case .changed:return "The character changed while this guide was open. Close the guide and reopen Level up to use the latest character." } }
}
extension Hero {
    var progressionClasses:[CharacterClassLevel] {
        if let classLevels, !classLevels.isEmpty { return classLevels }
        if let pools = hitDicePools, !pools.isEmpty { return pools.map { CharacterClassLevel(id:$0.id,name:$0.name,level:$0.total,hitDie:$0.sides,casting:ClassProfile.named($0.name)?.progression ?? .custom) } }
        return [CharacterClassLevel(id:id,name:characterClass,level:level,hitDie:hitDie,casting:ClassProfile.named(characterClass)?.progression ?? .custom)]
    }
}
func validateProgression(_ h:Hero) throws {
    let targets = Set(skills.map { "skill."+$0.0 } + (0..<6).map { "save.\($0)" })
    guard h.allTraining.allSatisfy({ (1...2).contains($0.rank) && targets.contains($0.target) }) else { throw CocoaError(.fileReadCorruptFile) }
    if let classes = h.classLevels {
        guard !classes.isEmpty, Set(classes.map(\.id)).count == classes.count, classes.reduce(0,{ $0+$1.level }) == h.level,
              classes.allSatisfy({ (1...20).contains($0.level) && [6,8,10,12].contains($0.hitDie) && !$0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }) else { throw CocoaError(.fileReadCorruptFile) }
    }
}
func guideID(_ key:String) -> UUID {
    let hex = SHA256.hash(data:Data(key.utf8)).prefix(16).map { String(format:"%02x",$0) }.joined()
    let a = Array(hex); let parts = [String(a[0..<8]),String(a[8..<12]),String(a[12..<16]),String(a[16..<20]),String(a[20..<32])]
    return UUID(uuidString:parts.joined(separator:"-"))!
}
enum GuideRules {
    static func reviewedSpell(_ entry:CompendiumEntry,level:Int,hero:Hero) throws -> Spell {
        guard entry.category == .spell,(0...9).contains(level) else { throw GuideError.invalid("Confirm the spell level first.") }
        let node = entry.node; node.children.removeAll { $0.name == "level" }
        let confirmed = XMLNode("level"); confirmed.text = String(level); node.children.append(confirmed)
        var warnings:[String] = []
        var spell = FightClubImport.spell(node,hero:hero,ability:nil,isCharacter:false,warnings:&warnings)
        spell.id = entry.id; return spell
    }
    static let casterSlots:[[Int]] = [[],[2],[3],[4,2],[4,3],[4,3,2],[4,3,3],[4,3,3,1],[4,3,3,2],[4,3,3,3,1],[4,3,3,3,2],[4,3,3,3,2,1],[4,3,3,3,2,1],[4,3,3,3,2,1,1],[4,3,3,3,2,1,1],[4,3,3,3,2,1,1,1],[4,3,3,3,2,1,1,1],[4,3,3,3,2,1,1,1,1],[4,3,3,3,3,1,1,1,1],[4,3,3,3,3,2,1,1,1],[4,3,3,3,3,2,2,1,1]]
    static func slots(at level:Int) -> [Int] { let row = casterSlots[min(20,max(0,level))]; return row+Array(repeating:0,count:9-row.count) }
    static func featureChoices(_ entry:CompendiumEntry,from:Int,through:Int) -> [CharacterFeature] {
        if entry.category != .classEntry { return entry.featureCopies().enumerated().map { i,feature in var f = feature; f.id = guideID(entry.id.uuidString+"-\(i)"); return f } }
        return entry.fields.enumerated().filter { _,field in field.name == "autolevel" && (Int(field.attributes["level"] ?? "1") ?? 1) >= from && (Int(field.attributes["level"] ?? "1") ?? 1) <= through }.flatMap { index,field in
            field.children.enumerated().filter { $0.element.name == "feature" }.map { childIndex,node in
                CharacterFeature(id:guideID(entry.id.uuidString+"-\(index)-\(childIndex)"),name:node.children.first(where:{ $0.name == "name" })?.text ?? "Class feature",text:node.children.filter { $0.name != "name" }.map(\.readable).joined(separator:"\n\n"),category:.classFeature,source:"\(entry.name) · Level \(field.attributes["level"] ?? "?")")
            }
        }
    }
    static func importedCastingRow(_ entry:CompendiumEntry,at level:Int) -> [Int]? {
        let row = entry.fields.last { $0.name == "autolevel" && (Int($0.attributes["level"] ?? "0") ?? 0) <= level && $0.children.contains { $0.name == "slots" } }
        let values = row?.children.first { $0.name == "slots" }?.text.split(separator:",").compactMap { Int($0.trimmingCharacters(in:.whitespacesAndNewlines)) } ?? []
        guard values.count == 10, values.allSatisfy({ (0...20).contains($0) }) else { return nil }; return values
    }
    static func importedSlots(_ entry:CompendiumEntry,at level:Int) -> [Int]? { importedCastingRow(entry,at:level).map { Array($0.dropFirst()) } }
    static func importedCantrips(_ entry:CompendiumEntry,at level:Int) -> Int? { importedCastingRow(entry,at:level)?.first }
}
