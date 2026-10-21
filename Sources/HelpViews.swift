import SwiftUI

enum HelpTopic:String,CaseIterable,Identifiable {
    case health,actions,inventory,journal,creatures,shortcuts
    var id:String { rawValue }
    var title:String { switch self { case .health:return "Health & recovery"; case .actions:return "Actions & casting"; case .inventory:return "Equipment & resources"; case .journal:return "Journal"; case .creatures:return "Creatures"; case .shortcuts:return "Keyboard shortcuts" } }
    var text:String {
        switch self {
        case .health:return "Click Damage, Heal, or Temp HP to enter an amount. Temporary HP absorbs damage first and does not stack.\n\nThe small death-save tile opens successes, failures, and a save roll. Rolling is available at 0 HP until three successes or failures. A natural 1 adds two failures; a natural 20 restores 1 HP. You can adjust the tracks manually for your table.\n\nHit dice and Rest open recovery choices. Counters refill only on rests you assigned."
        case .actions:return "Click an attack or roll to use it. Hold or right-click a d20 control for advantage or disadvantage.\n\nClick Cast for the default cast; hold or right-click Cast for slot levels, rituals, free uses, or cantrip strength. Opening options spends nothing. A separate Roll button never spends a spell slot. Costs explains configured resource costs.\n\nCombat brings health, conditions, concentration, attacks, prepared spells and resources together. Filter by type or timing, search, or star an action and turn on Favorites. No turn allowance is consumed automatically."
        case .inventory:return "Equip a weapon to show its linked attack in ready actions. Stowed weapons stay saved.\n\nUse containers to organize carried items. Configure effects and attunement explicitly; descriptions do not apply bonuses automatically.\n\nCounters and feature uses can reset on independently selected short, long, or full rests. Custom rolls may spend a linked resource."
        case .journal:return "Click a note title or arrow to expand it. Use the pencil to edit, then Save or Cancel. The editor supports formatting, links, lists, images, and tags.\n\nQuick note (⇧⌘J) captures text and optional tags without leaving your page. Add note or ⌘Return saves it to the displayed character’s journal. Closing keeps the draft while the app is open."
        case .creatures:return "Dismiss moves a summon into the compact inactive list without changing its HP, attacks, image, or notes. Summon brings it back. Companions stay active until you deactivate them.\n\nYou can also change Active in play in the creature editor. Activity does not automatically spend a counter or follow concentration."
        case .shortcuts:return "⌘1–⌘6: Sheet, Combat, Equipment, Spells, Journal, Creatures\n⌘7: Compendium\n⌘K: Search everything\n⌘F: Search the current supported page\n⌘D: Enter a dice formula\n⌘N: New character\n⇧⌘J: Quick note · ⌘Return to add\n⇧⌘R: Rest & recovery\n\nJournal: ⌘B bold, ⌘I italic. The macOS menus list other shortcuts."
        }
    }
}
struct TipButton:View {
    var topic:HelpTopic
    @AppStorage("showContextualTips") private var enabled = true
    @AppStorage("dismissedHelpTopics") private var dismissed = ""
    @State private var open = false
    var body:some View {
        if enabled && !dismissed.split(separator:",").contains(Substring(topic.rawValue)) {
            Button { open = true } label: { Image(systemName:"questionmark.circle").font(.system(size:11)).foregroundStyle(.secondary).frame(width:22,height:20).contentShape(Rectangle()) }.buttonStyle(.plain).help("Tips for "+topic.title).accessibilityLabel(topic.title+" tips")
                .popover(isPresented:$open) {
                    VStack(alignment:.leading,spacing:12) {
                        HStack { Text(topic.title).font(.headline); Spacer(); Button { open = false } label: { Image(systemName:"xmark") }.buttonStyle(.plain).accessibilityLabel("Close tip") }
                        Text(topic.text).font(.caption).fixedSize(horizontal:false,vertical:true)
                        HStack { Button("Hide this tip") { dismissed += (dismissed.isEmpty ? "":",")+topic.rawValue; open = false }; Spacer(); Button("Done") { open = false } }.font(.caption)
                    }.padding(18).frame(width:330)
                }
        }
    }
}
struct TipsLibrary:View {
    @AppStorage("showContextualTips") private var enabled = true
    @AppStorage("dismissedHelpTopics") private var dismissed = ""
    @State private var selected = HelpTopic.actions
    @Environment(\.dismiss) private var close
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("Tips & shortcuts").font(.title2.bold()); Spacer(); Button("Done") { close() } }
            HStack(alignment:.top,spacing:18) {
                VStack(alignment:.leading,spacing:5) { ForEach(HelpTopic.allCases) { topic in Button { selected = topic } label: { Text(topic.title).font(.caption).frame(maxWidth:.infinity,alignment:.leading).padding(8).background(selected == topic ? accent.opacity(0.12):.clear).clipShape(RoundedRectangle(cornerRadius:6)) }.buttonStyle(.plain) } }.frame(width:165)
                ScrollView { VStack(alignment:.leading,spacing:14) { Text(selected.title).font(.headline); Text(selected.text).font(.system(size:12)).lineSpacing(4).textSelection(.enabled) }.frame(maxWidth:.infinity,alignment:.leading) }
            }
            Divider()
            HStack { Toggle("Show tip buttons",isOn:$enabled).toggleStyle(.checkbox); Spacer(); Button("Restore hidden tips") { dismissed = ""; enabled = true } }.font(.caption)
        }.padding(22).frame(width:650,height:430).tint(accent)
    }
}
