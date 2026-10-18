import SwiftUI

private struct TemplateSaveKey:EnvironmentKey { static let defaultValue:((CompendiumEntry)->Void)? = nil }
extension EnvironmentValues {
    var templateSaveAction:((CompendiumEntry)->Void)? { get { self[TemplateSaveKey.self] } set { self[TemplateSaveKey.self] = newValue } }
}
struct SaveTemplateToggle:View {
    @Binding var selected:Bool
    @Environment(\.templateSaveAction) var save
    var body:some View { if save != nil { Toggle("Also save a reusable copy to Compendium",isOn:$selected).font(.caption).help("The compendium copy is saved with this editor. Character copies remain independent.") } }
}
struct ReferenceTemplateEditor:View {
    @State var draft:ReferenceTemplateDraft
    var onSave:(CompendiumEntry)->Void
    @Environment(\.dismiss) var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Custom \(draft.category == .race ? "ancestry":draft.category == .background ? "background":"class")").font(.title2.bold()); Spacer(); Button("Cancel") { dismiss() }; Button("Save") { onSave(draft.entry); dismiss() }.buttonStyle(.borderedProminent).disabled(!draft.issues.isEmpty) }
            ScrollView { VStack(spacing:12) {
                EditorGroup(title:"Identity & rules") {
                    TextField("Name",text:$draft.name)
                    if draft.category == .race {
                        HStack { Picker("Size",selection:value("size")) { ForEach(["T","S","M","L","H","G"],id:\.self) { Text(["T":"Tiny","S":"Small","M":"Medium","L":"Large","H":"Huge","G":"Gargantuan"][$0]!).tag($0) } }; EditorField(title:"Creature type") { TextField("Creature type",text:value("type")) }; EditorField(title:"Speed · ft") { TextField("Speed",text:value("speed")) }.frame(width:80) }
                        TextField("Ability increases or choices · describe the rule",text:value("ability"))
                    }
                    if draft.category == .classEntry {
                        HStack { Picker("Hit die",selection:value("hd")) { ForEach([6,8,10,12],id:\.self) { Text("d\($0)").tag(String($0)) } }; EditorField(title:"Starting skill choices") { TextField("Skill choices",text:value("numSkills")) } }
                        TextField("Starting saves and allowed skills, separated by commas",text:value("proficiency")); TextField("Spellcasting ability",text:value("spellAbility"))
                        Text("For subclasses, add a subclass heading at its grant level (e.g. Wizard Subclass: Diviner), then assign that subclass to its features.").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        DisclosureGroup("Granted skills · \(selectedSkills.count) selected") {
                        LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],alignment:.leading,spacing:7) { ForEach(skills,id:\.0) { skill in Toggle(skill.0,isOn:Binding(get:{ selectedSkills.contains(skill.0) },set:{ add in var set = selectedSkills; if add { set.insert(skill.0) } else { set.remove(skill.0) }; draft.values["proficiency"] = set.sorted().joined(separator:", ") })).toggleStyle(.checkbox).font(.system(size:11)) } }
                        }.font(.caption)
                        TextField("Languages & tools",text:value("training"))
                    }
                }
                EditorGroup(title:"Features & traits") {
                    ForEach($draft.traits) { $trait in VStack(spacing:8) {
                        HStack { TextField("Feature title",text:$trait.name); Button { draft.traits.removeAll { $0.id == trait.id } } label: { Image(systemName:"minus.circle") } }
                        if draft.category == .classEntry { HStack { Stepper("Class level \(trait.level)",value:$trait.level,in:1...20); TextField("Subclass · blank for core",text:$trait.subclass); Toggle("Optional",isOn:$trait.optional) }.font(.caption) }
                        BorderedTextEditor(text:$trait.text,height:75)
                    }.padding(10).background(surface).clipShape(RoundedRectangle(cornerRadius:7)) }
                    Button("Add feature") { draft.traits.append(TemplateTrait()) }
                }
            } }
            if let issue = draft.issues.first { Text(issue).font(.caption).foregroundStyle(gold) }
        }.padding(20).frame(width:640,height:660).background(paper).foregroundStyle(ink).textFieldStyle(.roundedBorder).tint(accent)
    }
    var selectedSkills:Set<String> { Set(draft.values["proficiency",default:""].components(separatedBy:",").map { $0.trimmingCharacters(in:.whitespaces) }.filter { !$0.isEmpty }) }
    func value(_ key:String) -> Binding<String> { Binding(get:{ draft.values[key] ?? "" },set:{ draft.values[key] = $0 }) }
}
struct CompendiumCreation:Identifiable { var id = UUID(); var category:CompendiumCategory; var original:CompendiumEntry? }
struct CompendiumCreator:View {
    var session:CompendiumCreation
    var hero:Hero
    var save:(CompendiumEntry)->Void
    var body:some View {
        Group {
            switch session.category {
            case .spell: SpellEditor(spell:session.original?.spell() ?? Spell(name:"",level:0),hero:hero) { complete(TemplateFactory.spell($0)) }
            case .item: ItemEditor(item:session.original?.item() ?? Item(name:""),hero:hero) { complete(TemplateFactory.item($0)) }
            case .monster: CreatureEditor(creature:session.original?.creature() ?? Creature(name:"")) { complete(TemplateFactory.creature($0)) }
            case .feat: FeatureEditor(feature:session.original?.featureCopies().first ?? CharacterFeature(name:"",category:.feat),hero:hero,onSave:{ complete(TemplateFactory.feature($0)) },onDelete:{})
            default: ReferenceTemplateEditor(draft:referenceDraft) { complete($0) }
            }
        }.environment(\.templateSaveAction,nil)
    }
    func complete(_ incoming:CompendiumEntry) { var entry = incoming; if session.original?.custom == true { entry.id = session.original!.id }; save(entry) }
    var referenceDraft:ReferenceTemplateDraft {
        var draft = ReferenceTemplateDraft(category:session.category)
        guard let original = session.original else { return draft }
        draft.name = original.name; draft.values = Dictionary(original.fields.filter { $0.children.isEmpty && $0.name != "name" }.map { ($0.name,$0.text) },uniquingKeysWith:{ first,_ in first })
        let fields = session.category == .classEntry ? original.fields.filter { $0.name == "autolevel" }:original.fields.filter { $0.name == "trait" }
        draft.traits = fields.flatMap { field -> [TemplateTrait] in
            let nodes = session.category == .classEntry ? field.children.filter { $0.name == "feature" }:[field]
            return nodes.map { node in TemplateTrait(name:node.children.first { $0.name == "name" }?.text ?? "Feature",text:node.children.filter { $0.name != "name" }.map(\.readable).joined(separator:"\n\n"),level:Int(field.attributes["level"] ?? "1") ?? 1,subclass:node.attributes["subclass"] ?? "",optional:node.attributes["optional"] == "YES") }
        }
        return draft
    }
}
struct TrainingGrantEditor:View {
    @Binding var grants:[TrainingGrant]?
    var source:String
    var body:some View {
        DisclosureGroup("Training granted by this feature") {
            Text("Multiple proficiency sources count once. Expertise uses twice your proficiency bonus; separate numeric bonuses still add.").font(.caption2).foregroundStyle(.secondary).padding(.vertical,6)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:8) { ForEach(skills,id:\.0) { skill in HStack { Text(skill.0).font(.system(size:11)); Spacer(); Picker(skill.0,selection:rank("skill."+skill.0)) { Text("None").tag(0); Text("Proficient").tag(1); Text("Expertise").tag(2) }.labelsHidden().frame(width:102) } } }
            HStack { ForEach(0..<6,id:\.self) { i in Toggle(String(abilities[i].prefix(3)),isOn:Binding(get:{ (grants ?? []).contains { $0.target == "save.\(i)" } },set:{ set("save.\(i)",$0 ? 1:0) })).toggleStyle(.checkbox).font(.caption2) } }.padding(.top,8)
        }.font(.caption)
    }
    func rank(_ target:String) -> Binding<Int> { Binding(get:{ grants?.first { $0.target == target }?.rank ?? 0 },set:{ set(target,$0) }) }
    func set(_ target:String,_ rank:Int) { var list = grants ?? []; list.removeAll { $0.target == target }; if rank > 0 { list.append(TrainingGrant(target:target,rank:rank,source:source)) }; grants = list }
}
