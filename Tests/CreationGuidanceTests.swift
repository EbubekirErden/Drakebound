import Foundation
@main struct CreationGuidanceTests {
    static func main() throws {
        var d=CharacterBuildDraft();d.originBonusMethod = .custom;d.startingLevel=5
        let asi=CharacterFeature(name:"Level 4: Ability Score Improvement",category:.classFeature,source:"Cleric · Level 4")
        d.selectedFeatures=[asi];assert(!d.improvementProblems.isEmpty)
        try d.configureImprovement(asi,choice:AbilityImprovementChoice(increases:[0,0,0,0,2,0]))
        assert(d.result.scores[4] == d.generatedScores[4]+2 && d.improvementProblems.isEmpty)
        d.selectedFeatures=[];assert(d.result.scores[4] == d.generatedScores[4])
        d.selectedFeatures=[asi];let feat=CharacterFeature(name:"Selected feat",category:.feat)
        try d.configureImprovement(asi,choice:AbilityImprovementChoice(increases:[0,0,0,0,1,0],feat:feat));assert(d.result.featureEntries!.contains { $0.name == feat.name })
        d.abilityMethod = .manual;d.manualScores=Array(repeating:20,count:6);assert(d.improvementProblem(AbilityImprovementChoice(increases:[2,0,0,0,0,0]),for:asi.id) != nil)
        let protector=CharacterFeature(name:"Protector",text:"Trained for battle, you gain proficiency with Martial weapons and training with Heavy armor.")
        var hero=Hero.sample;hero.featureEntries=[protector];hero.trainingGrants=[TrainingGrant(target:"weapon.simple",source:"Class")]
        assert(Set(hero.equipmentTrainingGrants.map(\.target)).isSuperset(of:["weapon.martial","armor.heavy","weapon.simple"]))
        try validate(Archive(heroes:[hero],library:[]))
        hero.items=[Item(name:"Longsword",equipped:true)];hero.attacks=[Attack(name:"Longsword",equipmentID:hero.items[0].id)]
        let withTraining=hero.attackBonus(hero.attacks[0]);hero.featureEntries=[];assert(hero.attackBonus(hero.attacks[0]) == withTraining-hero.proficiency)
        let entry=CompendiumEntry(category:.classEntry,name:"Cleric [2024]",fields:[ReferenceField(name:"armor",text:"light armor, medium armor, shields"),ReferenceField(name:"weapons",text:"simple weapons")])
        assert(GuideRules.equipmentTraining(entry).count == 4)
        hero.rulesEdition="2024";let record=CharacterClassLevel(name:"Cleric",level:5,hitDie:8,casting:.full)
        let allowance=GuideRules.spellAllowance(record,entry:nil,hero:hero);assert(allowance.cantrips == 4 && allowance.prepared == 9 && allowance.maximumLevel == 3)
        hero.rulesEdition="2014";assert(GuideRules.spellAllowance(record,entry:nil,hero:hero).prepared == 5+hero.modifier(4))
        let guidance=CompendiumEntry(category:.spell,name:"Guidance [2024]",fields:[ReferenceField(name:"school",text:"D"),ReferenceField(name:"time",text:"Action"),ReferenceField(name:"range",text:"Touch"),ReferenceField(name:"classes",text:"School: Divination [2024], Cleric [2024], Druid [2024]")])
        let invocation=CompendiumEntry(category:.spell,name:"Invocation: Unknown",fields:guidance.fields)
        let catalog=GuideCatalog(compendium:[guidance,invocation],library:[])
        assert(catalog.spells.count == 1 && catalog.spells[0].level == 0 && catalog.unleveledSpells.count == 1)
        assert(GuideRules.spellBelongs(catalog.spells[0],to:"Cleric"))
        assert(!GuideRules.spellBelongs(Spell(name:"Domain only",level:1,classes:"Wizard, Cleric [2024] (Domain)"),to:"Cleric"))
        var packDraft=CharacterBuildDraft();let kits=catalog.startingKits(classEntry:nil,background:nil,edition:"2024");let priest=kits.first { $0.name.contains("Priest") }!
        packDraft.applyStarterKit(priest,catalog:catalog);let snapshot=packDraft.hero;packDraft.applyStarterKit(priest,catalog:catalog);assert(packDraft.hero == snapshot)
        assert(packDraft.hero.items.first { $0.name == "Rations" }?.quantity == 7 && packDraft.hero.inventoryContainers.count == 1)
        try validate(Archive(heroes:[packDraft.result],library:[]))
        let optionA=StarterKit(id:"A",name:"Class A",source:"Class",items:[("Mace",1)],gold:7,groupID:"class")
        let optionB=StarterKit(id:"B",name:"Class B",source:"Class",items:[],gold:110,groupID:"class")
        var alternatives=CharacterBuildDraft();alternatives.applyStarterKit(optionA,catalog:catalog);alternatives.applyStarterKit(optionB,catalog:catalog);assert(alternatives.hero.gold == 7)
        var wealth=CharacterBuildDraft();wealth.applyStarterKit(optionB,catalog:catalog);assert(wealth.hero.gold == 110 && wealth.hero.inventoryContainers.isEmpty)
        if CommandLine.arguments.count > 1 {
            let imported=try CompendiumImport.read(Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
            let real=GuideCatalog(compendium:imported.entries,library:starterSpells)
            let cantrips=real.spells.filter { $0.level == 0 && GuideRules.spellBelongs($0,to:"Cleric") }
            assert(cantrips.contains { $0.name == "Guidance [2024]" } && cantrips.contains { $0.name == "Sacred Flame [2024]" } && cantrips.count > 1)
            let cleric=real.classes.first { $0.name == "Cleric [2024]" }!
            var revised=Hero();revised.rulesEdition="2024"
            assert(GuideRules.spellAllowance(record,entry:cleric,hero:revised).prepared == 9)
            let kit=real.startingKits(classEntry:cleric,background:nil,edition:"2024").first { $0.name.contains("Option A") }!
            var equipped=CharacterBuildDraft();equipped.applyStarterKit(kit,catalog:real)
            assert(equipped.hero.gold == 7 && equipped.hero.items.contains { $0.name.contains("Chain Shirt") } && equipped.hero.items.contains { $0.name.replacingOccurrences(of:" [2024]",with:"") == "Rations" && $0.quantity == 7 })
        }
        // Seed/library copies collapse only in the selection view; custom entries survive.
        var seed=Spell(name:"Guidance",level:0,classes:"Cleric")
        seed.text="Seed";var importedCopy=seed;importedCopy.id=UUID();importedCopy.text="Imported";importedCopy.classes="Druid"
        var custom=seed;custom.id=UUID();custom.text="My custom guidance"
        let importedEntry=CompendiumEntry(id:importedCopy.id,category:.spell,name:importedCopy.name,fields:[])
        let customEntry=CompendiumEntry(id:custom.id,category:.spell,name:custom.name,fields:[],custom:true)
        let before=[seed,importedCopy,custom]
        let visible=SelectionRules.browserSpells(before,entries:[importedEntry.id:importedEntry,customEntry.id:customEntry])
        assert(visible.count == 2 && visible[0].text == "Imported" && visible.contains { $0.id == custom.id })
        assert(visible[0].classes!.contains("Cleric") && visible[0].classes!.contains("Druid") && before.count == 3)
        var parent=CharacterFeature(name:"Channel Divinity",category:.classFeature)
        var child=CharacterFeature(name:"Turn Undead",category:.classFeature);child.parentFeatureID=parent.id
        var grandchild=CharacterFeature(name:"Child effect",category:.classFeature);grandchild.parentFeatureID=child.id
        let tree=[grandchild,child,parent]
        assert(SelectionRules.outline(tree).map(\.depth) == [0,1,2])
        assert(!SelectionRules.parentOptions(for:parent,in:tree).contains { $0.id == grandchild.id })
        assert(SelectionRules.outline([child]).first?.depth == 0)
        parent.parentFeatureID=grandchild.id
        assert(SelectionRules.outline([parent,child,grandchild]).count == 3)
        let linked=try JSONDecoder().decode(CharacterFeature.self,from:JSONEncoder().encode(child));assert(linked.parentFeatureID == parent.id)
        assert(TemplateFactory.feature(child).template?.feature?.parentFeatureID == nil)
        let data=try JSONEncoder().encode(hero);let restored=try JSONDecoder().decode(Hero.self,from:data);assert(restored == hero)
        print("PASS: guided ASI/feat changes and removal, score cap, equipment training sources and linked attack bonuses, Cleric allowances, recovered cantrips vs references, exact class lists, idempotent packs, containers, and JSON round trips")
    }
}
