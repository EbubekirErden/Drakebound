import SwiftUI
import AppKit

struct WelcomeView:View {
    @ObservedObject var store:Store
    enum Path { case start,importCharacter,demo }
    @State private var path=Path.start
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack(spacing:12) {
                    BrandMark().frame(width:40,height:40)
                    Text("Drakebound").font(.system(size:22,weight:.semibold,design:.serif))
                    Spacer()
                    Text("Character companion").font(.system(size:12)).foregroundStyle(.secondary)
                }.padding(.bottom,12)
                if store.characterArchiveReadFailed { recovery }
                else {
                    switch path {
                    case .start: start
                    case .importCharacter: importCharacter
                    case .demo: demo
                    }
                }
                Divider().padding(.top,8)
                Label("Saved on this Mac. Export a JSON backup to keep a portable copy, including character images.",systemImage:"internaldrive")
                    .font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }.frame(maxWidth:900).padding(32).frame(maxWidth:.infinity,minHeight:560,alignment:.top)
        }.background(paper).foregroundStyle(ink).tint(accent)
    }
    private var start:some View {
        VStack(alignment:.leading,spacing:22) {
            heading("Your next adventure starts here","Create an adventurer, bring an existing character, or explore a ready-made example.")
            EqualHeightGridLayout(minimumColumnWidth:240,spacing:14) {
                WelcomeChoice(title:"Create a character",detail:"Choose your rules and origins, build your character, then review before saving.",actionTitle:"Start creating",icon:"person.badge.plus",color:accent) { store.addHero() }
                WelcomeChoice(title:"Import a character",detail:"Bring a Drakebound JSON backup or a Fight Club character XML file.",actionTitle:"Choose an import",icon:"square.and.arrow.down",color:sky) { path = .importCharacter }
                WelcomeChoice(title:"Explore a demo",detail:"Try a sample wizard with spells, equipment, and a journal. Entirely optional.",actionTitle:"Preview demo",icon:"sparkles",color:gold) { path = .demo }
            }
            VStack(alignment:.leading,spacing:10) {
                Text("Ready to play offline").font(.system(size:13,weight:.semibold))
                Text("Included SRD rules provide 12 core classes, their SRD subclasses, species, backgrounds, feats, spells, equipment, and creatures. No import is needed. Add your own references whenever you like.").font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Button { store.showCompendium=true } label: { Label("Browse compendium",systemImage:"books.vertical") }.buttonStyle(PageButtonStyle())
            }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(surface.opacity(0.55),in:RoundedRectangle(cornerRadius:10))
        }
    }
    private var importCharacter:some View {
        VStack(alignment:.leading,spacing:20) {
            back
            heading("Bring your character with you","Choose a supported file. Your original file stays unchanged.")
            VStack(alignment:.leading,spacing:18) {
                importRow("Drakebound JSON backup","Restores characters, their images, spells, equipment, and journal entries.",icon:"doc.text")
                Divider()
                importRow("Fight Club character XML","Imports character sheets. The journal includes an import review for any mappings to check.",icon:"person.text.rectangle")
            }.padding(20).background(surface,in:RoundedRectangle(cornerRadius:10))
            HStack {
                Button { store.importBackup() } label: { Label("Choose a file…",systemImage:"folder") }.buttonStyle(PageButtonStyle(color:sky,prominent:true))
                Text("JSON or XML").font(.system(size:11)).foregroundStyle(.secondary)
            }
            Text("Cancelling the file picker keeps you here. Reference-only files can be imported through the compendium.").font(.system(size:12)).foregroundStyle(.secondary)
        }
    }
    private var demo:some View {
        VStack(alignment:.leading,spacing:20) {
            back
            heading("Meet Aelar Windrunner","Explore a complete example before building your own character.")
            VStack(alignment:.leading,spacing:14) {
                Label("High elf · Level 5 Wizard",systemImage:"sparkles").font(.system(size:16,weight:.semibold)).foregroundStyle(sky)
                Text("Try spellcasting, equipment, action cards, and journal notes with sample data.").font(.system(size:13))
                Text("Opening the demo adds one editable character marked “demo”. You can remove it later or create your own alongside it.").font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(surface,in:RoundedRectangle(cornerRadius:10))
            Button { store.exploreWelcomeDemo() } label: { Label("Open demo character",systemImage:"play") }.buttonStyle(PageButtonStyle(color:gold,prominent:true))
        }
    }
    private var recovery:some View {
        VStack(alignment:.leading,spacing:20) {
            heading("Your saved characters need attention","Drakebound could not read the saved character file. It has been left untouched.")
            Text("Restore a verified backup in your data folder, then try again. Creating characters and saving are paused to protect the original file.").font(.system(size:13)).fixedSize(horizontal:false,vertical:true)
            HStack(spacing:10) {
                Button("Show data folder") { NSWorkspace.shared.activateFileViewerSelecting([store.file]) }.buttonStyle(PageButtonStyle())
                Button("Try again") { store.retryCharacterArchive() }.buttonStyle(PageButtonStyle(prominent:true))
            }
        }.padding(20).background(surface,in:RoundedRectangle(cornerRadius:10))
    }
    private var back:some View {
        Button { path = .start } label: { Label("Back",systemImage:"chevron.left") }.buttonStyle(PageButtonStyle())
    }
    private func heading(_ title:String,_ subtitle:String) -> some View {
        VStack(alignment:.leading,spacing:10) {
            Text(title).font(.system(size:28,weight:.semibold)).fixedSize(horizontal:false,vertical:true)
            Text(subtitle).font(.system(size:14)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
    private func importRow(_ title:String,_ detail:String,icon:String) -> some View {
        HStack(alignment:.top,spacing:12) {
            Image(systemName:icon).font(.system(size:19)).foregroundStyle(sky).frame(width:28)
            VStack(alignment:.leading,spacing:6) { Text(title).font(.system(size:14,weight:.semibold));Text(detail).font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
        }
    }
}

private struct WelcomeChoice:View {
    var title:String
    var detail:String
    var actionTitle:String
    var icon:String
    var color:Color
    var action:()->Void
    var body:some View {
        Button(action:action) {
            VStack(alignment:.leading,spacing:12) {
                Image(systemName:icon).font(.system(size:24)).foregroundStyle(color).frame(height:32)
                Text(title).font(.system(size:17,weight:.semibold)).foregroundStyle(ink)
                Text(detail).font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Spacer(minLength:12)
                HStack { Text(actionTitle);Spacer();Image(systemName:"arrow.right") }.font(.system(size:12,weight:.semibold)).foregroundStyle(color)
            }.padding(20).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
                .background(surface,in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(0.18)))
                .contentShape(RoundedRectangle(cornerRadius:12))
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityHint(detail)
    }
}
