import Foundation

@main struct ProgressionTests {
    static func main() throws {
        var creation = CharacterBuildDraft()
        assert(creation.hero.attacks.isEmpty && creation.hero.items.isEmpty && creation.hero.features.isEmpty)
        assert(creation.hero.featureEntries == [] && creation.problems.contains { $0.contains("name") })
        creation.classSkillChoices = ["Athletics","Perception"]
        creation.hero.name = "  Guide Test  "
        creation.hero.ancestry = "Custom ancestry"; creation.hero.background = "Custom background"
        creation.changeAbilityMethod(.manual); creation.manualScores = [15,14,14,12,10,8]
        assert(creation.result.maxHP == 12 && creation.result.ac == 12)
        assert(creation.result.hitDicePools?.first?.total == 1)
        creation.startingLevel = 5
        assert(creation.result.maxHP == 44 && creation.result.level == 5 && creation.result.proficiency == 3)
        let created = try creation.finalized()
        assert(created.name == "Guide Test" && created.classLevels?.first?.level == 5)
        assert(created.journalEntries?.count == 1 && created.advancementHistory?.count == 1)
        try validate(Archive(heroes:[created],library:[]))
        creation.changeAbilityMethod(.standard); creation.assign(5,to:0)
        assert(creation.generatedScores[0] == 8 && creation.generatedScores.sorted() == [8,10,12,13,14,15])
        creation.changeAbilityMethod(.pointBuy); assert(creation.pointCost == 0)
        creation.manualScores = Array(repeating:15,count:6)
        assert(creation.pointCost == 54 && creation.problems.contains { $0.contains("Point buy") })
        do { _ = try creation.finalized(); fatalError("Accepted overspent point buy") } catch {}
        creation.manualScores = [15,15,15,8,8,8]; assert(creation.pointCost == 27)
        creation.prioritizeAbilities(); assert(creation.pointCost == 27)
        creation.changeAbilityMethod(.rolled)
        assert(creation.problems.contains { $0.contains("Roll your six") })
        for _ in 0..<50 {
            let rolls = try creation.rollAbilities()
            assert(creation.abilityPool.count == 6 && rolls.count == 6)
            for roll in rolls { assert(roll.dice.count == 4 && roll.total == roll.dice.reduce(0,+)-roll.dice.min()!) }
            assert(creation.abilityPool.allSatisfy { (3...18).contains($0) })
        }
        var old = Hero.sample
        old.migrateContent(); old.tempHP = 7; old.usedSlots = [2,1,0,0,0,0,0,0,0]; old.hitDiceUsed = 3
        old.conditions = ["Poisoned"]; old.counters = [ResourceCounter(name:"Uses",current:1,maximum:3)]
        let snapshot = old
        var level = CharacterBuildDraft(hero:old)
        assert(level.result.level == 6 && level.result.maxHP == 38 && level.result.hp == 34)
        assert(level.result.hitDicePools!.first!.total == 6 && level.result.hitDiceUsed == 3)
        level.hero.scores[1] += 2; assert(level.result.armorClass == old.armorClass+1)
        level.hero.scores[1] -= 2
        level.hpMethod = .rolled; assert(level.problems.contains { $0.contains("Roll your HP") }); level.hpMethod = .average
        level.abilityOverrideReason = "Test explicit feature increase"
        level.hero.scores[2] += 2
        assert(level.result.maxHP == 44 && level.result.hp == 40) // +7 new level, +5 retroactive Con.
        assert(level.result.usedSlots == old.usedSlots && level.result.tempHP == 7 && level.result.conditions == old.conditions)
        assert(level.result.counters == old.counters && old == snapshot) // Drafts never mutate the source.
        level.increaseCurrentHP = false; assert(level.result.hp == old.hp)
        level.hero.slots[0] = 1; assert(level.problems.contains { $0.contains("Slot totals") })
        level.hero.slots[0] = 4
        let advanced = try level.finalized()
        assert(advanced.advancementHistory?.last?.level == 6)
        assert(advanced.journalEntries!.last!.title == "Level 6 · Wizard 6")
        let archive = Archive(heroes:[advanced],library:starterSpells)
        let roundtrip = try JSONDecoder().decode(Archive.self,from:JSONEncoder().encode(archive)); try validate(roundtrip)
        assert(roundtrip.heroes.first == advanced)
        var maxed = old; maxed.level = 20
        assert(CharacterBuildDraft(hero:maxed).problems.contains { $0.contains("level 20") })
        var malformed = advanced; malformed.classLevels![0].level = 2
        do { try validate(Archive(heroes:[malformed],library:[])); fatalError("Accepted mismatched class levels") } catch {}
        assert(CastingProgression.half.contribution(3,edition:"2014") == 1)
        assert(CastingProgression.half.contribution(3,edition:"2024") == 2)
        assert(CastingProgression.halfUp.contribution(1,edition:"2014") == 1)
        assert(GuideRules.slots(at:5) == [4,3,2,0,0,0,0,0,0])
        assert(GuideRules.slots(at:20) == [4,3,3,3,3,2,2,1,1])
        var warlock = old; warlock.slotsRecoverOnShortRest = true
        warlock.resetCounters(for:.shortRest); assert(warlock.usedSlots.allSatisfy { $0 == 0 } && warlock.counters == old.counters)
        var normal = old; normal.resetCounters(for:.shortRest); assert(normal.usedSlots == old.usedSlots)
        // Independent grants preserve provenance without adding the proficiency bonus twice.
        var trained = Hero.sample; trained.skillRanks = [:]; trained.saveProficiencies = []
        trained.trainingGrants = [TrainingGrant(target:"skill.Arcana",source:"Background"),TrainingGrant(target:"skill.Arcana",source:"Class"),TrainingGrant(target:"save.3",source:"Class")]
        assert(trained.effectiveSkillRank("Arcana") == 1 && trained.skillBonus("Arcana",3) == trained.modifier(3)+trained.proficiency)
        assert(trained.trainingSources("skill.Arcana") == ["Background","Class"])
        trained.featureEntries = [CharacterFeature(name:"Expert training",training:[TrainingGrant(target:"skill.Arcana",rank:2,source:"Feat")])]
        assert(trained.effectiveSkillRank("Arcana") == 2 && trained.skillBonus("Arcana",3) == trained.modifier(3)+2*trained.proficiency)
        assert(trained.saveBonus(3) == trained.modifier(3)+trained.proficiency)
        trained.bonuses = [Bonus(name:"Extra",target:"skill.Arcana",amount:1)]
        assert(trained.skillBonus("Arcana",3) == trained.modifier(3)+2*trained.proficiency+1)
        let scopedXML = Data("<pc><character><name>Scoped caster</name><abilities>10,10,10,10,10,10</abilities><class><name>Artificer</name><level>1</level><spell><name>Repair</name><level>0</level><sclass>Artificer</sclass></spell></class></character></pc>".utf8)
        let scoped = try FightClubImport.read(scopedXML).heroes[0]
        assert(scoped.spells[0].sourceClassName == "Artificer" && scoped.spells[0].sourceClassID == scoped.hitDicePools![0].id && scoped.spells[0].classes == "Artificer")
        assert(!GuideRules.isASI(nil,className:"Wizard [2024]",level:19,edition:"2024"))
        assert(GuideRules.isASI(nil,className:"Fighter",level:6) && GuideRules.isASI(nil,className:"Rogue",level:10))
        var split = old; split.level = 3; split.classLevels = [CharacterClassLevel(name:"Artificer",level:1,hitDie:8),CharacterClassLevel(name:"Wizard [2024]",level:2,hitDie:6)]
        var splitDraft = CharacterBuildDraft(hero:split)
        splitDraft.selectedClassID = split.classLevels![1].id; splitDraft.chosenClass = split.classLevels![1]
        assert(splitDraft.newLevel == 4 && splitDraft.classLevel == 3 && !splitDraft.asiAvailable)
        splitDraft.hero.scores[3] += 1
        assert(splitDraft.problems.contains { $0.contains("No ability improvement") })
        split.classLevels![1].level = 3; split.level = 4
        splitDraft = CharacterBuildDraft(hero:split); splitDraft.selectedClassID = split.classLevels![1].id; splitDraft.chosenClass = split.classLevels![1]
        assert(splitDraft.classLevel == 4 && splitDraft.asiAvailable)
        splitDraft.hero.scores[3] += 3
        assert(splitDraft.problems.contains { $0.contains("two ability points") })
        var origin = ReferenceTemplateDraft(category:.race)
        assert(!origin.issues.isEmpty)
        origin.name = "Sky folk"; origin.traits = [TemplateTrait(name:"Flight",text:"Flying speed 30 feet.")]
        assert(origin.issues.isEmpty)
        var origins = creation; origins.chooseOrigin(origin.entry)
        assert(origins.selectedFeatures.contains { $0.name == "Flight" } && origins.requiredOriginIDs.count == 1)
        var background = ReferenceTemplateDraft(category:.background)
        background.name = "Scholar"; background.traits = [TemplateTrait(name:"Researcher",text:"A useful reference.")]
        assert(!background.issues.isEmpty); background.values["proficiency"] = "Arcana, History"
        assert(background.issues.isEmpty)
        origins.chooseOrigin(background.entry)
        assert(origins.result.trainingSources("skill.Arcana").contains("Scholar"))
        var templateSpell = Spell(name:"Reusable",level:1); templateSpell.sourceClassID = UUID(); templateSpell.sourceClassName = "Wizard"; templateSpell.freeUses = 2; templateSpell.freeRemaining = 0
        templateSpell.rolls = [NamedRoll(name:"Damage",expression:"1d6+{spell}")]
        let spellTemplate = TemplateFactory.spell(templateSpell)
        assert(spellTemplate.spell()?.sourceClassID == nil && spellTemplate.spell()?.freeRemaining == 2 && spellTemplate.spell()?.rolls == templateSpell.rolls)
        var item = Item(name:"Reusable blade",quantity:3,equipped:true); item.rolls = templateSpell.rolls; item.bonuses = [Bonus(name:"Magic",target:"ac",amount:1)]
        let itemTemplate = TemplateFactory.item(item); let itemCopy = itemTemplate.item()
        assert(itemCopy.id != item.id && !itemCopy.equipped && itemCopy.quantity == 1 && itemCopy.bonuses == item.bonuses && itemCopy.rolls == item.rolls)
        var feature = CharacterFeature(name:"Uses",counter:ResourceCounter(name:"Charges",current:0,maximum:3)); feature.training = trained.trainingGrants
        let featureTemplate = TemplateFactory.feature(feature)
        assert(featureTemplate.featureCopies()[0].counter?.current == 3 && featureTemplate.featureCopies()[0].training == feature.training)
        let templates = [spellTemplate,itemTemplate,featureTemplate,TemplateFactory.creature(Creature(name:"Ally",hp:1,maximumHP:12)),origin.entry,background.entry]
        let templateCopies = try JSONDecoder().decode([CompendiumEntry].self,from:JSONEncoder().encode(templates))
        assert(templateCopies == templates && templateCopies[3].creature().hp == 12)
        print("PASS: source-aware proficiency/expertise, class-specific ASI milestones, multiclass gating, structured custom origins, and reusable compendium template round trips")
        if CommandLine.arguments.count > 1 {
            let imported = try FightClubImport.read(Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
            var shennie = imported.heroes[0]
            let dagger = shennie.attacks.first { $0.name == "Dagger" }!
            assert(shennie.attackUnavailableReason(dagger) == "Unequipped" && dagger.equipmentID != nil)
            let daggerIndex = shennie.items.firstIndex { $0.id == dagger.equipmentID }!
            shennie.items[daggerIndex].equipped = true; assert(shennie.attackUnavailableReason(dagger) == nil)
            shennie.items[daggerIndex].equipped = false
            assert(shennie.spells.first { $0.name.contains("Cure Wounds") }?.sourceClassName == "Wizard [2024]")
            let sourceSpellIDs = shennie.spells.map(\.id)
            for i in shennie.spells.indices { shennie.spells[i].sourceClassID = nil; shennie.spells[i].sourceClassName = nil }
            shennie.migrateContent()
            assert(shennie.spells.map(\.id) == sourceSpellIDs && shennie.spells.first { $0.name.contains("Cure Wounds") }?.sourceClassName == "Wizard [2024]")
            var d = CharacterBuildDraft(hero:shennie)
            assert(d.existingClasses.map(\.level) == [7,1])
            assert(d.result.classLevels!.map(\.level) == [8,1] && d.result.level == 9)
            assert(d.result.maxHP == 67 && d.result.proficiency == 4)
            d.hero.scores[2] += 2; assert(d.result.maxHP == 76)
            assert(d.result.sourceXML == shennie.sourceXML && d.result.items == shennie.items && d.result.spells == shennie.spells)
            d = CharacterBuildDraft(hero:shennie)
            d.selectedClassID = UUID(); d.chosenClass = CharacterClassLevel(id:d.selectedClassID,name:"Fighter",level:0,hitDie:10)
            let multi = try d.finalized()
            assert(multi.classLevels!.map(\.level) == [7,1,1] && multi.maxHP == 69)
            assert(multi.saveProficiencies == shennie.saveProficiencies)
            assert(multi.hitDicePools!.map(\.used) == shennie.hitDicePools!.map(\.used)+[0])
            print("PASS: Shennie multiclass advancement, Constitution HP adjustment, preserved XML, inventory, spells, spent dice, and saving throws")
        }
        if CommandLine.arguments.count > 2 {
            let imported = try CompendiumImport.read(Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2])))
            let wizard = imported.entries.first { $0.name == "Wizard [2024]" && $0.category == .classEntry }!
            let subclasses = GuideRules.subclasses(wizard)
            assert(subclasses.contains { $0.name == "Abjurer" && $0.level == 3 })
            let classChoices = GuideRules.classChoices(wizard,from:3,through:3)
            assert(classChoices.contains { $0.feature.name.contains("Abjuration Savant") && GuideRules.belongs($0,to:"Abjurer") })
            assert(!classChoices.contains { $0.feature.name.contains("Evocation Savant") && GuideRules.belongs($0,to:"Abjurer") })
            assert(!GuideRules.isASI(wizard,className:wizard.name,level:2) && GuideRules.isASI(wizard,className:wizard.name,level:4))
            let dwarf = imported.entries.first { $0.name == "Dwarf [2024]" && $0.category == .race }!
            let facts = GuideRules.originFacts(dwarf)
            assert(facts.filter { $0.name == "size" }.count == 1 && facts.filter { $0.name == "type" }.count == 1)
            assert(!GuideRules.originFeatures(dwarf).contains { $0.name == "Size" || $0.name == "Creature Type" })
            var defaults = CharacterBuildDraft(); defaults.classTemplate = wizard; defaults.chosenClass.name = wizard.name; defaults.syncClassDefaults()
            defaults.chooseSubclass("Abjurer")
            assert(defaults.chosenClass.subclass.isEmpty) // Native menu styling cannot bypass the model gate.
            defaults.startingLevel = 3; defaults.chooseSubclass("Abjurer")
            assert(defaults.chosenClass.subclass == "Abjurer" && defaults.selectedFeatures.contains { $0.name.contains("Abjuration Savant") })
            assert(!defaults.selectedFeatures.contains { $0.name.contains("Evocation Savant") })
            defaults.startingLevel = 1
            assert(defaults.problems.contains { $0.contains("subclass") })
            defaults.chooseSubclass("")
            assert(defaults.selectedFeatures.contains { $0.name.contains("Arcane Recovery") })
            assert(!defaults.selectedFeatures.contains { $0.name.contains("Multiclass Character") })
            defaults.chooseOrigin(dwarf)
            assert(Set(GuideRules.originFeatures(dwarf).map(\.id)).isSubset(of:Set(defaults.selectedFeatures.map(\.id))))
            let guideCatalog = GuideCatalog(compendium:imported.entries,library:starterSpells)
            assert(guideCatalog.spells.first { $0.name == "Fire bolt" }?.classes?.contains("Wizard") == true)
            let ray = imported.entries.first { $0.name == "Ray of Frost [2024]" && $0.category == .spell }!
            assert(ray.value("level").isEmpty)
            let reviewed = try GuideRules.reviewedSpell(ray,level:0,hero:old)
            assert(reviewed.level == 0 && reviewed.rolls?.count == 4 && ray.value("level").isEmpty)
            do { _ = try GuideRules.reviewedSpell(ray,level:-1,hero:old); fatalError("Accepted unconfirmed spell level") } catch {}
            let options = GuideRules.featureChoices(wizard,from:8,through:8)
            assert(!options.isEmpty && options.allSatisfy { $0.source!.contains("Level 8") })
            assert(options == GuideRules.featureChoices(wizard,from:8,through:8))
            assert(GuideRules.importedSlots(wizard,at:1) == [2,0,0,0,0,0,0,0,0])
            assert(GuideRules.importedSlots(wizard,at:5) == [4,3,2,0,0,0,0,0,0])
            print("PASS: imported class-level choices, stable selection IDs, and slot tables excluding cantrip counts")
        }
        print("PASS: creation, standard array assignment, point-buy budget, 4d6 drop-lowest, HP growth, class levels, progression JSON, resource preservation, and explicit short-rest slot recovery")
    }
}
