import SwiftUI

struct JournalNoteEditor: View {
    @State var note: JournalEntry
    var isNew = false
    var onSave: (JournalEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text(isNew ? "New note":"Edit note").font(.system(size:20,weight:.semibold))
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(PageButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Save") { onSave(note); dismiss() }
                    .buttonStyle(PageButtonStyle(color:journalTint,prominent:true)).keyboardShortcut("s",modifiers:.command)
            }
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    TextField("Title",text:$note.title).font(.system(size:15,weight:.semibold)).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Note title")
                    JournalRichEditor(entry:$note)
                    PictureControls(data:$note.image,label:"Note image")
                }.padding(1)
            }
        }.padding(20).frame(width:680,height:570).background(surface).foregroundStyle(ink).tint(journalTint)
            .interactiveDismissDisabled()
    }
}
