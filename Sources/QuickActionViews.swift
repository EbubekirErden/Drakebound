import SwiftUI

extension Store {
    func performAction(_ ref:SheetActionRef,heroID:UUID,mode:RollMode? = nil,slot:Int? = nil,critical:Bool = false) {
        guard let i = heroes.firstIndex(where:{ $0.id == heroID }) else { return }
        do { let result = try heroes[i].performAction(ref,manual:mode ?? rollMode,slot:slot,critical:critical); record(result) }
        catch { self.error = error.localizedDescription }
    }
}
struct ResourceCostPicker:View {
    @Binding var cost:ResourceCost?
    var hero:Hero
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            Picker("Spend resource",selection:Binding(get:{ cost?.resource },set:{ ref in cost = ref.map { ResourceCost(resource:$0,amount:cost?.amount ?? 1) } })) {
                Text("None · no counter spent").tag(Optional<ResourceRef>.none)
                if let ref = cost?.resource,hero.resource(ref) == nil { Text("Missing resource · choose another").tag(Optional(ref)) }
                ForEach(hero.resourceChoices) { choice in Text("\(choice.counter.name) · \(choice.counter.current)/\(choice.counter.maximum)").tag(Optional(choice.ref)) }
            }
            if cost != nil { Stepper("Cost: \(cost?.amount ?? 1)",value:Binding(get:{ cost?.amount ?? 1 },set:{ cost?.amount = $0 }),in:1...999) }
        }.font(.caption)
    }
}
struct ConcentrationChip:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var body:some View {
        if let spell = hero.concentratingSpell {
            HStack(spacing:7) {
                Label(spell.name,systemImage:"sparkle.magnifyingglass").lineLimit(1).help("Concentrating on \(spell.name). Damage creates a pending Constitution save in Health & recovery.")
                if !hero.concentrationSaves.isEmpty { Button("Save pending · \(hero.concentrationSaves.count)") { store.navigate(to:"Sheet") }.buttonStyle(.plain).foregroundStyle(gold).help("Resolve pending concentration saves in Health & recovery") }
                Button { hero.endConcentration() } label: { Label("End",systemImage:"xmark").font(.system(size:9,weight:.semibold)) }.buttonStyle(.plain).help("End concentration on \(spell.name)").accessibilityLabel("End concentration on \(spell.name)")
            }.font(.system(size:10,weight:.medium)).foregroundStyle(sky).padding(.horizontal,9).padding(.vertical,6).background(sky.opacity(0.09)).clipShape(Capsule()).overlay(Capsule().stroke(sky.opacity(0.65)))
        }
    }
}
struct SpellConcentrationMark:View {
    @Binding var hero:Hero
    var spell:Spell
    var body:some View {
        if hero.concentrationSpellID == spell.id {
            HStack(spacing:7) {
                Text("Concentrating").font(.system(size:9,weight:.semibold)).foregroundStyle(sky)
                Button { hero.endConcentration() } label: { Label("End",systemImage:"xmark").font(.system(size:9,weight:.medium)) }.buttonStyle(.plain).foregroundStyle(sky).help("End concentration on \(spell.name)").accessibilityLabel("End concentration on \(spell.name)")
            }
        } else if spell.requiresConcentration {
            Text("Concentration").font(.system(size:9,weight:.medium)).foregroundStyle(.secondary).padding(.horizontal,6).padding(.vertical,4).background(ink.opacity(0.04)).clipShape(Capsule()).help("Requires concentration · currently inactive. Casting starts concentration and replaces any previous concentration spell.")
        }
    }
}
enum ActionCategory:String,CaseIterable {
    case all = "All types",attacks = "Attacks",spells = "Spells",items = "Items",features = "Features",creatures = "Creatures"
    func includes(_ ref:SheetActionRef) -> Bool {
        switch self { case .all:return true; case .attacks:return ref.group.kind == .attack || ref.group.kind == .creatureAttack; case .spells:return ref.group.kind == .spell; case .items:return ref.group.kind == .itemRoll; case .features:return ref.group.kind == .featureUse || ref.group.kind == .creatureFeature; case .creatures:return ref.kind.isCreature }
    }
}
enum QuickActionFilter:String,CaseIterable { case frequent = "Frequent",recent = "Recent",all = "All" }
struct QuickActionsPanel:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var fullPage = false
    @State private var query = ""
    @FocusState private var searchFocused:Bool
    @State private var timing:ActionTiming?
    @State private var category = ActionCategory.all
    @State private var filter = QuickActionFilter.frequent
    @State private var expanded = false
    var actions:[SheetAction] {
        let all = hero.sheetActions.filter { category.includes($0.ref) && (timing == nil || hero.actionTiming($0.ref) == timing) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query)) }
        let usage = Dictionary(all.compactMap { action in hero.actionHistory(action.ref).map { (action.ref,$0) } },uniquingKeysWith:{ first,_ in first })
        if filter == .all { return all.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
        if filter == .recent { return all.filter { usage[$0.ref] != nil }.sorted { usage[$0.ref]!.lastUsed > usage[$1.ref]!.lastUsed } }
        return all.filter { hero.actionIsFavorite($0.ref) || usage[$0.ref] != nil }.sorted {
            let a = hero.actionIsFavorite($0.ref), b = hero.actionIsFavorite($1.ref)
            if a != b { return a }
            let ca = usage[$0.ref]?.count ?? 0,cb = usage[$1.ref]?.count ?? 0
            return ca == cb ? $0.name.localizedStandardCompare($1.name) == .orderedAscending:ca > cb
        }
    }
    var body:some View {
        Group {
            if fullPage {
                VStack(alignment:.leading,spacing:12) {
                    PageToolbar(title:"Actions",subtitle:"\(actions.count) \(actions.count == 1 ? "action":"actions") · attacks, spells, and abilities",searchTitle:"Search actions",query:$query,focus:$searchFocused) {
                        TipButton(topic:.actions).frame(width:PageControl.height,height:PageControl.height)
                    }
                    fullFilters
                    VStack(alignment:.leading,spacing:10) { actionContents }.padding(14).background(surface,in:RoundedRectangle(cornerRadius:9))
                }
            } else {
                Card(title:"Actions",tip:.actions) { compactFilters; actionContents }
            }
        }.onReceive(store.$commandRequest) { request in if let request,request.action == .search && store.activeTab == "Actions" && !store.showCompendium && store.consume(request) { searchFocused = true } }
    }
    private var compactFilters:some View {
        HStack(spacing:5) {
            ForEach(QuickActionFilter.allCases,id:\.self) { choice in
                Button { filter = choice; expanded = false } label: {
                    Text(choice.rawValue).font(.system(size:10,weight:.medium)).padding(.horizontal,11).frame(height:26)
                        .foregroundStyle(filter == choice ? paper:ink.opacity(0.7)).background(filter == choice ? accent:ink.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius:6))
                }.buttonStyle(.plain).accessibilityLabel(choice.rawValue+" actions").accessibilityAddTraits(filter == choice ? .isSelected:[])
            }
            Spacer(minLength:0)
            Text("\(actions.count) \(actions.count == 1 ? "action":"actions")").font(.caption2).foregroundStyle(.secondary)
        }.frame(height:26)
    }
    private var fullFilters:some View {
        ViewThatFits(in:.horizontal) {
            HStack(spacing:12) { filterSegments; categoryPicker; timingPicker; Spacer(minLength:0) }
            VStack(alignment:.leading,spacing:10) {
                filterSegments
                HStack(spacing:12) { categoryPicker; timingPicker; Spacer(minLength:0) }
            }
        }
    }
    private var filterSegments:some View {
        HStack(spacing:2) {
            ForEach(QuickActionFilter.allCases,id:\.self) { choice in
                Button { filter = choice; expanded = false } label: {
                    Text(choice.rawValue).font(.system(size:11,weight:.medium)).frame(width:80,height:PageControl.height-6)
                        .foregroundStyle(filter == choice ? paper:ink.opacity(0.7)).background(filter == choice ? accent:Color.clear).clipShape(RoundedRectangle(cornerRadius:6))
                }.buttonStyle(.plain).accessibilityLabel(choice.rawValue+" actions").accessibilityAddTraits(filter == choice ? .isSelected:[])
            }
        }.padding(3).background(surface).clipShape(RoundedRectangle(cornerRadius:8))
    }
    private var categoryPicker:some View {
        PagePicker(title:"Action type",selectionTitle:category.rawValue,selection:$category) {
            ForEach(ActionCategory.allCases,id:\.self) { Text($0.rawValue).tag($0) }
        }.frame(width:140)
    }
    private var timingPicker:some View {
        PagePicker(title:"Action timing",selectionTitle:timing?.rawValue ?? "All timings",selection:$timing) {
            Text("All timings").tag(Optional<ActionTiming>.none)
            ForEach(ActionTiming.allCases,id:\.self) { Text($0.rawValue).tag(Optional($0)) }
        }.frame(width:150)
    }
    @ViewBuilder private var actionContents:some View {
        if actions.isEmpty {
            if fullPage { CenteredEmptyState("No matching actions",systemImage:"bolt",description:Text(timing != nil || category != .all || !query.isEmpty ? "No actions match these filters. Try All timings or another type.":filter == .all ? "Prepared spells, ready attacks, custom rolls, and tracked feature uses appear here.":filter == .recent ? "Actions you use appear here.":"Use actions to build this list, or star favorites in All."),height:240) }
            else { Text(timing != nil || category != .all || !query.isEmpty ? "No actions match these filters. Try All timings or another type.":filter == .all ? "Prepared spells, ready attacks, custom rolls, and tracked feature uses appear here.":filter == .recent ? "Actions you use appear here.":"Use actions to build this list, or star favorites in All.").font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity).multilineTextAlignment(.center).padding(.vertical,4) }
        }
        LazyVGrid(columns:[GridItem(.adaptive(minimum:240),spacing:8)],spacing:8) {
            ForEach(fullPage || expanded ? actions:Array(actions.prefix(6))) { action in GroupedActionCard(hero:$hero,store:store,action:action) }
        }
        if !fullPage && actions.count > 6 { Button(expanded ? "Show fewer":"Show all \(actions.count)") { expanded.toggle() }.font(.caption).buttonStyle(.plain).foregroundStyle(accent) }
    }
}

