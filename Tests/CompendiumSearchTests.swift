import Foundation

@main struct CompendiumSearchTests {
    static func main() throws {
        let entry=CompendiumEntry(category:.spell,name:"Café Shield",fields:[
            ReferenceField(name:"level",text:"1"),ReferenceField(name:"school",text:"AB"),
            ReferenceField(name:"classes",text:"Wizard, Sorcerer, "),ReferenceField(name:"source",text:"Player’s Handbook 2024"),
            ReferenceField(name:"text",text:"Ancient ravens protect the target.")])
        assert(CompendiumSearch.matches(entry,query:"  "))
        assert(CompendiumSearch.matches(entry,query:"CAFE wizard"))
        assert(CompendiumSearch.matches(entry,query:"wizard cafe"))
        assert(CompendiumSearch.matches(entry,query:"shield 2024"))
        assert(!CompendiumSearch.matches(entry,query:"shield cleric"))
        assert(!CompendiumSearch.matches(entry,query:"ravens"))
        assert(CompendiumSearch.matches(entry,query:"ravens",includeDescription:true))
        assert(CompendiumSearch.classNames(entry) == ["Wizard","Sorcerer"])
        let exact=CompendiumEntry(category:.spell,name:"Shield",fields:[])
        let prefix=CompendiumEntry(category:.spell,name:"Shield wall",fields:[])
        assert(CompendiumSearch.precedes(exact,prefix,query:"shield"))
        assert(!CompendiumSearch.precedes(prefix,exact,query:"shield"))
        assert(CompendiumSearch.precedes(prefix,entry,query:"shield"))
        assert(CompendiumSearch.precedes(entry,exact,query:""))
        var custom=entry;custom.template=CompendiumTemplate(spell:Spell(name:"Café Shield",level:1,classes:"Bard"))
        assert(CompendiumSearch.classNames(custom) == ["Bard"])
        let encoded=try JSONEncoder().encode(entry)
        _=CompendiumSearch.matches(entry,query:"ravens bard",includeDescription:true)
        let decoded=try JSONDecoder().decode(CompendiumEntry.self,from:encoded)
        assert(decoded.name == entry.name && decoded.value("text") == entry.value("text"))
        print("PASS: compendium search terms, accents/case, metadata, opt-in descriptions, class lists, ranking, and reference preservation")
    }
}
