import SwiftUI
import AppKit

extension Store {
    var activityFile:URL { file.deletingLastPathComponent().appendingPathComponent("activity.json") }
    func loadActivity() {
        if let data = try? Data(contentsOf:activityFile),data.count <= 20_000_000,let saved = try? JSONDecoder().decode(ActivityLedger.self,from:data) {
            activity = saved
            activity.entries = Array(activity.entries.prefix(200))
        }
        activityBaseline = Dictionary(uniqueKeysWithValues:heroes.map { ($0.id,CharacterPlayState($0)) })
        activityReady = true
    }
    func persistActivity() {
        do { try FileManager.default.createDirectory(at:activityFile.deletingLastPathComponent(),withIntermediateDirectories:true); try JSONEncoder().encode(activity).write(to:activityFile,options:.atomic) }
        catch { self.error = "Your character is saved, but its activity log could not be saved.\n"+error.localizedDescription }
    }
    func captureActivity() {
        guard activityReady else { return }
        var changed = false
        for hero in heroes {
            let current = CharacterPlayState(hero)
            if let before = activityBaseline[hero.id],before != current {
                let hint = activityContext.flatMap { $0.heroID == hero.id && Date().timeIntervalSince($0.date) < 0.5 ? $0.title:nil }
                activity.record(before:before,hero:hero,hint:hint)
                changed = true
            }
            activityBaseline[hero.id] = current
        }
        activityBaseline = activityBaseline.filter { id,_ in heroes.contains { $0.id == id } }
        activityContext = nil
        if changed { persistActivity() }
    }
    var canUndoActivity:Bool {
        guard canPerformMenuAction,let hero = heroes.first(where:{ $0.id == selected }) else { return false }
        return activity.canUndo(hero)
    }
    func undoActivity() {
        guard canPerformMenuAction,let index = heroes.firstIndex(where:{ $0.id == selected }) else { return }
        captureActivity()
        guard activity.canUndo(heroes[index]) else { return }
        do {
            let restored = try activity.undo(heroes[index])
            heroes[index] = restored
            activityBaseline[restored.id] = CharacterPlayState(restored)
            activityContext = nil
            persistActivity(); save()
        } catch { self.error = error.localizedDescription }
    }
    var editingText:Bool { NSApp.keyWindow?.firstResponder is NSTextView }
    func undoFromMenu() {
        if let text = NSApp.keyWindow?.firstResponder as? NSTextView,let manager = text.undoManager,manager.canUndo { manager.undo() }
        else { undoActivity() }
    }
    func redoTextFromMenu() { if let manager = (NSApp.keyWindow?.firstResponder as? NSTextView)?.undoManager,manager.canRedo { manager.redo() } }
}
struct ActivityContext { var heroID:UUID; var date = Date(); var title:String }
struct ActivityButton:View {
    @ObservedObject var store:Store
    var body:some View {
        Button { store.captureActivity(); store.showActivity = true } label: { Image(systemName:"list.bullet.rectangle").font(.system(size:13)).foregroundStyle(accent).frame(width:25,height:25).contentShape(Rectangle()) }.buttonStyle(.plain).help("Character activity · undo recent play changes").accessibilityLabel("Character activity")
            .popover(isPresented:$store.showActivity) { ActivityPanel(store:store) }
    }
}
struct ActivityPanel:View {
    @ObservedObject var store:Store
    var entries:[CharacterActivity] { store.activity.entries.filter { $0.heroID == store.selected } }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { VStack(alignment:.leading,spacing:3) { Text("Character activity").font(.headline); Text(store.heroes.first { $0.id == store.selected }?.name ?? "Select a character").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("Done") { store.showActivity = false } }
            Button { store.undoActivity() } label: { Label("Undo last change",systemImage:"arrow.uturn.backward").font(.caption.weight(.semibold)).frame(maxWidth:.infinity).padding(9).background(accent.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius:7)) }.buttonStyle(.plain).disabled(!store.canUndoActivity).help("Undo the newest remaining play change for this character · ⌘Z outside text editing")
            Divider()
            if entries.isEmpty { CenteredEmptyState("No play changes yet",systemImage:"list.bullet.rectangle",description:Text("HP, slots, counters, equipment, concentration, and creatures appear here as you play.")) }
            else { ScrollView { LazyVStack(alignment:.leading,spacing:12) {
                ForEach(entries) { entry in
                    VStack(alignment:.leading,spacing:5) {
                        HStack(alignment:.firstTextBaseline) { Text(entry.title).font(.system(size:12,weight:.semibold)).strikethrough(entry.undone); Spacer(minLength:6); if entry.undone { Text("Undone").font(.system(size:9)).foregroundStyle(accent) } else if !entry.undoable { Image(systemName:"lock").font(.system(size:9)).foregroundStyle(.secondary) } }
                        Text(entry.date.formatted(date:.abbreviated,time:.shortened)).font(.system(size:9)).foregroundStyle(.secondary)
                        ForEach(Array(entry.details.enumerated()),id:\.offset) { _,line in Text(line).font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                    }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(paper.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius:7)).opacity(entry.undone ? 0.65:1)
                }
            } } }
        }.padding(18).frame(width:390,height:440).tint(accent)
    }
}
