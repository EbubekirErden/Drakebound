import SwiftUI

extension CharacterGuide {
    var candidates:[CharacterFeature] {
        if featureGroup == "Class",let entry = classReference {
            return GuideRules.classChoices(entry,from:draft.isLevelUp ? draft.classLevel:1,through:draft.classLevel).filter { $0.subclass == nil || GuideRules.belongs($0,to:draft.chosenClass.subclass) }.map(\.feature).filter(featureMatches)
        }
        let entry = featureGroup == "Ancestry" ? draft.ancestryTemplate:draft.backgroundTemplate
        return entry.map(GuideRules.originFeatures)?.filter(featureMatches) ?? []
    }
    var eligibleFeats:[CompendiumEntry] { catalog.feats.filter { GuideRules.featMinimumLevel($0) <= draft.newLevel } }
    var reviewStep:some View {
        GuideReview(draft:draft,catalog:catalog,onEdit:{ go(to:$0,showProblems:true) },onPreview:{ fullPreview=true },onLoadoutEdit:{ loadoutPage=$0;go(to:.loadout) })
    }
    var classReferenceOptions:[CompendiumEntry] {
        guard draft.isLevelUp,let prior = draft.existingClasses.first(where:{ $0.id == draft.selectedClassID }) else { return catalog.classes }
        let base = ClassProfile.named(prior.name)?.name ?? prior.name
        return catalog.classes.filter { (ClassProfile.named($0.name)?.name ?? $0.name).caseInsensitiveCompare(base) == .orderedSame }
    }
    var classCastingAbility:Int {
        if let entry = classReference,let i = abilities.firstIndex(where:{ $0.caseInsensitiveCompare(entry.value("spellAbility")) == .orderedSame }) { return i }
        return ClassProfile.named(draft.chosenClass.name)?.casting ?? draft.hero.castingAbility
    }
    func linkClassReference() {
        let name = draft.chosenClass.name
        let match = catalog.classes.first { $0.name == name+(draft.hero.edition == "2024" ? " [2024]":"") } ?? catalog.classReference(name,edition:draft.hero.edition)
        draft.chosenClass.referenceID = match?.id
    }
    func selectExisting(_ record:CharacterClassLevel) {
        draft.classTemplate = nil
        draft.selectedClassID = record.id; draft.chosenClass = record; draft.selectedFeatures.removeAll { $0.category == .classFeature }
        if record.referenceID == nil { linkClassReference() } else if let entry = classReference { draft.classTemplate = entry; draft.syncClassDefaults() }; updateCasterLevel()
    }
    func selectProfile(_ name:String) {
        draft.selectedFeatures.removeAll { $0.category == .classFeature }
        draft.chosenClass.referenceID = nil; draft.classTemplate = nil; draft.classSkillChoices = []
        guard let profile = ClassProfile.named(name) else { draft.chosenClass.name = "Custom class"; draft.chosenClass.casting = .custom; return }
        draft.chosenClass.subclass = ""; draft.chosenClass.name = profile.name; draft.chosenClass.hitDie = profile.die; draft.chosenClass.casting = profile.progression
        if !draft.isLevelUp { draft.hero.saveProficiencies = profile.saves; draft.hero.castingAbility = profile.casting; draft.hero.slots = profile.progression == .full ? GuideRules.slots(at:draft.startingLevel):Array(repeating:0,count:9) }
        linkClassReference(); updateCasterLevel()
    }
    func applyClass(_ entry:CompendiumEntry) {
        draft.selectedFeatures.removeAll { $0.category == .classFeature }
        if (ClassProfile.named(draft.chosenClass.name)?.name ?? draft.chosenClass.name) != (ClassProfile.named(entry.name)?.name ?? entry.name) { draft.chosenClass.subclass = "" }
        draft.classTemplate = entry
        draft.classSkillChoices = draft.classSkillChoices.intersection(classSkillOptions)
        draft.chosenClass.name = entry.name
        if let die = Int(entry.value("hd")),[6,8,10,12].contains(die) { draft.chosenClass.hitDie = die }
        draft.chosenClass.casting = ClassProfile.named(entry.name)?.progression ?? .custom
        if !draft.isLevelUp {
            let saves = abilities.enumerated().filter { entry.value("proficiency").localizedCaseInsensitiveContains($0.element+" Saving Throws") }.map(\.offset)
            draft.hero.saveProficiencies = saves; draft.hero.castingAbility = classCastingAbility
            draft.hero.slots = Array(repeating:0,count:9); draft.hero.slotsRecoverOnShortRest = false
            if draft.chosenClass.casting != .none,let slots = GuideRules.importedSlots(entry,at:draft.classLevel) { draft.hero.slots = slots; draft.hero.slotsRecoverOnShortRest = entry.value("slotsReset") == "S" }
        }
        draft.syncClassDefaults(); updateCasterLevel()
    }
    func updateCasterLevel() { casterLevel = min(20,draft.resultingClasses.reduce(0) { $0+$1.casting.contribution($1.level,edition:draft.hero.edition) }) }
    func equipment(_ entry:CompendiumEntry) -> Item {
        var item = entry.item()
        if let ac = Int(entry.value("ac")),(0...30).contains(ac) {
            if item.equipmentKind == .shield { item.bonuses = [Bonus(name:entry.name,target:"ac",amount:ac)] }
            else if [.lightArmor,.mediumArmor,.heavyArmor].contains(item.equipmentKind) { item.armorBase = ac; item.armorAddsDexterity = item.equipmentKind != .heavyArmor; item.armorDexterityCap = item.equipmentKind == .mediumArmor ? 2:20 }
        }
        return item
    }
    func suggestedAttack(_ item:Item) -> Attack {
        if let existing = draft.hero.attacks.first(where:{ $0.name == item.name }) { return existing }
        let entry = catalog.items.first { $0.name == item.name }
        let damage = entry?.value("dmg1") ?? ""
        return Attack(name:item.name,ability:item.equipmentKind == .ranged ? 1:0,proficient:draft.result.weaponTraining(for:item) ?? true,damage:(try? Dice.roll(damage)) == nil ? "1d6":damage,type:entry.map { (["B":"Bludgeoning","P":"Piercing","S":"Slashing"][ $0.value("dmgType")] ?? $0.value("dmgType")) } ?? "",description:item.notes,equipmentID:item.id)
    }
}
