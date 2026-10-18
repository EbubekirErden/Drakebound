import SwiftUI

extension Store {
    func beginQuickNote() {
        guard canPerformMenuAction,characterCommandsAvailable,!importingCompendium,!quickNoteOpen,let id=selected else { return }
        quickNoteHeroID=id
        quickNoteOpen=true
    }
    func commitQuickNote() {
        guard quickNoteOpen,let id=quickNoteHeroID,let index=heroes.firstIndex(where:{ $0.id == id }),
              let draft=quickNoteDrafts[id],draft.canSave else { return }
        guard heroes[index].addQuickNote(draft) != nil else { return }
        quickNoteDrafts[id]=nil
        quickNoteOpen=false
        scheduleSave()
    }
}

struct QuickNoteButton:View {
    @ObservedObject var store:Store
    var body:some View {
        Button { if store.quickNoteOpen { store.quickNoteOpen=false } else { store.beginQuickNote() } } label: {
            Image(systemName:"square.and.pencil").frame(width:28,height:28)
                .foregroundStyle(journalTint).background(journalTint.opacity(store.quickNoteOpen ? 0.14:0),in:RoundedRectangle(cornerRadius:6))
        }.buttonStyle(.plain).help("Quick note · ⇧⌘J").accessibilityLabel("Quick note")
            .disabled(!store.characterCommandsAvailable || store.importingCompendium)
            .popover(isPresented:$store.quickNoteOpen,arrowEdge:.bottom) {
                if let id=store.quickNoteHeroID { QuickNotePopover(store:store,heroID:id) }
            }
    }
}

struct QuickNotePopover:View {
    @ObservedObject var store:Store
    let heroID:UUID
    @FocusState private var textFocused:Bool
    @State private var capture:QuickNoteDraft
    init(store:Store,heroID:UUID) {
        self.store=store;self.heroID=heroID
        _capture=State(initialValue:store.quickNoteDrafts[heroID] ?? QuickNoteDraft())
    }
    private var draft:Binding<QuickNoteDraft> {
        Binding(get:{ capture },set:{ capture=$0;store.quickNoteDrafts[heroID]=$0 })
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text("Quick note").font(.system(size:16,weight:.semibold))
                Spacer()
                Button { store.quickNoteOpen=false } label: { Image(systemName:"xmark").frame(width:24,height:24) }
                    .buttonStyle(.plain).keyboardShortcut(.cancelAction).help("Close and keep draft").accessibilityLabel("Close quick note")
            }
            Label(store.heroes.first(where:{ $0.id == heroID })?.name ?? "Character unavailable",systemImage:"person.crop.circle")
                .font(.system(size:11,weight:.medium)).foregroundStyle(journalTint).lineLimit(1)
            ZStack(alignment:.topLeading) {
                if draft.wrappedValue.text.isEmpty {
                    Text("First line becomes the title.\nCapture a thought, lead, or reminder…")
                        .font(.system(size:13)).foregroundStyle(.secondary).padding(.horizontal,12).padding(.vertical,11).allowsHitTesting(false)
                }
                TextEditor(text:draft.text).font(.system(size:13)).scrollContentBackground(.hidden)
                    .focused($textFocused).padding(6).accessibilityLabel("Quick note text")
            }.frame(height:150).background(paper,in:RoundedRectangle(cornerRadius:8))
                .overlay(RoundedRectangle(cornerRadius:8).stroke(ink.opacity(0.12)))
            HStack(spacing:8) {
                Image(systemName:"tag").foregroundStyle(.secondary)
                TextField("Tags, separated by commas · optional",text:draft.tags).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Quick note tags")
            }
            HStack {
                Text("Draft kept when closed").font(.system(size:10)).foregroundStyle(.secondary)
                    .help("Unfinished drafts stay with their character while the app is open.")
                Spacer(minLength:8)
                Button("Add note") { store.commitQuickNote() }
                    .buttonStyle(PageButtonStyle(color:journalTint,prominent:true)).keyboardShortcut(.return,modifiers:.command)
                    .disabled(!draft.wrappedValue.canSave || !store.heroes.contains { $0.id == heroID })
                    .help("Add to journal · ⌘Return")
            }
        }.padding(18).frame(width:380).background(surface).foregroundStyle(ink).tint(journalTint)
            .onAppear { capture=store.quickNoteDrafts[heroID] ?? QuickNoteDraft() }
            .task { textFocused=true }
    }
}
