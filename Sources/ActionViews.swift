import SwiftUI

struct RollListEditor: View {
    @Binding var rolls: [NamedRoll]?
    var hero: Hero
    var spell: Spell? = nil
    var allowsResourceCosts = true
    var list: Binding<[NamedRoll]> { Binding(get:{ rolls ?? [] },set:{ rolls = $0 }) }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            ForEach(list) { $roll in
                RollEditorRow(roll:$roll,hero:hero,spell:spell,allowsResourceCosts:allowsResourceCosts,remove:{ let id=roll.id;rolls?.removeAll { $0.id == id } })
                    .modifier(EditorRowStyle(index:list.wrappedValue.firstIndex { $0.id == roll.id } ?? 0))
            }
            HStack {
                Button("Add custom roll") { rolls = (rolls ?? []) + [NamedRoll()] }.help("Build a formula with dice and character values. Custom rolls do not apply HP or other effects automatically.")
                if let spell, spell.level > 0 && spell.level < 9 {
                    Button("Add upcast roll") {
                        let used = Set((rolls ?? []).compactMap(\.slotLevel))
                        guard let level = ((spell.level+1)...9).first(where:{ !used.contains($0) }) else { return }
                        let base = (rolls ?? []).first { $0.id == spell.automaticRollID } ?? rolls?.first
                        rolls = (rolls ?? []) + [NamedRoll(name:"Level \(level)",expression:base?.expression ?? "1d6",slotLevel:level)]
                    }.disabled(((spell.level+1)...9).allSatisfy { level in (rolls ?? []).contains { $0.slotLevel == level } })
                }
            }

        }.textFieldStyle(.roundedBorder)
    }
}
struct RollButtons: View {
    var rolls: [NamedRoll]?
    var hero: Hero
    @ObservedObject var store: Store
    var source: String
    var spell: Spell? = nil
    var slot = 0
    var actionSource:SheetActionRef? = nil
    var body: some View {
        if !(rolls ?? []).isEmpty {
            LazyVGrid(columns:[GridItem(.adaptive(minimum:180),alignment:.leading)],alignment:.leading,spacing:6) {
                ForEach(rolls ?? []) { roll in
                    let resolved = (try? hero.resolveRoll(roll.expression(spell:spell,slot:slot),spell:spell,slot:slot)) ?? roll.expression
                    let shown = resolved + (roll.kind != nil && hero.testPenalty != 0 ? signed(hero.testPenalty):"")
                    RollChoiceButton(enabled:resolved.lowercased().hasPrefix("1d20"),explanation:roll.name+": "+shown+(roll.resourceCost.map { "\nSpends "+hero.resourceSummary($0) } ?? "")) { mode in if var ref = actionSource { ref.rollID = roll.id; store.performAction(ref,heroID:hero.id,mode:mode,slot:slot) } else { do { store.record(try hero.performNamedRoll(roll,source:source,spell:spell,slot:slot,manual:mode ?? store.rollMode)) } catch { store.error = error.localizedDescription } } } label: {
                        HStack(spacing:9) {
                            Image(systemName:"dice").foregroundStyle(sky)
                            VStack(alignment:.leading,spacing:4) {
                                if roll.name != "Roll" { Text(roll.name).font(.system(size:10,weight:.medium)).foregroundStyle(.secondary) }
                                Text(shown + (roll.damageLabel.isEmpty ? "":" · " + roll.damageLabel)).font(.system(size:13,weight:.semibold,design:.monospaced)).foregroundStyle(ink)
                                if let range = Dice.bounds(shown) { Text("\(range.lowerBound)–\(range.upperBound) range").font(.system(size:10)).foregroundStyle(.secondary) }
                            }; Spacer(minLength:0)
                        }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(sky.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(sky.opacity(0.18)))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
struct FeaturePanel: View {
    @Binding var hero: Hero
    @ObservedObject var store: Store
    @State var editing: CharacterFeature?
    @State private var filter:FeatureCategory?
    @State private var browseFeats=false
    @State private var expanded:Set<UUID> = []
    var body: some View {
        Card(title:"Features & traits") {
            HStack(spacing:6) {
                Button("All") { filter = nil }.tint(filter == nil ? accent:Color.gray)
                ForEach(FeatureCategory.allCases,id:\.self) { category in Button(category.rawValue) { filter = category }.tint(filter == category ? accent:Color.gray) }
                Spacer();Button { browseFeats=true } label: { Label("Browse feats",systemImage:"books.vertical") }.popover(isPresented:$browseFeats) { FeatQuickAdd(hero:$hero,entries:store.compendium.filter { $0.category == .feat }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) }; Button { editing = CharacterFeature(category:filter ?? .other) } label: { Label("Feature",systemImage:"plus") }.buttonStyle(.plain).foregroundStyle(accent)
            }.font(.system(size:10))
            ForEach(FeatureCategory.allCases,id:\.self) { category in
                let entries = (hero.featureEntries ?? []).filter { ($0.category ?? .other) == category }
                if !entries.isEmpty && (filter == nil || filter == category) {
                    Text("\(category.rawValue) · \(entries.count)").font(.system(size:11,weight:.semibold)).foregroundStyle(gold).padding(.top,8)
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:10),count:min(2,max(1,entries.count))),alignment:.leading,spacing:10) {
                        ForEach(SelectionRules.outline(entries)) { row in
                            let feature=row.feature
                            VStack(alignment:.leading,spacing:10) {
                                HStack(alignment:.top) {
                                    Button { if expanded.contains(feature.id) { expanded.remove(feature.id) } else { expanded.insert(feature.id) } } label: {
                                        HStack(alignment:.top,spacing:8) { Image(systemName:expanded.contains(feature.id) ? "chevron.down":"chevron.right").font(.system(size:9)).padding(.top,3); VStack(alignment:.leading,spacing:5) { Text(feature.name).font(.system(size:13,weight:.medium)); if let parent=(hero.featureEntries ?? []).first(where:{ $0.id == feature.parentFeatureID }) { Text("↳ "+parent.name).font(.caption2).foregroundStyle(accent) }; if let source = feature.source, !source.isEmpty { Text(source).font(.system(size:9)).foregroundStyle(sky) } }; Spacer(minLength:0) }.contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                    Button { editing = feature } label: { Image(systemName:"pencil") }.buttonStyle(.plain).help("Edit feature, source, uses, and rolls")
                                }
                                if !feature.text.isEmpty { Text(DescriptionMarkdown.attributed(feature.text)).font(.system(size:11)).foregroundStyle(expanded.contains(feature.id) ? ink:Color.secondary).lineLimit(expanded.contains(feature.id) ? nil:2).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }
                                ForEach(feature.resolvedEffects.filter(\.enabled)) { effect in Text(featureEffectSummary(effect,level:hero.level)).font(.caption).foregroundStyle(leaf) }
                                if let counter = feature.counter {
                                    HStack(spacing:8) { Text("Uses \(counter.current) / \(counter.maximum)").font(.caption).foregroundStyle(gold); Button { changeUses(feature,-1) } label: { Image(systemName:"minus") }.disabled(counter.current == 0); Button { changeUses(feature,1) } label: { Image(systemName:"plus") }.disabled(counter.current >= counter.maximum); Spacer(minLength:0) }.font(.caption)
                                    Text(counter.resetSummary).font(.caption2).foregroundStyle(.secondary)
                                }
                                if feature.counter != nil || feature.resourceCost != nil { HStack { Button("Use feature") { store.performAction(SheetActionRef(kind:.featureUse,sourceID:feature.id),heroID:hero.id) }; if let cost = feature.resourceCost { Text(hero.resourceSummary(cost)).font(.caption2).foregroundStyle(gold) }; Spacer() }.font(.caption) }
                                RollButtons(rolls:feature.rolls,hero:hero,store:store,source:feature.name,actionSource:SheetActionRef(kind:.featureRoll,sourceID:feature.id))
                            }.padding(12).frame(maxWidth:.infinity,alignment:.topLeading).background(paper.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius:8))
                        }
                    }
                }
            }
        }.sheet(item:$editing) { feature in FeatureEditor(feature:feature,hero:hero,onSave:{ updated in var all = hero.featureEntries ?? []; if let i = all.firstIndex(where:{ $0.id == updated.id }) { all[i] = updated } else { all.append(updated) }; hero.replaceFeatures(all) },onDelete:{ hero.replaceFeatures((hero.featureEntries ?? []).filter { $0.id != feature.id }) }) }
    }
    func changeUses(_ feature:CharacterFeature,_ delta:Int) { guard let i = hero.featureEntries?.firstIndex(where:{ $0.id == feature.id }), let counter = feature.counter else { return }; hero.featureEntries?[i].counter?.current = min(counter.maximum,max(0,counter.current+delta)) }
}
struct FeatureEditor:View {
    @State var feature:CharacterFeature
    var hero:Hero
    var allowDelete = true
    var onSave:(CharacterFeature)->Void
    var onDelete:()->Void
    @State private var saveToCompendium = false
    @Environment(\.templateSaveAction) private var saveTemplate
    @Environment(\.dismiss) var dismiss
    var valid:Bool { validFeatureEffects(feature) && !feature.name.trimmingCharacters(in:.whitespaces).isEmpty && validRolls(feature.rolls,hero:hero) && (feature.counter == nil || ((1...999).contains(feature.counter!.maximum) && (0...max(0,feature.counter!.maximum)).contains(feature.counter!.current))) }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Feature").font(.system(size:20,weight:.semibold)); Spacer(); Button("Cancel") { dismiss() }.buttonStyle(PageButtonStyle()); Button("Save") { if saveToCompendium { saveTemplate?(TemplateFactory.feature(feature)) }; onSave(feature); dismiss() }.buttonStyle(PageButtonStyle(prominent:true)).disabled(!valid) }
            SaveTemplateToggle(selected:$saveToCompendium)
            ScrollView { VStack(spacing:12) {
                EditorGroup(title:"Identity & source") { TextField("Feature name",text:$feature.name); HStack { Picker("Category",selection:Binding(get:{ feature.category ?? .other },set:{ feature.category = $0 })) { ForEach(FeatureCategory.allCases,id:\.self) { Text($0.rawValue).tag($0) } }; TextField("Source · race, class, book",text:Binding(get:{ feature.source ?? "" },set:{ feature.source = $0 })) } }
                EditorGroup(title:"Description") { BorderedTextEditor(text:$feature.text,height:120,markdown:true) }
                EditorColumns {
                    EditorGroup(title:"Organization & timing") {
                Picker("Group under feature",selection:$feature.parentFeatureID) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(SelectionRules.parentOptions(for:feature,in:hero.featureEntries ?? [])) { parent in Text(parent.name).tag(Optional(parent.id)) }
                }.help("Groups this feature visually under another feature. Resources and effects remain independent.")
                ActionTimingPicker(timing:$feature.timing)
                    }
                EditorGroup(title:"Uses & recovery") { Toggle("Track uses",isOn:Binding(get:{ feature.counter != nil },set:{ feature.counter = $0 ? ResourceCounter(name:feature.name):nil })); if feature.counter != nil { let counter = Binding(get:{ feature.counter ?? ResourceCounter() },set:{ feature.counter = $0 }); HStack { EditorField(title:"Maximum") { TextField("Maximum",value:counter.maximum,format:.number) }; EditorField(title:"Remaining") { TextField("Remaining",value:counter.current,format:.number) } }; CounterResetPicker(counter:counter) } }
                EditorGroup(title:"Linked resource") { ResourceCostPicker(cost:$feature.resourceCost,hero:hero); Text("Use feature spends this cost and one tracked use, if enabled. Custom rolls spend only the resource configured on that roll.").font(.caption2).foregroundStyle(.secondary) }
                } trailing: {
                    FeatureEffectsEditor(feature:$feature,hero:hero)
                    TrainingGrantEditor(grants:$feature.training,source:feature.name)
                }
                EditorGroup(title:"Custom rolls") { RollListEditor(rolls:$feature.rolls,hero:hero) }
                if allowDelete { HStack { Button("Remove feature",role:.destructive) { onDelete(); dismiss() }; Spacer() } }
            } }
        }.padding(20).modifier(CustomEditorFrame()).textFieldStyle(.roundedBorder).tint(accent)
    }
}
struct SpellEditor:View {
    @State var spell:Spell
    var hero:Hero
    var isCompendium = false
    var classOptions:[String] = []
    var onSave:(Spell)->Void
    @State private var saveToCompendium = false
    @Environment(\.templateSaveAction) private var saveTemplate
    @Environment(\.dismiss) var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Spell").font(.system(size:20,weight:.semibold)); Spacer(); Button("Cancel") { dismiss() }.buttonStyle(PageButtonStyle()); Button("Save spell") { if !(spell.rolls ?? []).contains(where:{ $0.id == spell.automaticRollID }) { spell.automaticRollID = nil }; if saveToCompendium { saveTemplate?(TemplateFactory.spell(spell)) }; onSave(spell); dismiss() }.buttonStyle(PageButtonStyle(color:sky,prominent:true)).disabled(spell.name.trimmingCharacters(in:.whitespaces).isEmpty || !validRolls(spell.rolls,hero:hero,spell:spell)) }
            SaveTemplateToggle(selected:$saveToCompendium)
            ScrollView { VStack(spacing:12) {
                EditorGroup(title:"Identity") {
                    HStack(alignment:.bottom,spacing:14) {
                        EditorField(title:"Name") { TextField("Spell name",text:$spell.name) }
                        Stepper(spell.level == 0 ? "Cantrip":"Level \(spell.level)",value:$spell.level,in:0...9).frame(width:130,height:28)
                        EditorField(title:"School") { OptionField(title:"School",value:$spell.school,choices:spellSchoolChoices) }.frame(width:190)
                    }
                }
                EditorGroup(title:"Description") { BorderedTextEditor(text:$spell.text,height:110,markdown:true) }
                EditorColumns(equalHeight:true) {
                    EditorGroup(title:"Casting details",fillHeight:true) {
                    HStack { EditorField(title:"Casting time") { OptionField(title:"Casting time",value:$spell.time,choices:["1 action","1 bonus action","1 reaction","1 minute","10 minutes","1 hour","8 hours"]) }; EditorField(title:"Range") { OptionField(title:"Range",value:$spell.range,choices:["Self","Touch","30 feet","60 feet","90 feet","120 feet","150 feet","300 feet","1 mile","Sight","Unlimited"]) } }
                    HStack { EditorField(title:"Duration") { OptionField(title:"Duration",value:$spell.duration,choices:["Instantaneous","1 round","1 minute","10 minutes","1 hour","8 hours","24 hours","Until dispelled","Concentration, up to 1 minute","Concentration, up to 10 minutes","Concentration, up to 1 hour"]) }; EditorField(title:"Components") { SpellComponentButtons(value:$spell.components) } }
                    SpellMaterialField(components:$spell.components)
                    }
                } trailing: {
                EditorGroup(title:"Casting",fillHeight:true) {
                    SpellClassSelector(classes:Binding(get:{ spell.classes ?? "" },set:{ spell.classes = $0 }),options:classOptions + hero.progressionClasses.map(\.name))
                    HStack { Toggle("Ritual",isOn:Binding(get:{ spell.ritual ?? false },set:{ spell.ritual = $0 })); Toggle("Requires concentration",isOn:Binding(get:{ spell.requiresConcentration },set:{ spell.concentration = $0 })) }
                    if !isCompendium {
                        Picker("Cast as class",selection:Binding(get:{ spell.sourceClassID },set:{ id in spell.sourceClassID = id; if let record = hero.progressionClasses.first(where:{ $0.id == id }) { spell.sourceClassName = record.name; spell.castingAbility = ClassProfile.named(record.name)?.casting ?? hero.castingAbility } else { spell.sourceClassName = nil } })) {
                            Text("Custom / default ability").tag(Optional<UUID>.none)
                            ForEach(hero.progressionClasses) { record in Text("\(record.name) · \(record.level)").tag(Optional(record.id)) }
                        }
                        if let source = spell.sourceClassName { Text("Casting source: \(source)").font(.caption2).foregroundStyle(sky) }
                        HStack { Toggle("Prepared",isOn:$spell.prepared); if spell.level > 0 { Toggle("Uses slot",isOn:Binding(get:{ spell.usesSlot ?? true },set:{ spell.usesSlot = $0 })) } }
                        Toggle(isOn:Binding(get:{ spell.exemptFromClassLimit ?? false },set:{ spell.exemptFromClassLimit = $0 })) { Text("Extra / always-prepared spell · exclude from class allowance").fixedSize(horizontal:false,vertical:true) }
                        ResourceCostPicker(cost:$spell.resourceCost,hero:hero)
                        Text("A linked resource is spent on casting, in addition to any spell slot or free use. Automatic rolls also spend their own configured cost.").font(.caption2).foregroundStyle(.secondary)
                        Picker("Casting ability",selection:Binding(get:{ spell.castingAbility ?? hero.castingAbility },set:{ spell.castingAbility = $0 })) { ForEach(0..<6,id:\.self) { Text(abilities[$0]).tag($0) } }
                        Stepper("Free uses per long rest: \(spell.freeUses ?? 0)",value:Binding(get:{ spell.freeUses ?? 0 },set:{ spell.freeUses = $0; spell.freeRemaining = min(spell.freeRemaining ?? $0,$0) }),in:0...999)
                        if (spell.freeUses ?? 0) > 0 { Stepper("Remaining: \(spell.freeRemaining ?? spell.freeUses ?? 0)",value:Binding(get:{ spell.freeRemaining ?? spell.freeUses ?? 0 },set:{ spell.freeRemaining = $0 }),in:0...(spell.freeUses ?? 0)) }
                    }
                }
                }
                EditorGroup(title:spell.level == 0 ? "Cantrip scaling & custom rolls":"Upcasting & custom rolls") {
                    if spell.level > 0 {
                        Text("Add a base damage roll, then enable automatic upcasting on that roll.").font(.caption).foregroundStyle(.secondary)
                    }
                    RollListEditor(rolls:$spell.rolls,hero:hero,spell:spell,allowsResourceCosts:!isCompendium)
                    Picker("Roll when cast",selection:$spell.automaticRollID) { Text("None · log casting").tag(Optional<UUID>.none); ForEach(spell.rolls ?? []) { Text($0.name).tag(Optional($0.id)) } }
                    Text(spell.level == 0 ? "Cantrip tiers use character levels. Set each roll’s level requirement below its formula.":"Automatic upcasting uses the casting slot. Select that damage roll in Roll when cast to roll it during casting. Separate rolls spend no slot.").font(.caption2).foregroundStyle(.secondary)
                }
            } }
        }.padding(20).modifier(CustomEditorFrame()).textFieldStyle(.roundedBorder).tint(sky)
    }
}

