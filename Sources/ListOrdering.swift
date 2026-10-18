import Foundation

struct ListReorderToken:Codable,Equatable {
    enum Kind:String,Codable { case journal,equipment }
    var kind:Kind
    var heroID:UUID
    var entryID:UUID
    var containerID:UUID? = nil
}
extension Hero {
    var orderedJournalEntries:[JournalEntry] {
        let entries=journalEntries ?? []
        return entries.filter { $0.pinned == true }+entries.filter { $0.pinned != true }
    }
    @discardableResult mutating func toggleJournalPin(_ id:UUID)->Bool {
        guard let index=journalEntries?.firstIndex(where:{ $0.id == id }) else { return false }
        let pinned=journalEntries?[index].pinned == true
        journalEntries?[index].pinned = !pinned
        return true
    }
    @discardableResult mutating func reorderJournal(_ token:ListReorderToken,onto target:UUID,visibleIDs:[UUID])->Bool {
        guard token.kind == .journal,token.heroID == id,token.containerID == nil,
              let source=journalEntries?.first(where:{ $0.id == token.entryID }),
              let destination=journalEntries?.first(where:{ $0.id == target }),
              (source.pinned == true) == (destination.pinned == true) else { return false }
        var entries=journalEntries ?? []
        let allowed=Set(visibleIDs)
        let indices=entries.indices.filter { allowed.contains(entries[$0].id) && (entries[$0].pinned == true) == (source.pinned == true) }
        guard reorderSlots(&entries,indices:indices,source:token.entryID,target:target) else { return false }
        journalEntries=entries;return true
    }
    @discardableResult mutating func reorderEquipment(_ token:ListReorderToken,onto target:UUID,visibleIDs:[UUID])->Bool {
        guard token.kind == .equipment,token.heroID == id,
              let source=items.first(where:{ $0.id == token.entryID }),
              let destination=items.first(where:{ $0.id == target }),
              source.containerID == token.containerID,source.containerID == destination.containerID else { return false }
        let allowed=Set(visibleIDs)
        let indices=items.indices.filter { allowed.contains(items[$0].id) && items[$0].containerID == source.containerID }
        return reorderSlots(&items,indices:indices,source:token.entryID,target:target)
    }
}
// Replace only the visible slots in this group; hidden and unrelated entries retain their positions.
private func reorderSlots<T:Identifiable>(_ entries:inout [T],indices:[Int],source:UUID,target:UUID)->Bool where T.ID == UUID {
    var group=indices.map { entries[$0] }
    guard source != target,let from=group.firstIndex(where:{ $0.id == source }),let to=group.firstIndex(where:{ $0.id == target }) else { return false }
    group.insert(group.remove(at:from),at:to)
    for (slot,entry) in zip(indices,group) { entries[slot]=entry }
    return true
}
