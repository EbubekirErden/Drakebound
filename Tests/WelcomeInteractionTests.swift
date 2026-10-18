import SwiftUI
import AppKit
import Darwin

struct WelcomeProbe:NSViewRepresentable {
    var name:String
    func makeNSView(context:Context) -> NSView { let view=NSView();view.identifier=NSUserInterfaceItemIdentifier(name);return view }
    func updateNSView(_ view:NSView,context:Context) {}
}
struct WelcomeTestRoot:View {
    @ObservedObject var store:Store
    @AppStorage("appAppearance") private var mode="dark"
    var body:some View {
        RootView(store:store).preferredColorScheme((AppAppearance(rawValue:mode) ?? .dark).colorScheme)
            .onChange(of:mode) { _,_ in NSApp.appearance=AppAppearance.selected.native }
    }
}
@main struct WelcomeInteractionTests {
    @MainActor static func main() {
        _ = NSApplication.shared;NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline:.now()+60) { fputs("FAIL: welcome check timed out\n",stderr);Darwin.exit(1) }
        let store=Store()
        precondition(CommandLine.arguments.count == 2 && store.file.path == CommandLine.arguments[1],"Fixture Store must use the compiled isolated path")
        precondition(store.heroes.isEmpty && store.selected == nil && !FileManager.default.fileExists(atPath:store.file.path),"Fresh install must not seed a demo")
        UserDefaults.standard.set("dark",forKey:"appAppearance")
        let host=NSHostingView(rootView:WelcomeTestRoot(store:store))
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1000,height:760),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.contentView=host;window.center();window.makeKeyAndOrderFront(nil)
        Task { @MainActor in await WelcomeTestProbe.run(store,window:window) };NSApp.run()
    }
}
@MainActor enum WelcomeTestProbe {
    static func pause() async { try? await Task.sleep(nanoseconds:500_000_000) }
    static func descendants(_ view:NSView) -> [NSView] { [view]+view.subviews.flatMap(descendants) }
    static func click(_ name:String,window:NSWindow) async {
        guard let anchor=window.contentView.flatMap({ descendants($0).first { $0.identifier?.rawValue == name } }) else { fatalError("No welcome control: "+name) }
        let point=anchor.convert(NSPoint(x:anchor.bounds.midX,y:anchor.bounds.midY),to:nil)
        for type in [NSEvent.EventType.leftMouseDown,.leftMouseUp] {
            NSApp.sendEvent(NSEvent.mouseEvent(with:type,location:point,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1)!)
        }
        await pause()
    }
    static func screenshot(_ window:NSWindow,_ name:String) throws {
        let view=window.contentView!,bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds)!
        view.cacheDisplay(in:view.bounds,to:bitmap)
        try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]).deletingLastPathComponent().appendingPathComponent(name+".png"))
    }
    static func fixtureStore() -> Store {
        let store=Store();precondition(store.file.path == CommandLine.arguments[1]);return store
    }
    static func run(_ store:Store,window:NSWindow) async {
        NSApp.appearance=NSAppearance(named:.darkAqua);NSApp.activate(ignoringOtherApps:true);window.makeKeyAndOrderFront(nil)
        await pause();await pause()
        try! screenshot(window,"welcome-dark")
        UserDefaults.standard.set("light",forKey:"appAppearance");await pause()
        window.setContentSize(NSSize(width:900,height:620));await pause();try! screenshot(window,"welcome-light-small")
        store.save();let empty=try! JSONDecoder().decode(Archive.self,from:Data(contentsOf:store.file))
        precondition(empty.heroes.isEmpty && fixtureStore().heroes.isEmpty,"Empty roster must persist")
        await click("Create a character",window:window)
        precondition(store.characterGuide != nil && store.heroes.isEmpty,"Create must open guide without saving a hero")
        store.characterGuide=nil;await pause()
        precondition(store.heroes.isEmpty,"Cancel must return to Welcome without a character")
        await click("Import a character",window:window);try! screenshot(window,"welcome-import")
        await click("welcome-back",window:window)
        await click("Explore a demo",window:window);precondition(store.heroes.isEmpty,"Demo preview must not create a hero")
        try! screenshot(window,"welcome-demo-preview")
        await click("welcome-back",window:window)
        store.showCompendium=true;await pause();precondition(store.heroes.isEmpty)
        store.showCompendium=false;await pause()
        store.exploreWelcomeDemo();await pause()
        precondition(store.heroes.count == 1 && store.heroes[0].name.hasSuffix("(demo)") && store.selected == store.heroes[0].id)
        let demo=store.heroes[0];precondition(fixtureStore().heroes[0].id == demo.id,"Demo must persist only when chosen")
        store.exploreWelcomeDemo();precondition(store.heroes.count == 1,"Demo must not replace an existing roster")
        store.heroes=[];store.selected=nil;store.save();await pause()
        precondition(fixtureStore().heroes.isEmpty,"Deleting last character must not resurrect demo")
        var draft=CharacterBuildDraft();draft.hero.name="First real adventurer";draft.hero.ancestry="Custom ancestry";draft.hero.background="Custom background"
        draft.originAdjustments=[0,0,0,2,1,0];draft.classSkillChoices=["Athletics","Perception"]
        draft.changeAbilityMethod(.manual);draft.manualScores=[15,14,14,12,10,8]
        store.addHero();try! store.commitGuide(draft);await pause()
        precondition(store.heroes.count == 1 && store.heroes[0].name == "First real adventurer" && store.characterGuide == nil)
        let original=store.heroes[0]
        var imported=Hero.sample;imported.name="Imported adventurer";imported.migrateContent()
        let source=try! JSONEncoder().encode(Archive(heroes:[imported],library:[Spell(name:"Restored custom spell",level:1)]))
        try! store.importBackupData(source,fileExtension:"json");await pause()
        precondition(store.heroes.count == 2 && store.heroes[0] == original && store.heroes[1].name == imported.name)
        precondition(store.library.contains { $0.name == "Restored custom spell" } && store.selected == store.heroes[1].id)
        let roster=store.heroes
        do { try store.importBackupData(Data("not JSON".utf8),fileExtension:"json");fatalError("Invalid import accepted") } catch { }
        precondition(store.heroes == roster)
        let reloaded=fixtureStore();precondition(reloaded.heroes.map(\.id) == roster.map(\.id),"Existing characters must load directly without added sample")
        store.saveTaskCancellationForGuide();await pause();store.saveTaskCancellationForGuide()
        let valid=try! Data(contentsOf:store.file),corrupt=Data("broken archive retained".utf8)
        try! corrupt.write(to:store.file,options:.atomic)
        let protected=fixtureStore();precondition(protected.characterArchiveReadFailed && protected.heroes.isEmpty)
        protected.error=nil;protected.save();protected.addHero();protected.exploreWelcomeDemo()
        precondition(protected.heroes.isEmpty && protected.characterGuide == nil)
        do { try protected.commitGuide(draft);fatalError("Guide overwrote failed archive") } catch { }
        do { try protected.importBackupData(source,fileExtension:"json");fatalError("Import overwrote failed archive") } catch { }
        precondition(try! Data(contentsOf:store.file) == corrupt,"Unreadable data must never be overwritten")
        window.contentView=NSHostingView(rootView:WelcomeTestRoot(store:protected));await pause();try! screenshot(window,"welcome-recovery")
        try! valid.write(to:store.file,options:.atomic);protected.retryCharacterArchive()
        precondition(!protected.characterArchiveReadFailed && protected.heroes.map(\.id) == roster.map(\.id))
        store.saveTaskCancellationForGuide();protected.saveTaskCancellationForGuide()
        print("PASS: fresh/empty reloads, native welcome choices, creation/cancel/commit, optional demo, compendium navigation, additive JSON import, existing-character preservation, failed-archive protection and recovery; Dark/Light views rendered.")
        fflush(stdout);Darwin.exit(0)
    }
}
