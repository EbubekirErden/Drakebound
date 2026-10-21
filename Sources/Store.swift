import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Central app state: characters, library, compendium, rolls, and view presentation state.
/// Saving, importing, and backups live in `StorePersistence.swift`.
@MainActor final class Store: ObservableObject {
    @Published var activity = ActivityLedger()
    @Published var showActivity = false
    var activityBaseline:[UUID:CharacterPlayState] = [:]
    var activityReady = false
    var activityContext:ActivityContext?
    @Published var characterArchiveReadFailed = false
    @Published var heroes: [Hero] = []
    @Published var library = starterSpells
    @Published var selected: UUID?
    @Published var rolls: [RollResult] = []
    @Published var animatedRoll: RollResult?
    @Published var rollMode = RollMode.normal
    private let dicePresenter = DicePresenter()
    @Published var error: String?
    @Published var compendium:[CompendiumEntry] = []
    @Published var compendiumRevision = 0
    @Published var showPDFExport = false
    @Published var compendiumAdd:CompendiumAddRequest?
    var quickNoteDrafts:[UUID:QuickNoteDraft] = [:]
    @Published var quickNoteHeroID:UUID?
    @Published var quickNoteOpen = false
    @Published var showHelp = false
    @Published var showCompendium = false
    @Published var activeTab = "Sheet"
    @Published var commandRequest:UICommandRequest?
    var consumedCommandID:UUID?
    @Published var openEditorSheets = 0
    @Published var importingCompendium = false
    @Published var spellDetail:SpellPresentation?
    @Published var itemDetail:ItemPresentation?
    @Published var characterGuide:CharacterGuideSession?
    var saveTask: Task<Void,Never>?
    let writer = ArchiveWriter()
    var lastSavedArchive:Archive?
    var lastSavedCompendium:[CompendiumEntry]?
    var bundledSRD=BundledSRD.empty
    let file: URL
    /// The live character archive in Application Support. Only the shipping app should use this default.
    static var liveFile:URL { FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Fellowship5e/characters.json") }
    /// Pass an explicit `file` (for example in a temporary directory) so previews and tests never touch live data.
    /// Companion files (compendium, activity, backups) are always stored beside `file`.
    init(file location:URL? = nil) {
        file = location ?? Store.liveFile
        if FileManager.default.fileExists(atPath:file.path) {
            do { let a = try JSONDecoder().decode(Archive.self,from:Data(contentsOf:file)); try validate(a); heroes = a.heroes; library = a.library }
            catch { characterArchiveReadFailed = true; self.error = "Your saved file could not be read. It has been left untouched. Restore a verified backup in the data folder, then choose Try again.\n\(error.localizedDescription)" }
        }
        for i in heroes.indices { heroes[i].migrateContent(); heroes[i].reconcileConcentration() }
        let compendiumFile = file.deletingLastPathComponent().appendingPathComponent("compendium.json")
        if FileManager.default.fileExists(atPath:compendiumFile.path) {
            do { compendium = try JSONDecoder().decode([CompendiumEntry].self,from:Data(contentsOf:compendiumFile)) }
            catch { self.error = "The compendium could not be read. Its file was left untouched.\n\(error.localizedDescription)" }
        }
        do { bundledSRD=try BundledSRD.load();compendium=bundledSRD.merging(entries:compendium);library=bundledSRD.merging(spells:library) }
        catch { self.error="The included SRD library could not be loaded. Your characters and imported references are unchanged. Reinstall the complete app bundle to restore the included library." }
        let lists = Dictionary(compendium.filter { $0.category == .spell }.map { ($0.id,$0.value("classes")) },uniquingKeysWith:{ first,_ in first })
        for i in library.indices where library[i].classes == nil { library[i].classes = lists[library[i].id] }
        for i in heroes.indices { heroes[i].synchronizeWeaponAttacks(compendium:compendium) }
        selected = heroes.first?.id
        loadActivity()
    }
    func roll(_ expression: String, _ label: String, mode:RollMode? = nil) {
        do { record(try Dice.d20(expression,label:label,mode:mode ?? rollMode)) }
        catch { self.error = "Use dice notation such as 1d20+5 or 2d6+3. Up to 100 dice per term, with 2–1000 sides." }
    }
    func rollTyped(_ expression:String,_ label:String,hero:Hero,kind:D20Kind,ability:Int? = nil,mode:RollMode? = nil) {
        do { record(try hero.performD20(expression,label:label,kind:kind,ability:ability,manual:mode ?? rollMode)) } catch { self.error = error.localizedDescription }
    }
    func record(_ result: RollResult) {
        if let selected { activityContext = ActivityContext(heroID:selected,title:result.label) }
        rolls.insert(result,at:0); rolls = Array(rolls.prefix(50))
        if !result.event { animatedRoll = result; dicePresenter.show(result) { [weak self] in self?.animatedRoll = nil } }
    }
    func addHero() { guard characterGuide == nil,!characterArchiveReadFailed else { return }; characterGuide = CharacterGuideSession() }
    func openSpell(_ spell:Spell,hero:Hero,library:Bool = false,ids:[UUID]) { spellDetail = SpellPresentation(heroID:hero.id,spell:spell,library:library,ids:ids) }
}
