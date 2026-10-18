import Foundation

@main struct CreatureTransferTests {
    static func main() throws {
        var hero = Hero.sample
        hero.attacks = []; hero.spells = []; hero.items = []; hero.featureEntries = []
        let reaction = CreatureAttack(name:"Parry strike",bonus:5,damage:"1d6+2",timing:.reaction)
        let cone = CreatureAttack(name:"Breath",damage:"3d6",timing:.bonusAction,resolution:.damage)
        let trait = CharacterFeature(name:"Ward",counter:ResourceCounter(name:"Ward",current:2,maximum:2),timing:.reaction)
        let creature = Creature(name:"Wolf",hp:10,maximumHP:10,attacks:[reaction,cone],traits:[trait])
        hero.creatures = [creature]
        assert(hero.creatureActions.count == 3 && hero.sheetActions.count == 3)
        let ref = hero.creatureActions.first { $0.name == reaction.name }!.ref
        assert(hero.actionTiming(ref) == .reaction && hero.creatureActions[0].subtitle.contains("Wolf"))
        hero.conditions = ["Unconscious"]; hero.hp = 0 // Companion is its own actor.
        let attackRoll = try hero.performAction(ref)
        assert(attackRoll.expression == "1d20+5")
        let damageRef = SheetActionRef(kind:.creatureDamage,sourceID:reaction.id,creatureID:creature.id)
        let damage = try hero.performAction(damageRef,critical:true)
        assert(damage.expression == "2d6+2" && hero.actionHistory(ref)?.count == 2)
        let coneRef = SheetActionRef(kind:.creatureDamage,sourceID:cone.id,creatureID:creature.id)
        do { _ = try hero.performAction(coneRef,critical:true); fatalError("Save damage critically hit") } catch {}
        let featureRef = SheetActionRef(kind:.creatureFeature,sourceID:trait.id,creatureID:creature.id)
        var ledger = ActivityLedger(); let before = hero; let snapshot = CharacterPlayState(hero)
        _ = try hero.performAction(featureRef)
        ledger.record(before:snapshot,hero:hero)
        assert(hero.creatures![0].traits![0].counter!.current == 1)
        hero = try ledger.undo(hero); assert(hero == before)
        hero.setCreatureActive(creature.id,false)
        assert(hero.creatureActions.isEmpty)
        let inactive = hero
        do { _ = try hero.performAction(ref); fatalError("Inactive creature acted") } catch {}
        assert(hero == inactive)
        hero.setCreatureActive(creature.id,true); hero.creatures![0].hp = 0
        do { _ = try hero.performAction(ref); fatalError("Zero HP creature acted") } catch {}
        // Duplicate template child IDs stay distinct through their owning creature ID.
        var twin = creature; twin.id = UUID(); twin.name = "Second wolf"
        hero.creatures = [creature,twin]
        let refs = hero.creatureActions.map(\.ref)
        assert(Set(refs).count == refs.count && Set(refs.map(\.id)).count == refs.count)
        let decoded = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(hero)); assert(decoded == hero)
        let reactionEntry = CompendiumEntry(category:.monster,name:"Guard",fields:[ReferenceField(name:"reaction",children:[ReferenceField(name:"name",text:"Retaliate"),ReferenceField(name:"text",text:"When hit, react.")])])
        assert(reactionEntry.creature().traits?.first?.timing == .reaction)
        let reactionAttackEntry = CompendiumEntry(category:.monster,name:"Guard",fields:[ReferenceField(name:"reaction",children:[ReferenceField(name:"name",text:"Riposte"),ReferenceField(name:"attack",text:"Riposte|4|1d6+2")])])
        assert(reactionAttackEntry.creature().attacks.first?.timing == .reaction)
        // Batch transfer creates independent copies and never touches the source character/library.
        let source = Hero.sample
        let sourceBefore = source
        var target = Hero.sample; target.id = UUID(); target.name = "Destination"; target.spells = []; target.items = []; target.creatures = []; target.featureEntries = []
        let spell = Spell(name:"Custom spark",level:0,text:"Original text")
        let item = TemplateFactory.item(Item(name:"Travel kit",notes:"Keep me"))
        let feature = TemplateFactory.feature(CharacterFeature(name:"Custom feat",text:"Grant description"))
        let monster = TemplateFactory.creature(creature)
        let picks = [CompendiumPick(spell:spell),CompendiumPick(item),CompendiumPick(feature),CompendiumPick(monster)]
        let (added,summary) = try CompendiumTransfer.applying(picks,to:target,through:2)
        assert(summary.total == 4 && summary.spells == 1 && summary.items == 1 && summary.creatures == 1 && summary.features == 1)
        assert(added.id == target.id && added.spells[0].id != spell.id && added.items[0].notes == "Keep me")
        assert(target.spells.isEmpty && source == sourceBefore)
        let (repeated,duplicates) = try CompendiumTransfer.applying([picks[0],picks[2]],to:added,through:2)
        assert(duplicates.skipped == 2 && repeated == added)
        let missing = CompendiumEntry(category:.spell,name:"Missing level",fields:[])
        let (review,report) = try CompendiumTransfer.applying([CompendiumPick(missing)],to:target,through:1)
        assert(report.needsReview == 1 && review == target)
        let saved = target
        do { _ = try CompendiumTransfer.applying([],to:target,through:1); fatalError("Empty batch accepted") } catch {}
        assert(target == saved)
        let roundtrip = try JSONDecoder().decode(Hero.self,from:JSONEncoder().encode(added)); assert(roundtrip == added)
        assert(spell.name == "Custom spark" && item.template?.item?.notes == "Keep me")
        print("PASS: active creature actions/timing/ownership, independent attack modifiers, save damage, counter undo, inactive/zero HP guards, distinct duplicate templates, batch destination isolation, copies, duplicates, missing-level review, and persistence")
    }
}
