import Foundation

@main struct ListOrderingTests {
    static func main() throws {
        var hero=Hero.sample
        let a=JournalEntry(title:"Pinned A",description:"Preserve text",image:Data([1,2]),richText:Data([3,4]),pinned:true)
        let b=JournalEntry(title:"Note B",description:"Unpinned")
        let c=JournalEntry(title:"Pinned C",pinned:true)
        let d=JournalEntry(title:"Note D")
        hero.journalEntries=[a,b,c,d]
        let noteIDs=[a.id,b.id,c.id,d.id]
        assert(hero.orderedJournalEntries.map(\.id) == [a.id,c.id,b.id,d.id])
        assert(hero.reorderJournal(ListReorderToken(kind:.journal,heroID:hero.id,entryID:a.id),onto:c.id,visibleIDs:noteIDs))
        assert(hero.orderedJournalEntries.map(\.id) == [c.id,a.id,b.id,d.id])
        assert(hero.journalEntries?[1] == b && hero.journalEntries?[3] == d)
        let before=hero
        assert(!hero.reorderJournal(ListReorderToken(kind:.journal,heroID:UUID(),entryID:a.id),onto:c.id,visibleIDs:noteIDs))
        assert(!hero.reorderJournal(ListReorderToken(kind:.equipment,heroID:hero.id,entryID:a.id),onto:c.id,visibleIDs:noteIDs))
        assert(!hero.reorderJournal(ListReorderToken(kind:.journal,heroID:hero.id,entryID:b.id),onto:c.id,visibleIDs:noteIDs))
        assert(!hero.reorderJournal(ListReorderToken(kind:.journal,heroID:hero.id,entryID:a.id),onto:c.id,visibleIDs:[c.id]))
        assert(hero == before)
        assert(hero.toggleJournalPin(b.id));assert(hero.journalEntries?.first { $0.id == b.id }?.pinned == true)
        assert(hero.orderedJournalEntries.map(\.id) == [c.id,b.id,a.id,d.id])
        assert(hero.toggleJournalPin(b.id));assert(hero.orderedJournalEntries.map(\.id) == [c.id,a.id,b.id,d.id])
        assert(hero.journalEntries?.first { $0.id == a.id } == a)
        let legacy=try JSONSerialization.data(withJSONObject:["id":UUID().uuidString,"title":"Legacy","description":"Still here"])
        let decoded=try JSONDecoder().decode(JournalEntry.self,from:legacy);assert(decoded.pinned == nil)
        let bag=EquipmentContainer(name:"Bag"),otherBag=EquipmentContainer(name:"Other")
        hero.equipmentContainers=[bag,otherBag]
        let first=Item(name:"First",quantity:3,weight:2,equipped:true,notes:"Preserve item",containerID:bag.id)
        let other=Item(name:"Other",containerID:otherBag.id)
        let hidden=Item(name:"Hidden",containerID:bag.id)
        let carried=Item(name:"Carried")
        let last=Item(name:"Last",quantity:2,weight:1,containerID:bag.id)
        hero.items=[first,other,hidden,carried,last]
        let allItems=hero.items,baseHP=hero.hp,baseSlots=hero.usedSlots,baseAttacks=hero.attacks,baseAC=hero.armorClass
        let token=ListReorderToken(kind:.equipment,heroID:hero.id,entryID:first.id,containerID:bag.id)
        assert(hero.reorderEquipment(token,onto:last.id,visibleIDs:[first.id,last.id]))
        assert(hero.items.map(\.id) == [last.id,other.id,hidden.id,carried.id,first.id])
        assert(Set(hero.items.map(\.id)) == Set(allItems.map(\.id)))
        for item in allItems { assert(hero.items.first { $0.id == item.id } == item) }
        let stable=hero
        assert(!hero.reorderEquipment(token,onto:other.id,visibleIDs:hero.items.map(\.id)))
        assert(!hero.reorderEquipment(ListReorderToken(kind:.equipment,heroID:hero.id,entryID:first.id),onto:last.id,visibleIDs:hero.items.map(\.id)))
        assert(!hero.reorderEquipment(ListReorderToken(kind:.equipment,heroID:UUID(),entryID:first.id,containerID:bag.id),onto:last.id,visibleIDs:hero.items.map(\.id)))
        assert(!hero.reorderEquipment(token,onto:UUID(),visibleIDs:hero.items.map(\.id)))
        assert(!hero.reorderEquipment(token,onto:first.id,visibleIDs:hero.items.map(\.id)))
        assert(hero == stable)
        var extra=Item(name:"Second carried");extra.containerID=nil;hero.items.append(extra)
        assert(hero.reorderEquipment(ListReorderToken(kind:.equipment,heroID:hero.id,entryID:carried.id),onto:extra.id,visibleIDs:hero.items.map(\.id)))
        assert(hero.items.last?.id == carried.id)
        assert(hero.hp == baseHP && hero.usedSlots == baseSlots && hero.attacks == baseAttacks && hero.armorClass == baseAC)
        try validateInventory(hero)
        let data=try JSONEncoder().encode(Archive(heroes:[hero],library:[]))
        let roundtrip=try JSONDecoder().decode(Archive.self,from:data)
        assert(roundtrip.heroes == [hero])
        let tokenData=try JSONEncoder().encode(token);let decodedToken=try JSONDecoder().decode(ListReorderToken.self,from:tokenData);assert(token == decodedToken)
        print("PASS: journal pins and stable groups, filtered slots, same-container and Carried ordering, rejected foreign/stale drops, unchanged contents/play state, legacy decoding and archive round trips")
    }
}
