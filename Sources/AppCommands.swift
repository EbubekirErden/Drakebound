import SwiftUI
import AppKit

enum UICommand:Equatable { case edit,addItem,addSpell,rest,search,diceInput }
struct UICommandRequest { var id = UUID(); var action:UICommand; var heroID:UUID }
extension Store {
    var menusAvailable:Bool { !characterArchiveReadFailed && characterGuide == nil && openEditorSheets == 0 }
    var canPerformMenuAction:Bool { menusAvailable && NSApp.keyWindow?.attachedSheet == nil && NSApp.keyWindow?.sheetParent == nil }
    var characterCommandsAvailable:Bool { menusAvailable && heroes.contains { $0.id == selected } }
    func navigate(to tab:String) {
        guard canPerformMenuAction else { return }
        searchNavigation=nil
        spellDetail = nil; itemDetail = nil; showCompendium = tab == "Compendium"
        if !showCompendium { activeTab = tab == "Actions" ? "Combat":tab }
    }
    func consume(_ request:UICommandRequest) -> Bool {
        guard consumedCommandID != request.id,selected == request.heroID else { return false }
        consumedCommandID = request.id; return true
    }
    func request(_ command:UICommand) {
        guard characterCommandsAvailable && canPerformMenuAction else { return }
        if command == .addItem { navigate(to:"Equipment") }
        if command == .addSpell { navigate(to:"Spells") }
        if command == .search && !showCompendium && !["Equipment","Spells","Combat"].contains(activeTab) { navigate(to:"Spells") }
        commandRequest = UICommandRequest(action:command,heroID:selected!)
    }
}
struct DrakeboundCommands:Commands {
    @ObservedObject var store:Store
    @AppStorage("appAppearance") private var appearance = "dark"
    var body:some Commands {
        CommandGroup(replacing:.appInfo) { Button("About Drakebound") { AppBrand.showAbout() } }
        CommandGroup(after:.appInfo) {
            Menu("Appearance") {
                Picker("Appearance",selection:$appearance) {
                    ForEach(AppAppearance.allCases,id:\.self) { Text($0.title).tag($0.rawValue) }
                }.pickerStyle(.inline)
            }
        }
        CommandGroup(replacing:.newItem) { Button("New Character") { if store.canPerformMenuAction { store.addHero() } }.keyboardShortcut("n").disabled(!store.menusAvailable) }
        CommandGroup(after:.newItem) {
            Button("Import Backup or Fight Club XML…") { if store.canPerformMenuAction { store.importBackup() } }.keyboardShortcut("i",modifiers:[.command,.shift]).disabled(!store.menusAvailable)
            Button("Back Up All Characters & References…") { if store.canPerformMenuAction { store.exportBackup() } }.keyboardShortcut("e",modifiers:[.command,.shift]).disabled(!store.menusAvailable)
        }
        CommandGroup(after:.importExport) {
            Button("Export Character PDF…") { if store.canPerformMenuAction { store.showPDFExport = true } }.keyboardShortcut("p",modifiers:[.command,.shift]).disabled(!store.characterCommandsAvailable)
            Button("Export Character JSON…") { if let id = store.selected,store.canPerformMenuAction { store.exportCharacter(id) } }.disabled(!store.characterCommandsAvailable)
        }
        CommandGroup(replacing:.undoRedo) {
            Button("Undo") { store.undoFromMenu() }.keyboardShortcut("z").disabled(!store.editingText && !store.canUndoActivity)
            Button("Redo") { store.redoTextFromMenu() }.keyboardShortcut("z",modifiers:[.command,.shift]).disabled(!store.editingText)
        }
        CommandGroup(replacing:.help) {
            Button("Tips & shortcuts…") { store.showHelp = true }.disabled(!store.menusAvailable)
            Button("Included rules & attribution…") { AppBrand.showRulesCredits() }
            Button("SRD 5.2.1 reference PDF") { if let url=Bundle.main.resourceURL?.appendingPathComponent("SRD/SRD-5.2.1.pdf") { NSWorkspace.shared.open(url) } }
        }
        CommandMenu("Character") {
            Button("Edit Character…") { store.request(.edit) }.keyboardShortcut("e").disabled(!store.characterCommandsAvailable)
            Button("Level Up…") { if store.characterCommandsAvailable && store.canPerformMenuAction,let hero = store.heroes.first(where:{ $0.id == store.selected }) { store.beginLevelUp(hero) } }.keyboardShortcut("l",modifiers:[.command,.shift]).disabled(!store.characterCommandsAvailable || (store.heroes.first(where:{ $0.id == store.selected })?.level ?? 20) >= 20)
            Divider()
            Button("Add Equipment…") { store.request(.addItem) }.keyboardShortcut("n",modifiers:[.command,.shift]).disabled(!store.characterCommandsAvailable)
            Button("Quick Note…") { store.beginQuickNote() }.keyboardShortcut("j",modifiers:[.command,.shift]).disabled(!store.characterCommandsAvailable || store.importingCompendium)
            Button("Add Spell…") { store.request(.addSpell) }.keyboardShortcut("n",modifiers:[.command,.option]).disabled(!store.characterCommandsAvailable)
            Button("Activity Log…") { if store.canPerformMenuAction { store.captureActivity(); store.showActivity = true } }.disabled(!store.characterCommandsAvailable)
            Button("Rest & Recovery…") { store.request(.rest) }.keyboardShortcut("r",modifiers:[.command,.shift]).disabled(!store.characterCommandsAvailable)
        }
        CommandMenu("Navigate") {
            Button("Sheet") { store.navigate(to:"Sheet") }.keyboardShortcut("1").disabled(!store.menusAvailable)
            Button("Combat") { store.navigate(to:"Combat") }.keyboardShortcut("2").disabled(!store.menusAvailable)
            Button("Equipment") { store.navigate(to:"Equipment") }.keyboardShortcut("3").disabled(!store.menusAvailable)
            Button("Spells") { store.navigate(to:"Spells") }.keyboardShortcut("4").disabled(!store.menusAvailable)
            Button("Journal") { store.navigate(to:"Journal") }.keyboardShortcut("5").disabled(!store.menusAvailable)
            Button("Creatures") { store.navigate(to:"Creatures") }.keyboardShortcut("6").disabled(!store.menusAvailable)
            Button("Compendium") { store.navigate(to:"Compendium") }.keyboardShortcut("7").disabled(!store.menusAvailable)
            Divider()
            Button("Search Everywhere…") { store.beginGlobalSearch() }.keyboardShortcut("k").disabled(!store.menusAvailable || store.importingCompendium)
            Button("Find…") { store.request(.search) }.keyboardShortcut("f").disabled(!store.characterCommandsAvailable)
        }
        CommandMenu("Dice") {
            Button("Enter Dice Formula") { store.request(.diceInput) }.keyboardShortcut("d").disabled(!store.characterCommandsAvailable)
            Button("Roll d20") { if store.canPerformMenuAction { store.roll("1d20","d20") } }.keyboardShortcut("r").disabled(!store.menusAvailable)
            ForEach([4,6,8,10,12,100],id:\.self) { sides in Button("Roll d\(sides)") { if store.canPerformMenuAction { store.roll("1d\(sides)","d\(sides)") } }.disabled(!store.menusAvailable) }
            Divider()
            Picker("D20 Mode",selection:$store.rollMode) { ForEach(RollMode.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.disabled(!store.menusAvailable)
        }
    }
}