struct GroupedActionCard:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var action:SheetAction
    @State private var selectedRollID:UUID?
    @State private var attackDetails = false
    @State private var costDetails = false
    var spell:Spell? { hero.spells.first { $0.id == action.ref.sourceID && action.ref.kind == .spell } }
    var attack:Attack? { hero.attacks.first { $0.id == action.ref.sourceID && action.ref.kind == .attack } }
    var creature:Creature? { hero.creatureSource(action.ref) }
    var creatureAttack:CreatureAttack? { hero.creatureAttack(action.ref) }
    var creatureFeature:CharacterFeature? { hero.creatureFeature(action.ref) }
    var rolls:[NamedRoll] { hero.quickRolls(action.ref) }
    var chosenRoll:NamedRoll? { rolls.first { $0.id == selectedRollID } ?? rolls.first }
    var slot:Int { chosenRoll?.slotLevel ?? spell.flatMap { hero.availableSlot(for:$0) } ?? spell?.level ?? 0 }
    var rollExpression:String { guard let roll = chosenRoll else { return "" }; return (try? hero.resolveRoll(roll.expression(spell:spell,slot:slot),spell:spell,slot:slot)) ?? roll.expression }
    var canUseFeature:Bool { (hero.featureEntries ?? []).contains { $0.id == action.ref.sourceID && ($0.counter != nil || $0.resourceCost != nil) } }
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            HStack(alignment:.top,spacing:8) {
                Button { hero.toggleActionFavorite(action.ref) } label: { Image(systemName:hero.actionIsFavorite(action.ref) ? "star.fill":"star").foregroundStyle(gold) }.buttonStyle(.plain).accessibilityLabel("Favorite "+action.name).help("Keep \(action.name) in Frequent")
                Button { openDetails() } label: {
                    VStack(alignment:.leading,spacing:4) {
                        Text(action.name).font(.system(size:11,weight:.semibold)).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading)
                        Text(action.subtitle).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).help("Open \(action.name) details")
                if let spell { CastControl(hero:$hero,store:store,spell:spell,compact:true) }
                else if creatureFeature != nil { Button("Use") { store.performAction(action.ref,heroID:hero.id) }.font(.system(size:11,weight:.semibold)).tint(leaf).disabled(creature?.hp == 0) }
                else if canUseFeature { Button("Use") { store.performAction(action.ref,heroID:hero.id) }.font(.system(size:11,weight:.semibold)).tint(accent) }
            }.frame(height:42,alignment:.top)
            Group {
            if let creatureAttack,let creature {
                HStack(spacing:8) {
                    if creatureAttack.resolution != .damage {
                        RollChoiceButton(explanation:creature.name+" attack · "+signed(creatureAttack.bonus)) { mode in store.performAction(action.ref,heroID:hero.id,mode:mode) } label: { rollField("Attack",signed(creatureAttack.bonus),sky) }
                    }
                    Button { store.performAction(SheetActionRef(kind:.creatureDamage,sourceID:creatureAttack.id,creatureID:creature.id),heroID:hero.id) } label: { rollField("Damage",creatureAttack.damage,coral) }.buttonStyle(.plain).accessibilityLabel(creature.name+" · "+creatureAttack.name+" damage")
                }.disabled(creature.hp == 0)
            } else if let creatureFeature {
                Text(creatureFeature.counter.map { "Uses \($0.current)/\($0.maximum)" } ?? "Open title for action details").font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1)
            } else if let attack {
                HStack(spacing:8) {
                    RollChoiceButton(explanation:hero.attackExplanation(attack)) { mode in store.performAction(action.ref,heroID:hero.id,mode:mode) } label: {
                        rollField("Attack",signed(hero.attackBonus(attack)+hero.testPenalty),sky)
                    }
                    Button { store.performAction(SheetActionRef(kind:.attackDamage,sourceID:attack.id),heroID:hero.id) } label: {
                        rollField("Damage",hero.expression(attack.damage,bonus:hero.damageBonus(attack),targets:hero.attackTargets(attack,damage:true)),coral)
                    }.buttonStyle(.plain).help(hero.damageExplanation(attack)).accessibilityLabel("\(attack.name) damage")
                }
            } else if let roll = chosenRoll {
                HStack(spacing:8) {
                    if rolls.count > 1 {
                        Picker("Roll option",selection:Binding(get:{ chosenRoll?.id ?? roll.id },set:{ selectedRollID = $0 })) {
                            ForEach(rolls) { option in Text(option.name+" · "+option.expression).tag(option.id) }
                        }.labelsHidden().font(.system(size:10)).frame(maxWidth:.infinity).accessibilityLabel(action.name+" roll option")
                    } else { Text(roll.name == "Roll" ? "Custom roll":roll.name).font(.system(size:10)).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading) }
                    RollChoiceButton(enabled:rollExpression.lowercased().hasPrefix("1d20"),explanation:"Roll \(rollExpression). This spends only the roll’s configured resource cost; it does not cast or spend a spell slot.") { mode in
                        let kind:SheetActionKind = spell != nil ? .spellRoll:action.ref.kind == .itemRoll ? .itemRoll:.featureRoll
                        store.performAction(SheetActionRef(kind:kind,sourceID:action.ref.sourceID,rollID:roll.id),heroID:hero.id,mode:mode,slot:slot)
                    } label: { Text("Roll "+rollExpression).font(.system(size:11,weight:.semibold,design:.monospaced)).foregroundStyle(sky).padding(7).background(sky.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:6)) }
                }
            } else if let spell {
                HStack { Text(spell.range).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1); Spacer(minLength:0) }
            } else { Color.clear }
            }.frame(maxWidth:.infinity).frame(height:28,alignment:.leading)
            HStack(spacing:6) {
                if chosenRoll != nil && spell != nil { Text("No slot spent").help("This roll is separate from casting and never spends a spell slot.").font(.system(size:9)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.85) }
                else if let attack { Text(attack.type).font(.system(size:9)).foregroundStyle(.secondary).lineLimit(1) }
                if attack == nil && creature == nil {
                    Button { costDetails.toggle() } label: { Label("Costs",systemImage:"info.circle").font(.system(size:9)) }.buttonStyle(.plain).foregroundStyle(.secondary).help("Show casting, use, and roll costs").accessibilityLabel(action.name+" costs")
                        .popover(isPresented:$costDetails) {
                            VStack(alignment:.leading,spacing:10) {
                                Text(action.name+" · costs").font(.headline)
                                Text(hero.actionCostDetails(action.ref)).font(.caption).fixedSize(horizontal:false,vertical:true)
                                if let roll = chosenRoll { Divider(); Text("Roll "+rollExpression).font(.caption.bold()); Text(roll.resourceCost.map { "Roll spends: "+hero.resourceSummary($0) } ?? "Roll: no resource cost").font(.caption); if spell != nil { Text("Rolling separately spends no spell slot.").font(.caption).foregroundStyle(.secondary) } }
                            }.padding(16).frame(width:320)
                        }
                }
                if let creature { Text(creature.name).font(.system(size:9)).foregroundStyle(leaf).lineLimit(1).help("Creature action · "+hero.actionTiming(action.ref).rawValue) }
                Spacer(minLength:0)
                if let creatureAttack,let creature,creatureAttack.resolution != .damage {
                    Button("Crit") { store.performAction(SheetActionRef(kind:.creatureDamage,sourceID:creatureAttack.id,creatureID:creature.id),heroID:hero.id,critical:true) }.font(.system(size:9,weight:.semibold)).buttonStyle(.plain).foregroundStyle(coral).disabled(creature.hp == 0)
                }
                if let attack {
                    Button("Crit") { store.performAction(SheetActionRef(kind:.attackDamage,sourceID:attack.id),heroID:hero.id,critical:true) }.font(.system(size:9,weight:.semibold)).buttonStyle(.plain).foregroundStyle(coral).help("Roll critical damage: double the damage dice, add flat modifiers once.").accessibilityLabel(attack.name+" critical damage")
                }
                if let spell { SpellConcentrationMark(hero:$hero,spell:spell) }
            }.frame(height:18)
        }.padding(10).frame(maxWidth:.infinity).frame(height:120,alignment:.topLeading).background(paper.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius:8)).modifier(ConcentrationOutline(active:hero.concentrationSpellID == action.ref.sourceID))
        .popover(isPresented:$attackDetails) {
            if let creatureAttack { AttackDescription(name:(creature?.name ?? "Creature")+" · "+creatureAttack.name,text:creatureAttack.description ?? "",edit:nil) }
            else if let creatureFeature { AttackDescription(name:(creature?.name ?? "Creature")+" · "+creatureFeature.name,text:creatureFeature.text,edit:nil) }
            else if let attack { AttackDescription(name:attack.name,text:attack.description ?? "",edit:nil) }
            else if let feature = hero.featureEntries?.first(where:{ $0.id == action.ref.sourceID }) { VStack(alignment:.leading,spacing:12) { Text(feature.name).font(.headline); ScrollView { Text(feature.text).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) } }.padding(18).frame(width:400,height:300) }
        }
    }
    func rollField(_ title:String,_ value:String,_ color:Color) -> some View {
        HStack(spacing:6) { Text(title).font(.system(size:10)).lineLimit(1).fixedSize(); Spacer(minLength:2); Text(value).font(.system(size:13,weight:.semibold,design:.monospaced)).lineLimit(1).minimumScaleFactor(0.65) }.foregroundStyle(color).padding(7).frame(maxWidth:.infinity).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:6))
    }
    func openDetails() {
        if let spell { store.openSpell(spell,hero:hero,ids:hero.spells.filter { $0.prepared || $0.level == 0 }.map(\.id)) }
        else if action.ref.kind == .itemRoll { store.itemDetail = ItemPresentation(heroID:hero.id,itemID:action.ref.sourceID,ids:hero.items.map(\.id)) }
        else { attackDetails = true }
    }
}

struct ActionTimingPicker:View {
    @Binding var timing:ActionTiming?
    var defaultLabel = "Unspecified"
    var body:some View {
        Picker("Action timing",selection:$timing) {
            Text(defaultLabel).tag(Optional<ActionTiming>.none)
            ForEach(ActionTiming.allCases,id:\.self) { option in Text(option.rawValue).tag(Optional(option)) }
        }.font(.caption).help("Controls the Action / Bonus action / Reaction filter in Actions.")
    }
}
