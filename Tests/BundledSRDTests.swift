import Foundation

@main struct BundledSRDTests {
    static func main() throws {
        let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/SRD")
        let srd=try BundledSRD.load(directory:root),again=try BundledSRD.load(directory:root)
        precondition(srd.entries.count == 1675 && srd.spells.count == 339)
        precondition(srd.spells == again.spells,"Reference and roll IDs must remain stable between launches")
        func entry(_ name:String,_ category:CompendiumCategory) -> CompendiumEntry { srd.entries.first { $0.name == name+" [2024]" && $0.category == category }! }
        precondition(srd.entries.allSatisfy { $0.sourceMark == .revised && $0.sourceLabels.contains { $0.contains("CC BY 4.0") } })
        precondition(!srd.entries.contains { ["Beholder [2024]","Artificer [2024]","Aasimar [2024]"].contains($0.name) })
        precondition(!entry("Greater Invisibility",.spell).value("text").isEmpty)
        let bolt=entry("Fire Bolt",.spell).spell()!
        precondition(bolt.rolls?.map(\.expression) == ["1d10","2d10","3d10","4d10"] && bolt.rolls?.map(\.minimumCharacterLevel) == [1,5,11,17],"Cantrips retain character-level scaling")
        let fireball=entry("Fireball",.spell).spell()!
        precondition(fireball.rolls?.first?.slotLevel == 3 && fireball.rolls?.last?.expression == "14d6","Leveled spell rolls retain slot scaling")
        let wizard=entry("Wizard",.classEntry),fighter=entry("Fighter",.classEntry),bard=entry("Bard",.classEntry)
        precondition(fighter.value("proficiency").contains("Constitution Saving Throws") && !fighter.value("proficiency").contains("Dexterity Saving Throws"))
        precondition(bard.value("numSkills") == "3" && wizard.value("proficiency").contains("Insight"))
        precondition(GuideRules.importedCantrips(wizard,at:1) == 3 && GuideRules.importedSlots(wizard,at:3) == [4,2,0,0,0,0,0,0,0])
        precondition(GuideRules.subclasses(wizard).first?.name == "Evoker")
        precondition(GuideRules.isASI(wizard,className:"Wizard",level:8,edition:"2024"))
        precondition(GuideRules.featureChoices(wizard,from:1,through:1).contains { $0.name == "Spellcasting" })
        precondition(GuideRules.backgroundAbilities(entry("Acolyte",.background)) == [3,4,5])
        precondition(GuideRules.training(entry("Soldier",.background)).count == 2)
        precondition(entry("Longsword",.item).weaponProfile?.damage == "1d8")
        precondition(entry("Goblin Warrior",.monster).creature().maximumHP > 1)
        let catalog=GuideCatalog(compendium:srd.entries,library:[])
        precondition(catalog.spells.count == 339 && catalog.classes.count == 12 && catalog.backgrounds.count == 4 && catalog.ancestries.count == 9)
        precondition(catalog.classReference("Wizard",edition:"2024")?.id == wizard.id)
        precondition(catalog.classReference("Wizard",edition:"2014") == nil,"Never silently substitute 2024 rules into a 2014 class")
        var modified=wizard;modified.fields.append(ReferenceField(name:"text",text:"Preserve my reference changes"))
        let own=CompendiumEntry(category:.feat,name:"My custom feat",fields:[ReferenceField(name:"text",text:"Custom text")],custom:true)
        let merged=srd.merging(entries:[modified,own])
        precondition(merged.count == 1676 && merged.first == modified)
        precondition(srd.userEntries(merged) == [modified,own])
        precondition(srd.merging(entries:merged) == merged,"Loading or importing twice must not duplicate built-ins")
        var spell=srd.spells[0];spell.text="Preserve custom spell changes"
        let library=srd.merging(spells:[spell]);precondition(library.count == 339 && srd.userSpells(library) == [spell])
        let saved=try JSONEncoder().encode(srd.userEntries(merged))
        let reloaded=srd.merging(entries:try JSONDecoder().decode([CompendiumEntry].self,from:saved))
        precondition(reloaded == merged)
        let original=Hero.sample
        let archive=Archive(heroes:[original],library:srd.userSpells(library))
        try validate(archive)
        let roundtrip=try JSONDecoder().decode(Archive.self,from:JSONEncoder().encode(archive))
        precondition(roundtrip.heroes == [original] && srd.merging(spells:roundtrip.library) == library,"Bundled content must preserve existing character archives and edits")
        print("BundledSRDTests passed: offline categories, stable IDs, class progression, guide catalog, merge/save/reload preservation.")
    }
}
