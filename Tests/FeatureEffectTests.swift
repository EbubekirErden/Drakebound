import Foundation
@main struct FeatureEffectTests {
    static func main() throws {
        let text="Your Hit Point maximum increases by an amount equal to twice your character level when you gain this feat. When you gain a character level thereafter, your Hit Point maximum increases by an additional 2 Hit Points."
        let tough=CharacterFeature(name:"Origin: Tough [2024]",text:text,category:.feat,source:"Compendium")
        var h=Hero();h.level=5;h.maxHP=43;h.hp=43;h.featureEntries=[]
        h.replaceFeatures([tough]);assert(h.maximumHP == 53 && h.hp == 53 && h.maxHP == 43)
        h.level=6;assert(h.maximumHP == 55)
        h.hp=30;h.replaceFeatures([]);assert(h.maximumHP == 43 && h.hp == 30)
        h.replaceFeatures([tough]);assert(h.maximumHP == 55 && h.hp == 30)
        var duplicate=tough;duplicate.id=UUID();h.replaceFeatures([tough,duplicate]);assert(h.maximumHP == 55)
        var reference=tough;reference.effectMode = .referenceOnly;h.replaceFeatures([reference]);assert(h.maximumHP == 43)
        var custom=tough;custom.effectMode = .manual;custom.effects=[FeatureEffect(target:"maxHP",amount:3,perLevel:1)]
        h.replaceFeatures([custom]);assert(h.maximumHP == 52 && h.hp == 30)
        let archive=Archive(heroes:[h],library:[]);try validate(archive)
        let restored=try JSONDecoder().decode(Archive.self,from:JSONEncoder().encode(archive));assert(restored.heroes[0] == h)
        custom.effects?[0].target="not-a-stat";assert(!validFeatureEffects(custom))
        var old=Hero();old.level=5;old.maxHP=43;old.hp=43;old.featureEntries=[tough]
        old.migrateRecognizedFeatureEffects();assert(old.hp == 53 && old.maximumHP == 53)
        let once=old;old.migrateRecognizedFeatureEffects();assert(old == once)
        old.hp=0;old.featureEntries=[tough];old.migrateRecognizedFeatureEffects();assert(old.hp == 0)
        old.hp=30;old.featureEntries=[tough];old.migrateRecognizedFeatureEffects();assert(old.hp == 30)
        var imported=tough;imported.source="Feat";old.featureEntries=[imported];assert(old.maximumHP == 43)
        imported.effectMode = .automatic;old.featureEntries=[imported];assert(old.maximumHP == 53)
        old.featureEntries=[tough];old.bonuses=[Bonus(name:"Tough",target:"maxHP",amount:10)];assert(old.maximumHP == 53)
        var unrelated=tough;unrelated.text="Unrelated homebrew rule";assert(unrelated.recognizedEffects.isEmpty)
        unrelated=tough;unrelated.name="Toughened magic";assert(unrelated.recognizedEffects.isEmpty)
        var d=CharacterBuildDraft();d.originBonusMethod = .custom;d.selectedFeatures=[tough];assert(d.result.maximumHP == d.result.maxHP+2*d.newLevel)
        let entry=CompendiumEntry(category:.feat,name:tough.name,fields:[ReferenceField(name:"text",text:text)])
        var target=Hero();target.level=5;target.hp=target.maxHP
        let result=try CompendiumTransfer.applying([CompendiumPick(entry)],to:target,through:5)
        assert(result.0.maximumHP == target.maximumHP+10 && result.0.hp == result.0.maximumHP)
        var boundaryHero=Hero();boundaryHero.featureEntries=[tough]
        let originalBoundary=CharacterPlayState(boundaryHero).boundary
        boundaryHero.featureEntries?[0].effectMode = .referenceOnly
        assert(CharacterPlayState(boundaryHero).boundary != originalBoundary)
        let template=TemplateFactory.feature(custom);let a=template.featureCopies()[0],b=template.featureCopies()[0]
        assert(a.effects?.first?.id != b.effects?.first?.id)
        print("PASS: Tough scales with total level, duplicate rules do not stack, full/wounded/zero HP behavior, removal, reference/custom overrides, safe imported/manual handling, idempotent migration, creation, compendium transfer, validation and persistence")
    }
}
