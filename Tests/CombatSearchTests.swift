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
