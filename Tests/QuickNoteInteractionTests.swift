import SwiftUI
import AppKit
import Darwin

struct QuickNotePreviewRoot:View {
    @ObservedObject var store:Store
    @AppStorage("appAppearance") private var mode="light"
    var body:some View {
        RootView(store:store).preferredColorScheme((AppAppearance(rawValue:mode) ?? .light).colorScheme)
            .onChange(of:mode) { _,_ in NSApp.appearance=AppAppearance.selected.native }
    }
}
@main struct QuickNoteInteractionTests {
    @MainActor static func main() {
        _ = NSApplication.shared;NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline:.now()+40) { fputs("FAIL: quick-note UI check timed out\n",stderr);Darwin.exit(1) }
        let store=Store(file:URL(fileURLWithPath:CommandLine.arguments[1]));precondition(store.file.path != Store.liveFile.path,"Tests must never use the live save");precondition(CommandLine.arguments.count == 2 && store.file.path == CommandLine.arguments[1],"Test Store must use its compiled isolated path")
        var first=Hero();first.name="Capture test A";first.items=[];first.attacks=[];first.spells=[];first.migrateContent()
        first.journalEntries=[JournalEntry(title:"Existing pinned note",description:"Keep this intact",pinned:true,tags:["Lore"])]
        var second=Hero();second.name="Untouched test B";second.items=[];second.attacks=[];second.spells=[];second.migrateContent()
        store.heroes=[first,second];store.selected=first.id;store.activeTab="Journal"
        UserDefaults.standard.set("light",forKey:"appAppearance")
        let host=NSHostingView(rootView:QuickNotePreviewRoot(store:store))
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1200,height:800),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.contentView=host;window.center();window.makeKeyAndOrderFront(nil)
        Task { @MainActor in await QuickNoteProbe.run(store) }
        NSApp.run()
    }
}

@MainActor enum QuickNoteProbe {
    static var started=false
    static func pause() async { try? await Task.sleep(nanoseconds:500_000_000) }
    static func descendants(_ view:NSView) -> [NSView] { [view]+view.subviews.flatMap(descendants) }
    static func bodyEditor() -> NSTextView? {
        NSApp.windows.filter(\.isVisible).flatMap { $0.contentView.map(descendants) ?? [] }.compactMap { $0 as? NSTextView }.first { !$0.isFieldEditor && $0.isEditable }
    }
    static func typeBody(_ text:String) async {
        guard let editor=bodyEditor() else { fatalError("Capture editor did not open") }
        precondition(editor.window?.firstResponder === editor,"Text area must focus on open")
        editor.insertText(text,replacementRange:NSRange(location:0,length:editor.string.utf16.count));await pause()
    }
    static func screenshot(_ editor:NSTextView,_ name:String) throws {
        guard let content=editor.window?.contentView else { fatalError("No popover window") }
        let bitmap=content.bitmapImageRepForCachingDisplay(in:content.bounds)!;content.cacheDisplay(in:content.bounds,to:bitmap)
        try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]).deletingLastPathComponent().appendingPathComponent(name+".png"))
    }
    static func run(_ store:Store) async {
        guard !started else { return };started=true
        NSApp.appearance=NSAppearance(named:.aqua);NSApp.activate(ignoringOtherApps:true)
        await pause();await pause()
        guard NSApp.mainWindow != nil else { fatalError("No app window") }
        let firstID=store.heroes[0].id,secondID=store.heroes[1].id
        let before=store.heroes
        store.beginQuickNote();await pause()
        precondition(store.quickNoteOpen && store.quickNoteHeroID == firstID,"Capture must target selected character")
        precondition(store.quickNoteDrafts[firstID] == nil)
        store.commitQuickNote();precondition(store.heroes == before && store.quickNoteOpen,"Blank capture must not save")
        await typeBody("Moon gate\nAsk the keeper about the key.")
        guard let editor=bodyEditor(),let popup=editor.window,
              let field=popup.contentView.map(descendants)?.compactMap({ $0 as? NSTextField }).first(where:{ $0.placeholderString?.contains("Tags, separated") == true }) else { fatalError("Missing tags field") }
        field.selectText(nil)
        (popup.firstResponder as! NSTextView).insertText("Quest, #NPC, quest",replacementRange:NSRange(location:0,length:0));await pause()
        let draft=store.quickNoteDrafts[firstID]!
        precondition(draft.tags == "Quest, #NPC, quest")
        try! screenshot(editor,"quick-note-light")
        // Exercise the same binding dismissal used by the popover's Close/outside-click paths.
        store.quickNoteOpen=false;await pause()
        precondition(!store.quickNoteOpen,"Dismissal must close capture")
        precondition(store.quickNoteDrafts[firstID] == draft,"Dismiss must retain the exact draft")
        precondition(store.heroes == before,"Dismiss must not save or change any character")
        store.beginQuickNote();await pause()
        precondition(bodyEditor()?.string == draft.text,"Reopening must restore the draft")
        guard let reopened=bodyEditor()?.window else { fatalError("Capture failed to reopen") }
        _ = reopened;store.commitQuickNote();await pause()
        precondition(!store.quickNoteOpen,"Add note must save and close capture")
        precondition(store.quickNoteDrafts[firstID] == nil && store.heroes[1] == before[1])
        let added=store.heroes[0].journalEntries!.first!
        precondition(added.title == "Moon gate" && added.description == draft.text && added.tags == ["Quest","NPC"])
        var expected=before[0];expected.journalEntries=[added]+before[0].journalEntries!
        precondition(store.heroes[0] == expected,"Capture must only change journal entries")
        store.commitQuickNote();precondition(store.heroes[0] == expected,"Double submission must not duplicate")
        store.save();let archive=try! JSONDecoder().decode(Archive.self,from:Data(contentsOf:store.file))
        precondition(archive.heroes == store.heroes,"Note must persist in the existing archive")
        store.selected=secondID;await pause();store.beginQuickNote();await pause();await typeBody("Second character draft")
        store.selected=firstID;await pause()
        precondition(!store.quickNoteOpen && store.quickNoteDrafts[secondID]?.text == "Second character draft")
        store.beginQuickNote();await pause();precondition(bodyEditor()?.string == "")
        await typeBody("New first character draft");store.quickNoteOpen=false;await pause()
        store.selected=secondID;await pause()
        UserDefaults.standard.set("dark",forKey:"appAppearance");await pause()
        store.beginQuickNote();await pause()
        precondition(bodyEditor()?.string == "Second character draft")
        try! screenshot(bodyEditor()!,"quick-note-dark")
        store.quickNoteOpen=false;await pause()
        store.openEditorSheets=1;store.beginQuickNote();precondition(!store.quickNoteOpen,"Do not interrupt another editor")
        store.openEditorSheets=0
        let count=store.heroes[0].journalEntries!.count
        store.quickNoteHeroID=UUID();store.quickNoteOpen=true;store.commitQuickNote()
        precondition(store.heroes[0].journalEntries!.count == count,"Missing captured character must not retarget a note")
        store.quickNoteOpen=false;store.saveTaskCancellationForGuide()
        print("PASS: native focus and typing/tags, dismissal and draft retention, save, duplicate/blank guards, archive persistence, per-character drafts and editor guards; Light/Dark popovers rendered.")
        fflush(stdout);Darwin.exit(0)
    }
}
