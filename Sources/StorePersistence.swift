import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Saving, loading companions, imports, and backups for `Store`. Writes are ordered through `ArchiveWriter`.
extension Store {
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds:350_000_000) } catch { return }
            self?.save(background:true)
        }
    }
    func saveTaskCancellationForGuide() { saveTask?.cancel() }
    /// Waits for queued background writes so the file on disk is current before it is read or replaced.
    func flushPendingWrites() { writer.flush() }
    /// Saves characters. Background saves encode and write off the main thread; foreground saves (quit, import) finish before returning.
    /// Nothing is written when the characters and library are unchanged since the last successful save.
    func save(background:Bool = false) {
        guard !characterArchiveReadFailed else { return }
        do {
            for i in heroes.indices { heroes[i].synchronizeWeaponAttacks(compendium:compendium);heroes[i].reconcileConcentration() }
            captureActivity()
            let archive = Archive(heroes:heroes,library:bundledSRD.userSpells(library)); try validate(archive)
            if let last = lastSavedArchive,last.hasSameContent(as:archive),FileManager.default.fileExists(atPath:file.path) { return }
            if background {
                lastSavedArchive = archive
                writer.enqueue(archive,to:file) { [weak self] failure in
                    guard let failure else { return }
                    Task { @MainActor [weak self] in self?.lastSavedArchive = nil; self?.error = "Could not save: \(failure.localizedDescription)" }
                }
            } else {
                try writer.writeAndWait(archive,to:file); lastSavedArchive = archive
            }
        } catch { lastSavedArchive = nil; self.error = "Could not save: \(error.localizedDescription)" }
    }
    func importCompendium(_ data:Data) {
        guard !importingCompendium else { return }; importingCompendium = true
        Task { @MainActor in
            do {
                let result = try await Task.detached { try CompendiumImport.read(data) }.value
                let before = compendium.count; compendium = CompendiumImport.merged(compendium,result.entries)
                let existingIDs = Set(library.map(\.id))
                for entry in compendium where entry.category == .spell && !existingIDs.contains(entry.id) { if let spell = entry.spell() { library.append(spell) } }
                try saveCompendium(); save(); showCompendium = true
                notify("Imported \(compendium.count-before) compendium entries",detail:"\(Set(result.entries.map(\.category)).count) categories.\(result.repairedAmpersands > 0 ? " Repaired \(result.repairedAmpersands) unescaped ampersand during parsing; your original file is unchanged.":"") Exact duplicates are kept once; distinct versions with the same name are retained. Reference descriptions do not activate rules automatically.")
            } catch { self.error = "Compendium import failed.\n\(error.localizedDescription)" }
            importingCompendium = false
        }
    }
    /// Saves imported and custom compendium entries off the main thread, in order with character saves.
    /// Nothing is written when they are unchanged since the last successful save. A background failure is reported and retried by the next save.
    func saveCompendium() throws {
        let entries = bundledSRD.userEntries(compendium)
        let target = file.deletingLastPathComponent().appendingPathComponent("compendium.json")
        if let last = lastSavedCompendium,last == entries,FileManager.default.fileExists(atPath:target.path) { return }
        lastSavedCompendium = entries
        writer.enqueue(to:target,data:{ try JSONEncoder().encode(entries) }) { [weak self] failure in
            guard let failure else { return }
            Task { @MainActor [weak self] in self?.lastSavedCompendium = nil; self?.error = "Could not save the compendium. Your changes stay in the app and will be saved again on the next change.\n\(failure.localizedDescription)" }
        }
    }
    func exportBackup() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Drakebound-all-characters-and-references.json"
        panel.title="Back up all characters & references"
        panel.message="Includes every character and their images, shared spells and compendium references. Activity history and interface preferences are not included."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted]; try encoder.encode(Archive(heroes:heroes,library:library,compendium:compendium)).write(to:url,options:.atomic) }
        catch { self.error = error.localizedDescription }
    }
    func exportCharacter(_ id:UUID) {
        guard let hero=heroes.first(where:{ $0.id == id }) else { return }
        let name=hero.name.components(separatedBy:CharacterSet(charactersIn:"/:\n\r")).joined(separator:"-")
        let panel=NSSavePanel();panel.allowedContentTypes=[.json];panel.nameFieldStringValue=name+"-character.json"
        panel.title="Export \(hero.name)"
        panel.message="This character only, including images, spells, equipment, features, companions and journal. Shared reference libraries are excluded."
        guard panel.runModal() == .OK,let url=panel.url else { return }
        do { try CharacterExport.data(for:hero).write(to:url,options:.atomic) }
        catch { self.error="Character export failed.\n"+error.localizedDescription }
    }
    func importBackup() {
        guard !characterArchiveReadFailed else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json,.xml]; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try importBackupData(Data(contentsOf:url),fileExtension:url.pathExtension)
        } catch { self.error = "Import failed. Choose a Drakebound JSON backup, Fight Club character XML, or compendium XML.\n\(error.localizedDescription)" }
    }
    func importBackupData(_ data:Data,fileExtension:String) throws {
        guard !characterArchiveReadFailed else { throw CocoaError(.fileReadCorruptFile) }
        if fileExtension.lowercased() == "xml" {
            if String(data:data.prefix(4096),encoding:.utf8)?.contains("<compendium") == true { importCompendium(data); return }
            var imported = try FightClubImport.read(data)
            imported.heroes = try imported.heroes.map { original in
                var hero = original
                if let portrait = hero.portrait { hero.portrait = try LocalImage.normalize(portrait) }
                if hero.creatures != nil { for i in hero.creatures!.indices { if let image = hero.creatures![i].image { hero.creatures![i].image = try LocalImage.normalize(image) } } }
                return hero
            }
            if !imported.heroes.isEmpty {
                save()
                flushPendingWrites()
                if FileManager.default.fileExists(atPath:file.path) {
                    let backup = file.deletingLastPathComponent().appendingPathComponent("before-import-\(UUID().uuidString).json")
                    try Data(contentsOf:file).write(to:backup,options:.atomic)
                }
                var added = 0
                for hero in imported.heroes where !heroes.contains(where:{ $0.sourceXML == data && $0.name == hero.name }) { heroes.append(hero); selected = hero.id; added += 1 }
                save()
                notify("Imported \(added) character(s)",detail:"Portraits, spells, equipment, features, counters, and creatures are included. Read ‘Fight Club import review’ in Journal for mappings and fields to verify. Existing characters were backed up before import.",heroID:selected,reviewImport:added > 0)
            } else {
                var added = 0
                for var spell in imported.spells where !library.contains(where:{ $0.name.caseInsensitiveCompare(spell.name) == .orderedSame }) { spell.id = UUID(); library.append(spell); added += 1 }
                save(); notify("Imported \(added) spells",detail:"Custom roll formulas are included.")
            }
        } else {
            let archive = try JSONDecoder().decode(Archive.self,from:data); try validate(archive)
            for var hero in archive.heroes { hero.id = UUID(); hero.migrateContent(); heroes.append(hero) }
            for var spell in archive.library where !library.contains(where:{ $0.name == spell.name }) { spell.id = UUID(); library.append(spell) }
            if let entries = archive.compendium { compendium = CompendiumImport.merged(compendium,entries); let ids = Set(library.map(\.id)); for entry in compendium where !ids.contains(entry.id) { if let spell = entry.spell() { library.append(spell) } }; try saveCompendium() }
            selected = heroes.last?.id; save()
            notify("Imported \(archive.heroes.count) character(s)",detail:"Characters and references were added to your existing library.",heroID:selected)
        }
    }
}
