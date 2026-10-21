import Foundation

@main struct CombatSearchTests {
    static func main() throws {
        var hero=Hero.sample
        hero.migrateContent()
        hero.name="Exported adventurer"
        hero.portrait=Data([1,2,3,4])
        var spell=Spell(name:"Éclair",level:3)
        spell.prepared=false;spell.text="Private spell text";hero.spells.append(spell)
        let feature=CharacterFeature(name:"Silent feature",text:"A passive feature without a counter")
        hero.featureEntries=(hero.featureEntries ?? [])+[feature]
        let reference=TemplateFactory.spell(spell)
        let extra=Spell(name:"Separate library spell",level:2)
        let before=hero
        let index=GlobalSearchIndex(hero:hero,library:[reference.spell()!,extra],compendium:[reference])
        let hits=index.search("eclair spell")
        precondition(hits.count == 2 && hits[0].character && !hits[1].character)
        precondition(hits[0].target == .spell(spell.id),"Unprepared character spells must be searchable")
        precondition(index.search("silent feature").first?.target == .feature(feature.id),"Passive features must be searchable")
        precondition(index.search("separate library").first?.target == .librarySpell(extra.id))
        precondition(index.search("  \n ").isEmpty && index.search("nothing matches").isEmpty)
        precondition(index.search("spell",limit:1).count == 1)
        precondition(index.entries.filter { $0.target == .librarySpell(reference.id) }.isEmpty,"Compendium-backed spells must not duplicate library references")
        precondition(hero == before,"Search construction and queries cannot mutate a character")
        let noCharacter=GlobalSearchIndex(hero:nil,library:[extra],compendium:[reference])
        precondition(noCharacter.search("eclair").first?.character == false)
        let troll=CompendiumEntry(id:UUID(),category:.monster,name:"Blinded Troll",fields:[])
        let rulesIndex=GlobalSearchIndex(hero:nil,library:[],compendium:[troll])
        let blinded=rulesIndex.search("blinded")
        precondition(blinded.first?.target == .condition("blinded"),"Exact condition must rank above a partial creature name")
        precondition(blinded.contains { $0.target == .reference(troll.id) })
        for condition in conditionReferences {
            precondition(rulesIndex.search(condition.name).contains { $0.target == .condition(condition.id) },"Every condition, including exhaustion, is searchable without a character")
        }
        precondition(rulesIndex.search("condition blinded").first?.target == .condition("blinded"))
        precondition(rulesIndex.search("sight checks").contains { $0.target == .condition("blinded") })
        var other=hero;other.id=UUID();other.name="Shennie"
        var pet=Creature();pet.name="Tirpik";pet.active=false
        other.creatures=[pet]
        let note=JournalEntry(title:"Earlier notes",description:"A hidden observatory",tags:["Session"])
        other.journalEntries=[note]
        let shared=GlobalSearchIndex(heroes:[hero,other],selectedID:hero.id,library:[],compendium:[reference])
        precondition(shared.search("shennie").contains { $0.target == .hero(other.id) && $0.heroID == other.id })
        precondition(shared.search("tirpik").first?.target == .creature(pet.id))
        precondition(shared.search("tirpik").first?.heroID == other.id)
        precondition(shared.search("earlier notes").contains { $0.target == .note(note.id) && $0.heroID == other.id })
        precondition(shared.search("hidden observatory").first?.heroID == other.id)
        precondition(shared.search("session note").contains { $0.target == .note(note.id) })
        let ownedSpells=shared.search("eclair").filter { $0.character }
        precondition(ownedSpells.count == 2 && Set(ownedSpells.map(\.id)).count == 2,"Copied content IDs must be scoped by owning character")
        precondition(ownedSpells[0].heroID == hero.id && ownedSpells[1].heroID == other.id)
        let data=try CharacterExport.data(for:hero)
        let archive=try JSONDecoder().decode(Archive.self,from:data)
        precondition(archive.heroes == [hero] && archive.library.isEmpty && archive.compendium == nil)
        precondition(archive.heroes[0].portrait == hero.portrait && archive.heroes[0].spells.last == spell)
        precondition(archive.heroes[0].featureEntries?.contains(feature) == true)
        let typedFeature=CharacterFeature(name:"Boundary test",text:"")
        hero.featureEntries=[typedFeature]
        let expected="effects:\(typedFeature.id):\(typedFeature.effectMode?.rawValue ?? "legacy"):\(typedFeature.resolvedEffects.map { "\($0.id):\($0.target):\($0.amount):\($0.perLevel):\($0.enabled)" }.joined(separator:";"))"
        precondition(CharacterPlayState(hero).boundary.contains(expected),"CI simplification must preserve serialized undo boundary signatures")
        print("PASS: cross-category search, character priority, unprepared spells, passive features, accent folding, blank/limited results, library deduplication, read-only queries, single-character image-inclusive export and undo signature compatibility")
    }
}
