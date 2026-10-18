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
        ControlFlowLayout(spacing:10) {
            filterSegments;categoryPicker;timingPicker
            if !query.isEmpty || category != .all || timing != nil {
                Button("Clear filters") { query="";category = .all;timing=nil;expanded=false }.buttonStyle(PageButtonStyle())
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
            VStack(spacing:10) {
                if fullPage { CenteredEmptyState(emptyTitle,systemImage:"bolt",description:Text(emptyMessage),height:190) }
                else { Text(emptyMessage).font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity).multilineTextAlignment(.center).padding(.vertical,4) }
                if filter != .all || timing != nil || category != .all || !query.isEmpty {
                    Button("Show all actions") { filter = .all;timing=nil;category = .all;query="";expanded=true }.buttonStyle(PageButtonStyle(prominent:true)).accessibilityLabel("Show all actions")
                }
            }.frame(maxWidth:.infinity).padding(.bottom,8)
        }
        LazyVGrid(columns:[GridItem(.adaptive(minimum:240),spacing:8,alignment:.top)],spacing:8) {
            ForEach(fullPage || expanded ? actions:Array(actions.prefix(6))) { action in GroupedActionCard(hero:$hero,store:store,action:action) }
        }
        if !fullPage && actions.count > 6 { Button(expanded ? "Show fewer":"Show all \(actions.count)") { expanded.toggle() }.font(.caption).buttonStyle(.plain).foregroundStyle(accent) }
    }
    private var emptyTitle:String {
        if timing != nil || category != .all || !query.isEmpty { return "No matching actions" }
        switch filter { case .frequent:return "No frequent actions yet";case .recent:return "No recent actions yet";case .all:return "No actions available" }
    }
    private var emptyMessage:String {
        if timing != nil || category != .all || !query.isEmpty { return "Try another search, type, or timing, or show all actions." }
        switch filter {
        case .frequent:return "Use an action or star it in All to keep it here."
        case .recent:return "Actions you use will appear here. Browse All to get started."
        case .all:return "Prepared spells, ready attacks, custom rolls, and tracked feature uses appear here."
        }
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
        VStack(alignment:.leading,spacing:10) {
            HStack(alignment:.top,spacing:8) {
                Image(systemName:cardIcon).font(.system(size:15,weight:.medium)).foregroundStyle(cardColor).frame(width:30,height:30).background(cardColor.opacity(0.12),in:RoundedRectangle(cornerRadius:8))
                Button { openDetails() } label: {
                    VStack(alignment:.leading,spacing:4) {
                        Text(action.name).font(.system(size:13,weight:.semibold)).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading)
                        Text(action.subtitle).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).help("Open \(action.name) details")
                Button { hero.toggleActionFavorite(action.ref) } label: { Image(systemName:hero.actionIsFavorite(action.ref) ? "star.fill":"star").foregroundStyle(gold) }.buttonStyle(.plain).accessibilityLabel("Favorite "+action.name).help("Keep \(action.name) in Frequent")
                if let spell { CastControl(hero:$hero,store:store,spell:spell,compact:true) }
                else if creatureFeature != nil { Button("Use") { store.performAction(action.ref,heroID:hero.id) }.font(.system(size:11,weight:.semibold)).tint(leaf).disabled(creature?.hp == 0) }
                else if canUseFeature { Button("Use") { store.performAction(action.ref,heroID:hero.id) }.font(.system(size:11,weight:.semibold)).tint(accent) }
            }.frame(minHeight:34,alignment:.top)
            Group {
            if let creatureAttack,let creature {
                HStack(spacing:8) {
                    if creatureAttack.resolution != .damage {
                        RollChoiceButton(explanation:creature.name+" attack · "+signed(creatureAttack.bonus)) { mode in store.performAction(action.ref,heroID:hero.id,mode:mode) } label: { rollField("Attack",signed(creatureAttack.bonus),sky) }
                    }
                    Button { store.performAction(SheetActionRef(kind:.creatureDamage,sourceID:creatureAttack.id,creatureID:creature.id),heroID:hero.id) } label: { rollField("Damage",creatureAttack.damage,coral) }.buttonStyle(.plain).accessibilityLabel(creature.name+" · "+creatureAttack.name+" damage")
                }.disabled(creature.hp == 0)
            } else if let creatureFeature {
                VStack(alignment:.leading,spacing:6) {
                    if let counter=creatureFeature.counter { Text("Uses \(counter.current)/\(counter.maximum)").font(.system(size:12,weight:.medium)).foregroundStyle(leaf) }
                    excerpt(creatureFeature.text)
                }
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
                VStack(alignment:.leading,spacing:8) {
                    HStack(spacing:8) { detailField("Range",spell.range);detailField("Duration",spell.duration) }
                    excerpt(spell.text)
                }
            } else if let feature=hero.featureEntries?.first(where:{ $0.id == action.ref.sourceID }) { excerpt(feature.text) }
            else if let item=hero.items.first(where:{ $0.id == action.ref.sourceID }) { excerpt(item.notes) }
            }.frame(maxWidth:.infinity,alignment:.leading)
            HStack(spacing:6) {
                if chosenRoll != nil && spell != nil { Text("No slot spent").help("This roll is separate from casting and never spends a spell slot.").font(.system(size:9)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.85) }
                else if let attack { Text(attack.type).font(.system(size:9)).foregroundStyle(.secondary).lineLimit(1) }
                if attack == nil && creature == nil {
                    Button { costDetails.toggle() } label: { Label("Costs",systemImage:"info.circle").font(.system(size:11)) }.buttonStyle(.plain).foregroundStyle(.secondary).help("Show casting, use, and roll costs").accessibilityLabel(action.name+" costs")
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
            }.frame(minHeight:20)
        }.padding(12).frame(maxWidth:.infinity,alignment:.topLeading).background(paper.opacity(0.65),in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(cardColor.opacity(0.18))).modifier(ConcentrationOutline(active:hero.concentrationSpellID == action.ref.sourceID))
        .popover(isPresented:$attackDetails) {
            if let creatureAttack { AttackDescription(name:(creature?.name ?? "Creature")+" · "+creatureAttack.name,text:creatureAttack.description ?? "",edit:nil) }
            else if let creatureFeature { AttackDescription(name:(creature?.name ?? "Creature")+" · "+creatureFeature.name,text:creatureFeature.text,edit:nil) }
            else if let attack { AttackDescription(name:attack.name,text:attack.description ?? "",edit:nil) }
            else if let feature = hero.featureEntries?.first(where:{ $0.id == action.ref.sourceID }) { VStack(alignment:.leading,spacing:12) { Text(feature.name).font(.headline); ScrollView { Text(DescriptionMarkdown.attributed(feature.text)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) } }.padding(18).frame(width:400,height:300) }
        }
    }
    private var cardColor:Color { if creature != nil { return leaf };if attack != nil { return coral };if spell != nil { return sky };return action.ref.kind == .itemRoll ? gold:accent }
    private var cardIcon:String { if creature != nil { return "pawprint" };if attack != nil { return "scope" };if spell != nil { return "sparkles" };return action.ref.kind == .itemRoll ? "backpack":"bolt.shield" }
    private func excerpt(_ text:String)->some View {
        Text(DescriptionMarkdown.attributed(String(text.prefix(600)))).font(.system(size:11)).foregroundStyle(ink.opacity(0.75)).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading)
    }
    private func detailField(_ title:String,_ value:String)->some View {
        VStack(alignment:.leading,spacing:4) { Text(title.uppercased()).font(.system(size:9,weight:.medium)).foregroundStyle(.secondary);Text(value).font(.system(size:12,weight:.medium)).lineLimit(2) }.frame(maxWidth:.infinity,alignment:.leading).padding(8).background(ink.opacity(0.035),in:RoundedRectangle(cornerRadius:6))
    }
    func rollField(_ title:String,_ value:String,_ color:Color) -> some View {
        VStack(alignment:.leading,spacing:4) { Text(title.uppercased()).font(.system(size:9,weight:.semibold)).foregroundStyle(.secondary);Text(value).font(.system(size:18,weight:.semibold,design:.monospaced)).lineLimit(1).minimumScaleFactor(0.65) }.foregroundStyle(color).padding(9).frame(maxWidth:.infinity,alignment:.leading).background(color.opacity(0.09),in:RoundedRectangle(cornerRadius:7))
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