struct CastControl: View {
    @Binding var hero: Hero
    @ObservedObject var store: Store
    var spell: Spell
    var compact = false
    @State private var choosing = false
    var title:String { spell.level > 0 && spell.usesSlot == false ? "Use":"Cast" }
    func cast(_ mode:CastMode,_ level:Int? = nil,_ tier:Int? = nil) {
        choosing = false
        do { store.record(try hero.cast(spell.id,mode:mode,at:level,cantripLevel:spell.level == 0 ? (tier ?? hero.level):nil)) }
        catch { store.error = error.localizedDescription }
    }
    var body: some View {
        Button { cast(hero.defaultCastMode(spell)) } label: {
            Text(title).font(.system(size:11,weight:.semibold)).foregroundStyle(sky).padding(.horizontal,12).frame(height:26).background(sky.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:6)).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .highPriorityGesture(LongPressGesture(minimumDuration:0.65).exclusively(before:TapGesture()).onEnded { value in
            switch value { case .first:choosing = true; case .second:cast(hero.defaultCastMode(spell)) }
        })
        .contextMenu { castingChoices }
        .popover(isPresented:$choosing,arrowEdge:.bottom) {
            VStack(alignment:.leading,spacing:12) {
                Text(spell.name).font(.headline).lineLimit(2)
                Text("Casting options").font(.caption).foregroundStyle(.secondary)
                ScrollView { VStack(alignment:.leading,spacing:7) { castingChoices }.frame(maxWidth:.infinity,alignment:.leading) }.frame(maxHeight:270)
                Text("Choosing an option casts immediately. Opening this panel spends nothing.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }.padding(16).frame(width:285).tint(sky)
        }
        .help((spell.level == 0 ? "Click to cast without a slot":spell.usesSlot == false ? "Click to use without a spell slot":"Click to cast using the lowest available slot")+" · hold or right-click for casting options")
        .accessibilityLabel(title+" "+spell.name)
        .modifier(PreparedCasting(prepared:spell.prepared))
    }
    func castDamage(at slot: Int) -> String {
        guard let roll = (spell.rolls ?? []).first(where:{ $0.id == spell.automaticRollID }), let expression = try? hero.resolveRoll(roll.expression(spell:spell,slot:slot),spell:spell,slot:slot) else { return "" }
        return " · " + expression + (roll.damageLabel.isEmpty ? "":" " + roll.damageLabel)
    }
    @ViewBuilder var castingChoices:some View {
        if spell.level == 0 {
            Button("Cast cantrip · no slot") { cast(.slot) }
            ForEach((spell.rolls ?? []).filter { $0.minimumCharacterLevel != nil }) { roll in
                Button("Character level \(roll.minimumCharacterLevel ?? 1)+ · \(roll.expression)") { cast(.slot,nil,roll.minimumCharacterLevel) }
            }
        } else {
            ForEach(Array(spell.level...9).filter { !compact || hero.slots[$0-1] > 0 },id:\.self) { level in
                Button("Level \(level) · \(max(0,hero.slots[level-1]-hero.usedSlots[level-1])) left" + castDamage(at:level)) { cast(.slot,level) }.disabled(hero.slots[level-1] <= hero.usedSlots[level-1])
            }
            if compact && !(spell.level...9).contains(where:{ hero.slots[$0-1] > 0 }) { Text("No spell slots configured").font(.caption).foregroundStyle(.secondary) }
            if spell.ritual == true { Divider(); Button("Cast as ritual · no slot") { cast(.ritual) } }
            if spell.usesSlot == false || (spell.freeUses ?? 0) > 0 {
                Button("Free use\((spell.freeUses ?? 0) > 0 ? " · \(spell.freeRemaining ?? spell.freeUses ?? 0) left":"")") { cast(.free) }
                    .disabled((spell.freeUses ?? 0) > 0 && (spell.freeRemaining ?? spell.freeUses ?? 0) <= 0)
            }
        }
    }
}
struct SlotManager: View {
    @Binding var hero: Hero
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment:.leading,spacing:18) { HStack { Text("Spell slots").font(.headline); Spacer(); Button("Done") { dismiss() } }; Text("Set totals and expended slots explicitly. This does not take a long rest.").font(.caption).foregroundStyle(.secondary); Form { ForEach(0..<9,id:\.self) { i in VStack(alignment:.leading,spacing:5) { Stepper("Level \(i+1) total: \(hero.slots[i])",value:$hero.slots[i],in:0...20); Stepper("Used: \(hero.usedSlots[i]) · remaining: \(max(0,hero.slots[i]-hero.usedSlots[i]))",value:$hero.usedSlots[i],in:0...20) } } }.formStyle(.grouped).editorBorder() }.padding(22).frame(width:470,height:650).tint(sky)
    }
}
struct SpellDetails: View {
    @Binding var hero: Hero
    @ObservedObject var store: Store
    var original: Spell
    var library: Bool
    var navigationIDs:[UUID] = []
    var onClose:()->Void
    @State private var browsingID:UUID?
    @State var editing = false
    @State var slots = false
    @State var castLevel = 1
    @State private var cantripLevel = 1
    @State var message = ""
    var spell: Spell { (library ? store.library:hero.spells).first { $0.id == (browsingID ?? original.id) } ?? original }
    var browseIDs:[UUID] { navigationIDs.isEmpty ? (library ? store.library:hero.spells).map(\.id):navigationIDs }
    var position:Int { browseIDs.firstIndex(of:spell.id) ?? 0 }
    var ownedSpell:Spell? { hero.spells.first { $0.id == spell.id || $0.name.caseInsensitiveCompare(spell.name) == .orderedSame } }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Button { navigate(-1) } label: { Image(systemName:"chevron.left") }.disabled(position == 0).help("Previous spell").keyboardShortcut(.leftArrow,modifiers:[])
                Text("\(position+1) / \(browseIDs.count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                Button { navigate(1) } label: { Image(systemName:"chevron.right") }.disabled(position >= browseIDs.count-1).help("Next spell").keyboardShortcut(.rightArrow,modifiers:[])
                Spacer(); Button("Edit") { editing = true }; Button("Done",action:onClose)
            }
            HStack { Text(spell.name).font(.system(size:23,weight:.semibold)); if !library { SpellConcentrationMark(hero:$hero,spell:spell) }; Spacer()
                if !library || ownedSpell != nil { Button { let id = library ? ownedSpell?.id:spell.id; if let i = hero.spells.firstIndex(where:{ $0.id == id }) { hero.spells[i].prepared.toggle() } } label: { Label((library ? ownedSpell?.prepared:spell.prepared) == true ? "Prepared":"Not prepared",systemImage:(library ? ownedSpell?.prepared:spell.prepared) == true ? "checkmark.circle.fill":"circle").font(.caption).foregroundStyle((library ? ownedSpell?.prepared:spell.prepared) == true ? accent:Color.secondary) }.buttonStyle(.plain) }
                else { Text("Not in spellbook").font(.caption).foregroundStyle(.secondary) }
            }
            if !library,let source = spell.sourceClassName { Text("Casting as \(source)").font(.caption2).foregroundStyle(accent) }
            if !library,let cost = spell.resourceCost { Text("Casting spends "+hero.resourceSummary(cost)).font(.caption2).foregroundStyle(gold) }
            Text(spell.level == 0 ? "\(spell.school) cantrip":"Level \(spell.level) · \(spell.school)").font(.caption).foregroundStyle(sky)
            Text("\(spell.time) · \(spell.range)\n\(spell.components) · \(spell.duration)").font(.system(size:12)).lineSpacing(5)
            ScrollView { VStack(alignment:.leading,spacing:18) { Text(DescriptionMarkdown.attributed(spell.text)).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading); if !(spell.rolls ?? []).isEmpty { Text("CUSTOM ROLLS").font(.system(size:10,weight:.semibold)).foregroundStyle(sky); RollButtons(rolls:spell.rolls,hero:hero,store:store,source:spell.name,spell:spell,slot:spell.level == 0 ? 0:castLevel,actionSource:library ? nil:SheetActionRef(kind:.spellRoll,sourceID:spell.id)); Text(spell.level == 0 && hero.cantripRoll(spell,at:hero.level) != nil ? "Cast uses the selected character-level tier. Each formula can also be rolled separately without casting.":"Rolls are separate from casting unless an automatic roll is configured.").font(.caption2).foregroundStyle(.secondary) } } }.id(spell.id)
            Divider()
            if library {
                Button("Add to character…") { store.compendiumAdd = CompendiumAddRequest(picks:[CompendiumPick(spell:spell)]) }.disabled(store.heroes.isEmpty)
            } else {
                if spell.level > 0 {
                    HStack { Picker("Slot level",selection:$castLevel) { ForEach(spell.level...9,id:\.self) { level in Text("\(level) · \(max(0,hero.slots[level-1]-hero.usedSlots[level-1])) left").tag(level) } }; Button("Manage slots") { slots = true } }
                    if hero.availableSlot(for:spell) == nil { Text("No spell slots remain for this spell. Take a long rest or use Manage slots to restore a slot. Configured rituals and free uses still work.").font(.caption).foregroundStyle(gold) }
                    HStack { Button("Cast at level \(castLevel)") { cast(.slot) }.buttonStyle(.borderedProminent); if spell.ritual == true { Button("Ritual") { cast(.ritual) } }; if spell.usesSlot == false || (spell.freeUses ?? 0) > 0 { Button("Free use") { cast(.free) } } }.modifier(PreparedCasting(prepared:spell.prepared))
                } else {
                    if (spell.rolls ?? []).contains(where:{ $0.minimumCharacterLevel != nil }) {
                        Picker("Cantrip strength",selection:$cantripLevel) { ForEach((spell.rolls ?? []).filter { $0.minimumCharacterLevel != nil }) { roll in Text("Character level \(roll.minimumCharacterLevel ?? 1)+ · \(roll.expression)").tag(roll.minimumCharacterLevel ?? 1) } }
                        Text("Character-level scaling · no spell slot. Your level: \(hero.level).").font(.caption2).foregroundStyle(.secondary)
                    }
                    Button(hero.cantripRoll(spell,at:cantripLevel).map { "Cast & roll \($0.expression)" } ?? "Cast cantrip") { cast(.slot) }.buttonStyle(.borderedProminent).modifier(PreparedCasting(prepared:spell.prepared))
                }
                if !spell.prepared { Text("Not prepared · prepare this spell above to cast it.").font(.caption2).foregroundStyle(.secondary) }
                if !message.isEmpty { Text(message).font(.caption).foregroundStyle(gold) }
            }
        }.padding(22).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).modifier(ConcentrationOutline(active:!library && hero.concentrationSpellID == spell.id)).tint(sky)
        .onAppear { castLevel = hero.availableSlot(for:spell) ?? max(1,spell.level); cantripLevel = hero.cantripRoll(spell,at:hero.level)?.minimumCharacterLevel ?? 1 }
        .sheet(isPresented:$editing) { SpellEditor(spell:spell,hero:hero,isCompendium:library,classOptions:store.compendium.filter { $0.category == .classEntry }.map(\.name)) { updated in if library { if let entry = store.compendium.first(where:{ $0.id == updated.id && $0.custom == true }) { var copy = TemplateFactory.spell(updated); copy.id = entry.id; store.upsertTemplate(copy) } else if let i = store.library.firstIndex(where:{ $0.id == updated.id }) { store.library[i] = updated; store.save() } } else if let i = hero.spells.firstIndex(where:{ $0.id == updated.id }) { hero.spells[i] = updated } } }
        .sheet(isPresented:$slots) { SlotManager(hero:$hero) }
    }
    func navigate(_ direction:Int) { let next = position+direction; guard browseIDs.indices.contains(next) else { return }; browsingID = browseIDs[next]; castLevel = hero.availableSlot(for:spell) ?? max(1,spell.level); message = ""; cantripLevel = hero.cantripRoll(spell,at:hero.level)?.minimumCharacterLevel ?? 1 }
    func cast(_ mode:CastMode) { do { let result = try hero.cast(spell.id,mode:mode,at:castLevel,cantripLevel:spell.level == 0 ? cantripLevel:nil); store.record(result); message = result.event ? result.expression : "Rolled \(result.expression) = \(result.total)" } catch { message = error.localizedDescription } }
}
