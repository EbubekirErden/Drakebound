import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PDFExportView:View {
    var hero:Hero
    @State private var options = CharacterPDFOptions()
    @State private var saved:URL?
    @State private var failure:String?
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Label("Export character PDF",systemImage:"doc.richtext").font(.headline); Spacer(); Button("Done") { dismiss() } }
            Text(hero.name).font(.title2.bold())
            Text("Two-page play sheet: character essentials on page one, spellbook on page two.").font(.caption).foregroundStyle(.secondary)
            Picker("Paper",selection:$options.letter) { Text("A4").tag(false); Text("US Letter").tag(true) }.pickerStyle(.segmented)
            VStack(alignment:.leading,spacing:10) {
                Toggle("Spell reference appendix",isOn:$options.spellDescriptions)
                Toggle("Feature reference appendix",isOn:$options.featureDescriptions)
                Toggle("Equipment reference appendix",isOn:$options.equipmentDescriptions)
                Toggle("Creature appendix",isOn:$options.creatures)
                Toggle("Journal appendix",isOn:$options.journal)
            }.font(.system(size:12)).padding(14).frame(maxWidth:.infinity,alignment:.leading).background(surface).clipShape(RoundedRectangle(cornerRadius:8))
            Text("Appendices are optional extra pages. The compact sheet lists key features and carried equipment; very large lists show an overflow count.").font(.caption2).foregroundStyle(.secondary)
            if let failure { Text(failure).font(.caption).foregroundStyle(coral) }
            HStack {
                if let saved { Button("Open PDF") { NSWorkspace.shared.open(saved) } }
                Spacer()
                Button("Save PDF…") { save() }.buttonStyle(.borderedProminent)
            }
        }.padding(22).frame(width:440).tint(accent)
    }
    func save() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = hero.name.replacingOccurrences(of:"/",with:"-")+" - Character sheet.pdf"
        guard panel.runModal() == .OK,let url = panel.url else { return }
        do { let data = try CharacterPDF.data(for:hero,options:options); try data.write(to:url,options:.atomic); saved = url; failure = nil }
        catch { failure = "Could not export PDF. "+error.localizedDescription }
    }
}
