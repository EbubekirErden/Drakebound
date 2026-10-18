import Foundation

extension Store {
    func exploreWelcomeDemo() {
        guard heroes.isEmpty,!characterArchiveReadFailed,characterGuide == nil,!importingCompendium else { return }
        var hero=Hero.sample;hero.name += " (demo)";hero.migrateContent();hero.reconcileConcentration()
        heroes=[hero];selected=hero.id;activeTab="Sheet";showCompendium=false
        save()
    }
    func retryCharacterArchive() {
        guard characterArchiveReadFailed else { return }
        do {
            let archive=try JSONDecoder().decode(Archive.self,from:Data(contentsOf:file));try validate(archive)
            var loaded=archive.heroes
            for i in loaded.indices { loaded[i].migrateContent();loaded[i].reconcileConcentration();loaded[i].synchronizeWeaponAttacks(compendium:compendium) }
            library=bundledSRD.merging(spells:archive.library);heroes=loaded;selected=loaded.first?.id
            characterArchiveReadFailed=false;error=nil
            loadActivity()
        } catch { self.error="The saved character file still cannot be read. It has been left untouched. Restore a verified backup, then try again." }
    }
}
