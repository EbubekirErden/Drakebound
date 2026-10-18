import Foundation

@main struct GuideLoadoutSummaryTests {
    static func main() throws {
        let wizard=CharacterClassLevel(name:"Wizard",level:3,hitDie:6)
        let cleric=CharacterClassLevel(name:"Cleric",level:2,hitDie:8)
        let explicit=Spell(name:"Explicit assignment",level:1,sourceClassID:cleric.id,sourceClassName:"Wizard")
        let named=Spell(name:"Legacy class name",level:1,sourceClassName:"Wizard [2024]")
        let unassigned=Spell(name:"Unassigned",level:0)
        let unknown=Spell(name:"Unknown class",level:1,sourceClassID:UUID())
        let extra=Spell(name:"Extra spell",level:1,sourceClassID:wizard.id,exemptFromClassLimit:true)
        let spells=[explicit,named,unassigned,unknown,extra]
        let before=try JSONEncoder().encode(spells)
        let classes=[wizard,cleric]
        assert(GuideLoadoutSummary.spells(spells,for:wizard,classes:classes).map(\.id) == [named.id,extra.id])
        assert(GuideLoadoutSummary.spells(spells,for:cleric,classes:classes).map(\.id) == [explicit.id])
        assert(GuideLoadoutSummary.unassignedSpells(spells,classes:classes) == 2)
        assert(GuideLoadoutSummary.spells([unassigned],for:wizard,classes:[wizard]).count == 1)
        assert(GuideLoadoutSummary.spells([unknown],for:wizard,classes:[wizard]).isEmpty)
        let decoded=try JSONDecoder().decode([Spell].self,from:before)
        assert(decoded == spells)
        let items=[Item(name:"Arrows",quantity:20,weight:0.05),Item(name:"Empty pouch",quantity:1,weight:0),Item(name:"Potions",quantity:2,weight:0.5)]
        assert(GuideLoadoutSummary.quantity(items) == 23)
        assert(abs(GuideLoadoutSummary.weight(items)-2) < 0.0001)
        assert(GuideLoadoutSummary.quantity([]) == 0 && GuideLoadoutSummary.weight([]) == 0)
        print("PASS: class IDs take priority, legacy names, multiclass unassigned spells, extra spell retention, quantity-weight totals, unchanged selections")
    }
}
