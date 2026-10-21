import SwiftUI
import AppKit
import Darwin

struct UXProbe:NSViewRepresentable {
    var name:String
    func makeNSView(context:Context)->NSView { let view=NSView();view.identifier=NSUserInterfaceItemIdentifier(name);return view }
    func updateNSView(_ view:NSView,context:Context) {}
}

@main struct PlayUXTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline:.now()+120) { fputs("FAIL: UI check timed out\n",stderr);Darwin.exit(1) }
        let root = URL(fileURLWithPath:CommandLine.arguments[1]).standardizedFileURL
        precondition(root.lastPathComponent.hasPrefix("drakebound-play-ux-") && root.deletingLastPathComponent().resolvingSymlinksInPath() == URL(fileURLWithPath:"/private/tmp").resolvingSymlinksInPath())
        let file = root.appendingPathComponent("data/characters.json")
        precondition(file.path != Store.liveFile.path)
        try! FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
        let store = Store(file:file)
        precondition(store.file == file && store.error == nil)
        var hero = Hero.sample
        hero.migrateContent();hero.synchronizeWeaponAttacks(compendium:store.compendium);hero.hp = 12;hero.tempHP = 5;hero.hitDiceUsed = 4
        hero.rulesEdition = "2014";hero.exhaustionLevel = 2;hero.usedSlots = hero.slots
        store.heroes = [hero];store.selected = hero.id;store.loadActivity()
        let original = hero
        let preview = RestPreview(hero:hero,event:.longRest)
        precondition(hero == original && preview.after.hp == hero.maximumHP)
        precondition(preview.after.hitDiceUsed == max(0,4-max(1,hero.level/2)))
        precondition(preview.after.exhaustionLevel == 1 && preview.after.tempHP == 0)
        precondition(preview.after.usedSlots.allSatisfy { $0 == 0 })
        precondition(preview.rows.contains { $0.title == "HP" && $0.value.contains("→") })
        hero.rulesEdition = "2024"
        precondition(RestPreview(hero:hero,event:.longRest).after.hitDiceUsed == 0)
        precondition(RestPreview(hero:hero,event:.shortRest).after.hp == 12)
        precondition(RestPreview(hero:hero,event:.fullRest).after.exhaustionLevel == 0)

        store.setTabVisible("Spells",false)
        precondition(!store.tabIsVisible("Spells"))
        store.navigate(to:"Spells");precondition(store.activeTab == "Spells","Hidden tabs remain accessible through fixed shortcuts")
        store.setTabVisible("Spells",false);precondition(store.activeTab == "Sheet")
        store.setTabVisible("Combat",false);precondition(store.tabIsVisible("Combat"))
        store.navigate(to:"Actions");precondition(store.activeTab == "Combat")
        var second = hero;second.id = UUID();second.name = "Second adventurer"
        store.heroes.append(second);store.selected = second.id
        precondition(store.tabIsVisible("Spells"),"Tab visibility must be per character")
        store.selected = original.id;store.loadActivity()
        store.heroes[0].hp -= 3;store.captureActivity()
        precondition(store.notice?.activityID != nil && store.canUndoNotice)
        store.undoNotice();precondition(store.heroes[0].hp == original.hp && store.notice == nil)
        store.heroes[0].hp -= 2;store.captureActivity()
        let stale = store.notice!
        store.heroes[0].usedSlots[0] -= 1;store.captureActivity()
        precondition(store.notice == nil,"Routine slot changes stay quiet and clear obsolete Undo")
        store.notice = stale;store.undoNotice()
        precondition(store.heroes[0].hp == original.hp-2,"Stale toast must not undo a newer change")
        store.heroes[0].hp -= 1;store.captureActivity();store.selected = second.id
        precondition(!store.canUndoNotice,"Undo must not cross characters")
        store.selected = original.id;store.notice = nil
        let imported = try! JSONEncoder().encode(Archive(heroes:[second],library:[]))
        try! store.importBackupData(imported,fileExtension:"json")
        precondition(store.error == nil && store.notice?.title == "Imported 1 character(s)")
        store.notice = nil;store.selected = original.id
        store.heroes[0] = original;store.loadActivity();store.captureActivity()
        store.heroes[0] = preview.after
        store.record(RollResult(label:"Long rest",expression:"Recovery completed",dice:[],total:0,event:true))
        store.captureActivity()
        precondition(store.notice?.title == "Long rest completed" && store.canUndoNotice)
        store.undoNotice();precondition(store.heroes[0] == original)
        print("PASS: rest previews match recovery without mutation; per-character tabs and fixed destinations; quiet slots; safe Undo; non-modal import success")
        store.setTabVisible("Spells",true)
        let host = NSHostingView(rootView:AnyView(RootView(store:store).preferredColorScheme(.light)))
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:620),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false;window.contentView = host;window.makeKeyAndOrderFront(nil)
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps:true);window.makeKeyAndOrderFront(nil)
            for mode in ["light","dark"] {
                NSApp.appearance = NSAppearance(named:mode == "light" ? .aqua:.darkAqua)
                for tab in ["Sheet","Combat","Equipment","Spells"] {
                    store.activeTab = tab
                    host.rootView = AnyView(RootView(store:store).preferredColorScheme(mode == "light" ? .light:.dark))
                    try? await Task.sleep(nanoseconds:350_000_000)
                    screenshot(window,root.appendingPathComponent("\(tab.lowercased())-\(mode)-small.png"))
                }
            }
            store.activeTab = "Combat"
            NSApp.appearance=NSAppearance(named:.aqua)
            var veteran=original;veteran.level=17;veteran.name="Aelar Windrunner";veteran.hp=85;veteran.maxHP=112;veteran.exhaustionLevel=0
            veteran.slots=[4,3,3,3,2,1,1,1,1];veteran.usedSlots=[2,1,0,1,0,0,0,0,0]
            veteran.counters=[ResourceCounter(name:"Arcane Recovery",current:1,maximum:1),ResourceCounter(name:"Ward",current:3,maximum:6)]
            store.heroes[0]=veteran;store.loadActivity();store.notice=nil
            host.rootView=AnyView(RootView(store:store).preferredColorScheme(.light))
            window.setContentSize(NSSize(width:1260,height:840))
            await pause();screenshot(window,root.appendingPathComponent("combat-light-wide.png"))
            window.setContentSize(NSSize(width:900,height:620));await pause()
            screenshot(window,root.appendingPathComponent("combat-level17-small.png"))
            // Exercise actual row controls, not fixtures in the live Store.
            let beforeHit=store.heroes[0]
            await click("attack-hit",window:window)
            precondition(store.rolls.first?.label.contains("attack") == true && store.heroes[0].usedSlots == beforeHit.usedSlots)
            await click("slot-spend-1",window:window)
            precondition(store.heroes[0].usedSlots[0] == beforeHit.usedSlots[0]+1)
            store.heroes[0].usedSlots[0]=beforeHit.usedSlots[0];store.captureActivity();store.notice=nil
            let beforeSearch=store.heroes
            await click("global-search",window:window)
            await pause()
            guard let sheet=window.attachedSheet else { fatalError("Global search did not open") }
            await typeSearch("magic missile",window:sheet)
            screenshot(sheet,root.appendingPathComponent("global-search.png"))
            precondition(store.heroes == beforeSearch,"Typing search must not change resources")
            let known=store.heroes[0].spells.first { $0.name == "Magic missile" }!
            await click("search-result-spell:"+known.id.uuidString,window:sheet)
            await pause()
            precondition(!store.globalSearchOpen && store.spellDetail?.spell.id == known.id)
            precondition(store.heroes == beforeSearch,"Opening a spell result must not cast it")
            store.spellDetail=nil;await pause()
            let reference=store.compendium.first { $0.category == .item }!
            store.beginGlobalSearch();await pause()
            guard let referenceSheet=window.attachedSheet else { fatalError("Search could not reopen") }
            await typeSearch(reference.name,window:referenceSheet)
            await click("search-result-reference:"+reference.id.uuidString,window:referenceSheet)
            await pause()
            precondition(store.searchDetail?.reference?.id == reference.id && store.heroes == beforeSearch)
            store.searchDetail=nil;await pause()
            let beforeOptions=store.heroes
            await click("casting-options-Magic missile",window:window)
            guard let options=NSApp.windows.first(where:{ candidate in candidate.isVisible && candidate.contentView.map(descendants)?.contains(where:{ $0.identifier?.rawValue == "casting-popover" }) == true }) else { fatalError("Explicit casting options did not open") }
            screenshot(options,root.appendingPathComponent("combat-casting-options.png"))
            precondition(store.heroes == beforeOptions,"Opening casting options must spend nothing")
            store.heroes[0]=original;store.loadActivity();store.notice=nil
            store.activeTab = "Sheet"
            host.rootView = AnyView(RootView(store:store).preferredColorScheme(.light).dynamicTypeSize(.accessibility3))
            try? await Task.sleep(nanoseconds:350_000_000)
            screenshot(window,root.appendingPathComponent("sheet-large-text-small.png"))
            var compact=original
            compact.conditions=[];compact.exhaustionLevel=0
            compact.counters=(0..<9).map { ResourceCounter(name:$0 == 0 ? "Arcane Recovery":"Resource \($0+1)",current:2,maximum:3) }
            compact.featureEntries=(0..<24).map { i in CharacterFeature(name:"Feature \(i+1)",text:"Full description \(i+1). This text should appear only after opening its feature.",counter:i == 0 ? ResourceCounter(name:"Feature use",current:1,maximum:2):nil,category:.classFeature,source:"Class progression") }
            store.heroes[0]=compact;store.loadActivity()
            let binding=Binding<Hero>(get:{ store.heroes[0] },set:{ store.heroes[0]=$0 })
            window.setContentSize(NSSize(width:1000,height:700))
            host.rootView=AnyView(ScrollView { VStack(spacing:14) { AttacksAndResourcesPanel(hero:binding,store:store,width:960,edit:{ _ in });FeaturePanel(hero:binding,store:store) }.padding(20) }.background(paper).foregroundStyle(ink).preferredColorScheme(.light))
            await pause();screenshot(window,root.appendingPathComponent("sheet-compact-sections.png"))
            precondition(!descendants(window.contentView!).contains { $0.identifier?.rawValue == "feature-description" },"Feature descriptions must start hidden")
            let featureID=compact.featureEntries![0].id
            let beforeDisclosure=store.heroes[0]
            await click("feature-toggle-"+featureID.uuidString,window:window)
            precondition(descendants(window.contentView!).contains { $0.identifier?.rawValue == "feature-description" })
            precondition(store.heroes[0] == beforeDisclosure,"Reading a feature cannot change character data")
            screenshot(window,root.appendingPathComponent("sheet-feature-expanded.png"))
            await click("feature-toggle-"+featureID.uuidString,window:window)
            precondition(!descendants(window.contentView!).contains { $0.identifier?.rawValue == "feature-description" })
            await click("resource-chip-"+store.heroes[0].resourceChoices[0].ref.key,window:window)
            guard let resourceWindow=NSApp.windows.first(where:{ $0.isVisible && $0.contentView.map(descendants)?.contains(where:{ $0.identifier?.rawValue == "resource-spend" }) == true }) else { fatalError("Resource details did not open") }
            precondition(store.heroes[0] == beforeDisclosure)
            screenshot(resourceWindow,root.appendingPathComponent("sheet-resource-popup.png"))
            await click("resource-spend",window:resourceWindow)
            precondition(store.heroes[0].counters![0].current == 1 && store.heroes[0].counters![1].current == 2)
            await click("resource-done",window:resourceWindow)
            window.setContentSize(NSSize(width:650,height:700))
            host.rootView=AnyView(ScrollView { VStack(spacing:14) { AttacksAndResourcesPanel(hero:binding,store:store,width:610,edit:{ _ in });FeaturePanel(hero:binding,store:store) }.padding(20) }.background(paper).foregroundStyle(ink).preferredColorScheme(.light))
            await pause();screenshot(window,root.appendingPathComponent("sheet-compact-sections-narrow.png"))
            host.rootView=AnyView(ConditionsEditor(hero:binding).preferredColorScheme(.light))
            window.setContentSize(NSSize(width:510,height:490))
            await pause();screenshot(window,root.appendingPathComponent("conditions-compact.png"))
            await click("condition-toggle-Poisoned",window:window)
            precondition(store.heroes[0].hasCondition("Poisoned") && store.heroes[0].rollMode(for:.attack) == .disadvantage)
            store.heroes[0].spells[0].concentration=true;store.heroes[0].concentrationSpellID=store.heroes[0].spells[0].id
            await click("condition-toggle-Paralyzed",window:window)
            precondition(store.heroes[0].hasCondition("Paralyzed") && store.heroes[0].concentrationSpellID == nil)
            host.rootView=AnyView(ConditionsReference().preferredColorScheme(.light))
            window.setContentSize(NSSize(width:560,height:540));await pause()
            screenshot(window,root.appendingPathComponent("conditions-reference.png"))
            store.heroes[0]=original;store.loadActivity()
            host.rootView = AnyView(RestEditor(hero:Binding(get:{ store.heroes[0] },set:{ store.heroes[0] = $0 }),store:store,initialRest:.longRest).preferredColorScheme(.light))
            window.setContentSize(NSSize(width:500,height:440))
            try? await Task.sleep(nanoseconds:350_000_000)
            screenshot(window,root.appendingPathComponent("rest-compact.png"))
            host.rootView = AnyView(WelcomeView(store:store).preferredColorScheme(.light))
            window.setContentSize(NSSize(width:900,height:620))
            try? await Task.sleep(nanoseconds:350_000_000)
            screenshot(window,root.appendingPathComponent("welcome-branded.png"))
            store.saveTaskCancellationForGuide();store.flushPendingWrites()
            print("PASS: isolated Combat/Sheet/Spells layouts, high-level slots, actual attack/slot controls, global search routing without spending, rest and branding; compact feature disclosure, resource adjustment and condition toggles")
            fflush(stdout);Darwin.exit(0)
        }
        NSApp.run()
    }
    @MainActor static func pause() async { try? await Task.sleep(nanoseconds:500_000_000) }
    @MainActor static func descendants(_ view:NSView)->[NSView] { [view]+view.subviews.flatMap(descendants) }
    @MainActor static func click(_ name:String,window:NSWindow) async {
        guard let anchor=window.contentView.flatMap({ descendants($0).first { $0.identifier?.rawValue == name } }) else { fatalError("Missing UI control: "+name) }
        anchor.scrollToVisible(anchor.bounds);await pause()
        let point=anchor.convert(NSPoint(x:name.hasPrefix("condition-toggle-") ? 12:anchor.bounds.midX,y:anchor.bounds.midY),to:nil)
        for type in [NSEvent.EventType.leftMouseDown,.leftMouseUp] {
            NSApp.sendEvent(NSEvent.mouseEvent(with:type,location:point,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1)!)
        }
        await pause()
    }
    @MainActor static func typeSearch(_ query:String,window:NSWindow) async {
        guard let field=window.contentView.map(descendants)?.compactMap({ $0 as? NSTextField }).first(where:{ $0.placeholderString?.hasPrefix("Search spells") == true }) else { fatalError("Missing global search field") }
        field.selectText(nil)
        guard let editor=window.firstResponder as? NSTextView else { fatalError("Search field is not focused") }
        editor.insertText(query,replacementRange:NSRange(location:0,length:editor.string.utf16.count))
        await pause();await pause()
    }
    @MainActor static func screenshot(_ window:NSWindow,_ url:URL) {
        let view = window.contentView!,bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds)!
        view.cacheDisplay(in:view.bounds,to:bitmap)
        try! bitmap.representation(using:.png,properties:[:])!.write(to:url)
    }
}
