import Foundation

@main struct JournalTagTests {
    static func main() throws {
        let id=UUID()
        let legacy=try JSONSerialization.data(withJSONObject:["id":id.uuidString,"title":"Old note","description":"A preserved story"])
        var note=try JSONDecoder().decode(JournalEntry.self,from:legacy)
        assert(note.tags == nil && note.normalizedTags.isEmpty)
        note.tags=JournalEntry.parseTags(" NPC, #Quest, npc, , Café, CAFE, Location ")
        assert(note.tags == ["NPC","Quest","Café","Location"])
        assert(note.matchesJournalSearch("quest"))
        assert(note.matchesJournalSearch("preserved",tag:"npc"))
        assert(!note.matchesJournalSearch("story",tag:"Session"))
        assert(!note.matchesJournalSearch("absent",tag:"NPC"))
        note.pinned=true;note.image=Data([1,2,3]);note.richText=Data([4,5,6])
        let roundTrip=try JSONDecoder().decode(JournalEntry.self,from:JSONEncoder().encode(note))
        assert(roundTrip == note && roundTrip.id == id)
        assert(JournalEntry.parseTags(" , #, , ").isEmpty)
        print("Journal tags: legacy decode, normalization, filtering and full note archive round trip passed.")
    }
}
