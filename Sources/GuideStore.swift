import SwiftUI

struct CharacterGuideSession:Identifiable {
    var id = UUID()
    var original:Hero?
}
extension Store {
    func upsertTemplate(_ entry:CompendiumEntry) {
        let old = compendium; let oldLibrary = library
        var incoming = entry; incoming.custom = true
        if let i = compendium.firstIndex(where:{ $0.id == incoming.id && $0.custom == true }) { compendium[i] = incoming }
        else { guard !compendium.contains(where:{ $0.name == incoming.name && $0.category == incoming.category && $0.identityKey == incoming.identityKey }) else { return }; compendium.append(incoming) }
        if let spell = incoming.spell() {
            if let i = library.firstIndex(where:{ $0.id == incoming.id }) { library[i] = spell } else { library.append(spell) }
        }
        do { try saveCompendium(); save(); compendiumRevision += 1 }
        catch { compendium = old; library = oldLibrary; self.error = "Could not save the compendium copy: \(error.localizedDescription)" }
    }
    func beginLevelUp(_ hero:Hero) {
        guard hero.level < 20, characterGuide == nil else { return }
        characterGuide = CharacterGuideSession(original:hero)
    }
    func commitGuide(_ draft:CharacterBuildDraft) throws {
        guard !characterArchiveReadFailed else { throw GuideError.invalid("The saved character file needs recovery before creating or updating characters.") }
        let hero = try draft.finalized()
        var next = heroes
        if let original = draft.original {
            guard let i = next.firstIndex(where:{ $0.id == original.id }),next[i] == original else { throw GuideError.changed }
            next[i] = hero
        } else { next.append(hero) }
        let archive = Archive(heroes:next,library:bundledSRD.userSpells(library)); try validate(archive)
        flushPendingWrites()
        if draft.isLevelUp && FileManager.default.fileExists(atPath:file.path) {
            try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
            try Data(contentsOf:file).write(to:file.deletingLastPathComponent().appendingPathComponent("before-level-up-\(UUID().uuidString).json"),options:.atomic)
        }
        saveTaskCancellationForGuide()
        try writer.writeAndWait(archive,to:file); lastSavedArchive = archive
        heroes = next; selected = hero.id; showCompendium = false; characterGuide = nil
    }
}
