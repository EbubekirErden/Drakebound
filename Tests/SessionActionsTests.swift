import Foundation

@main struct SessionActionsTests {
    static func main() throws {
        var h = Hero.sample
        let pool = ResourceCounter(name:"Focus",current:1,maximum:5,resetOn:[.shortRest])
        let ref = ResourceRef(kind:.counter,id:pool.id)
        let cost = ResourceCost(resource:ref)
        h.counters = [pool]; h.usedSlots = Array(repeating:0,count:9)
        let roll = NamedRoll(name:"Damage",expression:"1d4",resourceCost:cost)
        let a = Spell(name:"Focus spell",level:1,duration:"Concentration, up to 1 minute",rolls:[roll],automaticRollID:roll.id,resourceCost:cost)
        let b = Spell(name:"Other focus",level:0,concentration:true)
        let normal = Spell(name:"Plain spell",level:0)
        h.spells = [a,b,normal]
        let original = h
        do { _ = try h.cast(a.id); fatalError("Two costs used one remaining charge") } catch {}
        assert(h == original,"Failed casting consumed state")
        h.counters![0].current = 5
        _ = try h.cast(a.id)
        assert(h.counters![0].current == 3 && h.usedSlots[0] == 1 && h.concentrationSpellID == a.id)
        assert(h.actionUsage?.first?.count == 1)
        _ = try h.cast(normal.id); assert(h.concentrationSpellID == a.id)
        _ = try h.cast(b.id); assert(h.concentrationSpellID == b.id)
        _ = try h.cast(b.id); assert(h.actionUsage!.first { $0.action.sourceID == b.id }!.count == 2)
        var invalid = a; invalid.rolls![0].expression = "oops"; h.spells[0] = invalid
        let invalidBefore = h
        do { _ = try h.cast(invalid.id); fatalError("Invalid roll accepted") } catch {}
        assert(h == invalidBefore,"Invalid roll consumed state")
        h.spells[0] = a
        var feature = CharacterFeature(name:"Channel",counter:ResourceCounter(name:"Channel uses",current:1,maximum:1,resetOn:[.longRest]),resourceCost:cost)
        h.featureEntries = [feature]
        let featureRef = ResourceRef(kind:.feature,id:feature.id)
        assert(h.resourceChoices.count == 2 && h.resource(featureRef)?.current == 1)
        _ = try h.performAction(SheetActionRef(kind:.featureUse,sourceID:feature.id))
        assert(h.resource(featureRef)?.current == 0 && h.resource(ref)?.current == 2)
        let spent = h
        do { _ = try h.performAction(SheetActionRef(kind:.featureUse,sourceID:feature.id)); fatalError("Spent feature used again") } catch {}
        assert(h == spent)
        h.resetCounters(for:.shortRest)
        assert(h.resource(ref)?.current == 5 && h.resource(featureRef)?.current == 0)
        h.resetCounters(for:.longRest)
        assert(h.resource(featureRef)?.current == 1)
        let item = Item(name:"Wand",rolls:[roll])
        h.items = [item]
        let itemRef = SheetActionRef(kind:.itemRoll,sourceID:item.id,rollID:roll.id)
        _ = try h.performAction(itemRef)
        assert(h.resource(ref)?.current == 4 && h.actionUsage?.first?.action == itemRef)
        h.toggleFavorite(itemRef); assert(h.favoriteActions == [itemRef])
        h.toggleFavorite(itemRef); assert(h.favoriteActions!.isEmpty)
        h.setResource(ref,nil)
        let missing = h
        do { _ = try h.performAction(itemRef); fatalError("Missing resource ignored") } catch {}
        assert(h == missing)
        try validate(Archive(heroes:[h],library:[]))
        let restored = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(h)); assert(restored == h)
        assert(TemplateFactory.spell(a).template?.spell?.resourceCost == nil)
        assert(TemplateFactory.spell(a).template?.spell?.rolls?.first?.resourceCost == nil)
        assert(TemplateFactory.item(item).template?.item?.rolls?.first?.resourceCost == nil)
        assert(TemplateFactory.feature(feature).template?.feature?.resourceCost == nil)
        h.hp = 1; h.damage(1); assert(h.concentrationSpellID == nil)
        _ = try h.cast(b.id); h.longRest(); assert(h.concentrationSpellID == nil)
        _ = try h.cast(b.id); h.conditions = ["Stunned"]; h.reconcileConcentration(); assert(h.concentrationSpellID == nil)
        feature.counter!.current = 0
        assert(Spell(name:"C",level:0,duration:"C, up to 1 minute").requiresConcentration)
        assert(!Spell(name:"C",level:0,duration:"Concentration",concentration:false).requiresConcentration)
        // Group legacy per-roll history without rewriting or dropping stored variants.
        var grouped = Hero.sample
        grouped.level = 8; grouped.conditions = []; grouped.exhaustionLevel = 0
        grouped.slots = [4,3,3,2,0,0,0,0,0]
        let tiers = [1,5,11,17].enumerated().map { NamedRoll(name:"Tier",expression:"\($0.offset+1)d8",minimumCharacterLevel:$0.element) }
        let slots = (3...9).map { NamedRoll(name:"Slot \($0)",expression:"\($0+5)d6",slotLevel:$0) }
        let frost = Spell(name:"Frost",level:0,rolls:tiers)
        let fireball = Spell(name:"Fireball",level:3,rolls:slots)
        grouped.spells = [fireball,frost]; grouped.items = []; grouped.attacks = []; grouped.featureEntries = []
        assert(grouped.sheetActions.count == 2)
        let fireRef = SheetActionRef(kind:.spell,sourceID:fireball.id)
        let frostRef = SheetActionRef(kind:.spell,sourceID:frost.id)
        assert(grouped.quickRolls(fireRef).map(\.slotLevel) == [3,4])
        assert(grouped.quickRolls(frostRef).map(\.expression) == ["2d8"])
        let oldRef = SheetActionRef(kind:.spellRoll,sourceID:fireball.id,rollID:slots.last!.id)
        grouped.noteAction(oldRef); grouped.noteAction(fireRef); grouped.toggleFavorite(oldRef)
        let savedUsage = grouped.actionUsage; let savedFavorites = grouped.favoriteActions
        assert(grouped.actionIsFavorite(fireRef) && grouped.actionHistory(fireRef)?.count == 2)
        assert(grouped.spells[0].rolls?.count == 7 && grouped.actionUsage == savedUsage && grouped.favoriteActions == savedFavorites)
        grouped.toggleActionFavorite(fireRef); assert(grouped.favoriteActions!.isEmpty)
        let staff = Attack(name:"Staff",damage:"1d6")
        grouped.attacks = [staff]
        let damageRef = SheetActionRef(kind:.attackDamage,sourceID:staff.id)
        let damage = try grouped.performAction(damageRef,manual:.advantage)
        assert(damage.dice.count == 1 && damage.expression == grouped.expression(staff.damage,bonus:grouped.damageBonus(staff),targets:grouped.attackTargets(staff,damage:true)))
        assert(grouped.actionHistory(SheetActionRef(kind:.attack,sourceID:staff.id))?.count == 1)
        grouped.conditions = ["Stunned"]
        let stunned = grouped
        do { _ = try grouped.performAction(damageRef); fatalError("Incapacitated attack damage allowed") } catch {}
        assert(grouped == stunned)
        grouped.conditions = []; grouped.items = [Item(name:"Staff",equipped:false)]
        grouped.attacks[0].equipmentID = grouped.items[0].id
        do { _ = try grouped.performAction(damageRef); fatalError("Stowed damage allowed") } catch {}
        assert(!grouped.sheetActions.contains { $0.ref.sourceID == staff.id })
        let groupedRoundtrip = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(grouped))
        assert(groupedRoundtrip == grouped && groupedRoundtrip.spells[0].rolls?.count == 7)
        let modern = CompendiumEntry(category:.spell,name:"Sample [2024]",fields:[])
        let ua = CompendiumEntry(category:.spell,name:"Sample (UA)",fields:[])
        let hb = CompendiumEntry(category:.spell,name:"Sample",fields:[ReferenceField(name:"source",text:"Homebrew")])
        let custom = CompendiumEntry(category:.spell,name:"Mine",fields:[],custom:true)
        let unknown = CompendiumEntry(category:.spell,name:"Unmarked",fields:[ReferenceField(name:"text",text:"This text mentions 2024 without identifying a source.")])
        assert(modern.sourceMark == .revised && ua.sourceMark == .ua && hb.sourceMark == .homebrew && unknown.sourceMark == .unmarked)
        assert(CompendiumScope.curated.includes(modern) && CompendiumScope.curated.includes(custom))
        assert(!CompendiumScope.curated.includes(ua) && CompendiumScope.curated.includes(ua,ua:true))
        assert(!CompendiumScope.curated.includes(hb) && CompendiumScope.curated.includes(hb,homebrew:true))
        assert(CompendiumScope.all.includes(unknown))
        let mixedClass = CompendiumEntry(category:.classEntry,name:"Wizard [2024]",fields:[ReferenceField(name:"autolevel",children:[ReferenceField(name:"text",text:"Source: Unearthed Arcana")])])
        let unmarkedClass = CompendiumEntry(category:.classEntry,name:"Wizard",fields:[ReferenceField(name:"autolevel",children:[ReferenceField(name:"text",text:"Source: Player's Handbook (2024)")])])
        assert(mixedClass.sourceMark == .revised && CompendiumScope.curated.includes(mixedClass))
        assert(unmarkedClass.sourceMark == .unmarked)
        // Inactive creatures preserve their entire record; legacy saves stay active.
        var summon = Creature(name:"Tirpik",kind:"Summon",hp:7,maximumHP:12,description:"Keep this note")
        let originalSummon = summon
        assert(summon.isActive)
        summon.isActive = false
        let asleep = try JSONDecoder().decode(Creature.self,from:JSONEncoder().encode(summon))
        assert(!asleep.isActive && asleep.hp == 7 && asleep.description == "Keep this note")
        summon.isActive = true
        assert(summon == originalSummon)
        var legacy = try JSONSerialization.jsonObject(with:JSONEncoder().encode(summon)) as! [String:Any]
        legacy.removeValue(forKey:"active")
        let legacyCreature = try JSONDecoder().decode(Creature.self,from:JSONSerialization.data(withJSONObject:legacy)); assert(legacyCreature.isActive)
        summon.isActive = false
        assert(TemplateFactory.creature(summon).template?.creature?.active == nil)
        assert(TemplateFactory.creature(summon).template?.creature?.hp == 12)
        // Critical damage doubles signed dice, including rider dice, but not flat bonuses.
        let signedCritical = try Dice.criticalExpression("1d6 + 3 + 1d4 - 1d8 - 2"); assert(signedCritical == "2d6+3+2d4-2d8-2")
        let flatCritical = try Dice.criticalExpression("5"); assert(flatCritical == "5")
        let bigCritical = try Dice.roll(Dice.criticalExpression("100d6-100d4+5"))
        assert(bigCritical.dice.count == 400 && bigCritical.dice.filter { $0 < 0 }.count == 200)
        do { _ = try Dice.criticalExpression("1d6oops"); fatalError("Invalid critical expression accepted") } catch {}
        var criticalHero = Hero.sample; criticalHero.conditions = []; criticalHero.exhaustionLevel = 0
        criticalHero.attacks = [Attack(name:"Test staff",damage:"1d6")]
        let critRef = SheetActionRef(kind:.attackDamage,sourceID:criticalHero.attacks[0].id)
        let crit = try criticalHero.performAction(critRef,critical:true)
        assert(crit.dice.count == 2 && crit.label.contains("critical damage"))
        assert(criticalHero.actionHistory(critRef)?.count == 1)
        // Cost preview is read-only and includes the automatic roll’s resource cost.
        var costHero = Hero.sample
        let previewPool = ResourceCounter(name:"Focus",current:3,maximum:4)
        costHero.counters = [previewPool]
        let previewCost = ResourceCost(resource:ResourceRef(kind:.counter,id:previewPool.id))
        let previewRoll = NamedRoll(name:"Damage",expression:"1d6",resourceCost:previewCost)
        var costSpell = Spell(name:"Cost spell",level:1,rolls:[previewRoll],automaticRollID:previewRoll.id)
        costSpell.resourceCost = previewCost
        costHero.spells = [costSpell]; costHero.slots = [2,0,0,0,0,0,0,0,0]; costHero.usedSlots = Array(repeating:0,count:9)
        let beforeCostPreview = costHero
        let costText = costHero.actionCostDetails(SheetActionRef(kind:.spell,sourceID:costSpell.id))
        assert(costText.contains("1 level 1 slot") && costText.contains("2 Focus · 3/4"))
        assert(costHero == beforeCostPreview)
        assert(ActionTiming.castingTime("1 reaction, when an enemy takes a bonus action") == .reaction)
        assert(ActionTiming.castingTime("1 bonus action") == .bonusAction)
        assert(ActionTiming.castingTime("Action") == .action)
        assert(ActionTiming.castingTime("1 minute") == .other)
        var timedHero = Hero.sample
        let reaction = Spell(name:"Shield",level:1,time:"1 reaction, when hit")
        timedHero.spells = [reaction]
        assert(timedHero.actionTiming(SheetActionRef(kind:.spell,sourceID:reaction.id)) == .reaction)
        timedHero.attacks = [Attack(name:"Staff",timing:.bonusAction)]
        assert(timedHero.actionTiming(SheetActionRef(kind:.attackDamage,sourceID:timedHero.attacks[0].id)) == .bonusAction)
        timedHero.creatures = [originalSummon]
        timedHero.setCreatureActive(originalSummon.id,false)
        assert(timedHero.creatures?.first?.isActive == false)
        timedHero.setCreatureActive(originalSummon.id,true)
        assert(timedHero.creatures?.first == originalSummon)
        let timedCopy = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(timedHero)); assert(timedCopy == timedHero)
        var dying = Hero.sample; dying.hp = 0; dying.resetDeathSaves()
        try dying.applyDeathSave(natural:10,total:10); assert(dying.deathSuccesses == 1)
        try dying.applyDeathSave(natural:1,total:99); assert(dying.deathFailures == 2)
        try dying.applyDeathSave(natural:20,total:1); assert(dying.hp == 1 && dying.deathFailures == 0 && dying.deathSuccesses == 0)
        do { _ = try dying.rollDeathSave(); fatalError("Death save allowed at positive HP") } catch {}
        dying.hp = 0; dying.deathSuccesses = 2
        try dying.applyDeathSave(natural:12,total:12); assert(!dying.needsDeathSave && dying.deathSaveStatus == "Stable")
        let stableCopy = dying
        do { try dying.applyDeathSave(natural:2,total:2); fatalError("Stable character rolled") } catch {}
        assert(dying == stableCopy)
        dying.hp = 5; assert(dying.deathSuccesses == 0 && dying.deathFailures == 0)
        dying.hp = 0; dying.deathFailures = 2
        try dying.applyDeathSave(natural:2,total:2); assert(dying.deathFailures == 3 && !dying.needsDeathSave)
        let deadCopy = dying
        do { try dying.applyDeathSave(natural:0,total:0); fatalError("Invalid natural accepted") } catch {}
        assert(dying == deadCopy)
        print("PASS: atomic linked costs, shared feature counters, independent rests, action history/favorites, concentration replacement/end, reusable templates, round trips, and non-destructive source views")
    }
}
