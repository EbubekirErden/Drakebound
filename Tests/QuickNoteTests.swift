import Foundation

@main struct QuickNoteTests {
    static func main() throws {
        assert(!QuickNoteDraft(text:" \n\t").canSave)
        assert(QuickNoteDraft(text:" \n").entry() == nil)
        let draft=QuickNoteDraft(text:"\n  Moon gate  \nAsk the keeper about the key.\n",tags:"Quest, #NPC, quest")
        let entry=draft.entry()!
        assert(entry.title == "Moon gate" && entry.description == draft.text)
        assert(entry.tags == ["Quest","NPC"] && entry.richText == nil)
        var hero=Hero();hero.name="Keeper";hero.journalEntries=[JournalEntry(title:"Pinned",description:"Existing",pinned:true,tags:["Lore"])]
        let original=hero,existing=hero.journalEntries!
        assert(hero.addQuickNote(QuickNoteDraft(text:" ")) == nil && hero == original)
        let id=hero.addQuickNote(draft)!
        assert(hero.journalEntries!.first!.id == id && Array(hero.journalEntries!.dropFirst()) == existing)
        var expected=original;expected.journalEntries=hero.journalEntries;assert(hero == expected)
        assert(hero.orderedJournalEntries.first!.title == "Pinned")
        var legacy=Hero();legacy.journalEntries=nil;legacy.notes="A legacy story"
        legacy.addQuickNote(draft);assert(legacy.journalEntries!.last!.description == "A legacy story")
        let archive=Archive(heroes:[hero,original],library:[])
        let restored=try JSONDecoder().decode(Archive.self,from:JSONEncoder().encode(archive))
        assert(restored.heroes == archive.heroes)
        print("Quick notes: blank rejection, title/body/tags, pinned and legacy note preservation, unchanged character fields and archive round trip passed.")
    }
}
