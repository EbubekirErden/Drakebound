import Foundation

struct QuickNoteDraft: Equatable {
    var text = ""
    var tags = ""
    var canSave:Bool { !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }
    func entry() -> JournalEntry? {
        guard canSave else { return nil }
        let title = text.components(separatedBy:.newlines).first { !$0.trimmingCharacters(in:.whitespaces).isEmpty }?.trimmingCharacters(in:.whitespaces) ?? "Untitled note"
        return JournalEntry(title:title,description:text,tags:JournalEntry.parseTags(tags))
    }
}

extension Hero {
    @discardableResult mutating func addQuickNote(_ draft:QuickNoteDraft) -> UUID? {
        guard let entry=draft.entry() else { return nil }
        // Preserve legacy journal text even when quick capture precedes opening Journal.
        let existing = journalEntries ?? (notes.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? [] : [JournalEntry(title:"Earlier notes",description:notes)])
        journalEntries = [entry] + existing
        return entry.id
    }
}
