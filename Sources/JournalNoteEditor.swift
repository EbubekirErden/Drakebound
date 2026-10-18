import SwiftUI

struct JournalNoteEditor: View {
    @State var note: JournalEntry
    var isNew = false
    var onSave: (JournalEntry) -> Void
    @State private var tagText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text(isNew ? "New note":"Edit note").font(.system(size:20,weight:.semibold))
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(PageButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Save") { note.tags = JournalEntry.parseTags(tagText); onSave(note); dismiss() }
                    .buttonStyle(PageButtonStyle(color:journalTint,prominent:true)).keyboardShortcut("s",modifiers:.command)
            }
            TextField("Title",text:$note.title).font(.system(size:15,weight:.semibold)).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Note title")
            HStack(spacing:10) {
                Label("Tags",systemImage:"tag").font(.caption).foregroundStyle(.secondary)
                TextField("Session, NPC, Location…",text:$tagText).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Note tags, separated by commas").help("Separate tags with commas. Use any names you like.")
            }
            JournalRichEditor(entry:$note).frame(maxHeight:.infinity)
            PictureControls(data:$note.image,label:"Note image",previewHeight:96)
        }.padding(20).frame(width:680,height:570).background(surface).foregroundStyle(ink).tint(journalTint)
            .interactiveDismissDisabled()
            .onAppear { tagText = note.normalizedTags.joined(separator:", ") }
    }
}
