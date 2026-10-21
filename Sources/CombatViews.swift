import SwiftUI

struct CombatPanel:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var width:CGFloat
    var rest:()->Void
    @State private var query = ""
    @State private var favorites = false
    @State private var category = ActionCategory.all
    @State private var timing:ActionTiming?
    @FocusState private var searching:Bool
    var actions:[SheetAction] {
        hero.sheetActions.filter { action in
            category.includes(action.ref) && (!favorites || hero.actionIsFavorite(action.ref)) &&
            (timing == nil || hero.actionTiming(action.ref) == timing) &&
            CompendiumSearch.matches(name:action.name,summary:action.subtitle,classes:"",source:"",query:query)
        }.sorted { first,second in
            let a = hero.actionIsFavorite(first.ref),b = hero.actionIsFavorite(second.ref)
            return a == b ? first.name.localizedStandardCompare(second.name) == .orderedAscending:a
        }
    }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            CombatVitals(hero:$hero,store:store,rest:rest)
            if width >= 560 {
                HStack(alignment:.top,spacing:16) {
                    actionList.frame(maxWidth:.infinity)
                    support.frame(width:width >= 850 ? 280:224)
                }
            } else {
                support
                actionList
            }
        }.onReceive(store.$commandRequest) { request in
            if let request,request.action == .search,store.activeTab == "Combat",!store.showCompendium,store.consume(request) { searching = true }
        }
    }
    @ViewBuilder var support:some View {
        VStack(alignment:.leading,spacing:14) { CombatConditions(hero:$hero);CombatSaves(hero:$hero,store:store);slots;resources }
    }
    @ViewBuilder var slots:some View {
        if hero.slots.contains(where:{ $0 > 0 }) { SpellSlotGrid(hero:$hero,manage:nil) }
    }
    @ViewBuilder var resources:some View {
        if !hero.resourceChoices.isEmpty { CombatResources(hero:$hero) }
    }
    var actionList:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:12) {
                Text("Ready actions · \(actions.count)").font(.system(size:12,weight:.semibold)).fixedSize()
                Spacer(minLength:8)
                PageSearchField(title:"Find an attack, spell or ability",query:$query,focus:$searching).frame(maxWidth:280)
                Button { favorites.toggle() } label: { Image(systemName:favorites ? "star.fill":"star").foregroundStyle(gold) }.buttonStyle(.plain).frame(width:26,height:30).accessibilityLabel("Show favorite combat actions").accessibilityValue(favorites ? "On":"Off").help("Show favorites")
            }
            ControlFlowLayout(spacing:8) {
                PagePicker(title:"Combat actions",selectionTitle:category.rawValue,selection:$category) {
                    ForEach(ActionCategory.allCases,id:\.self) { Text($0 == .creatures ? "Companions":$0.rawValue).tag($0) }
                }
                PagePicker(title:"Action timing",selectionTitle:timing?.rawValue ?? "All timings",selection:$timing) {
                    Text("All timings").tag(Optional<ActionTiming>.none)
                    ForEach(ActionTiming.allCases,id:\.self) { Text($0.rawValue).tag(Optional($0)) }
                }
                if !query.isEmpty || favorites || timing != nil || category != .all {
                    Button("Clear") { query="";favorites=false;timing=nil;category = .all }.buttonStyle(.plain).font(.system(size:12)).foregroundStyle(accent)
                }
            }
            VStack(spacing:0) {
                ForEach([ActionCategory.attacks,.spells,.features,.items,.creatures],id:\.self) { group in
                    let members = actions.filter { group == .creatures ? $0.ref.kind.isCreature:!$0.ref.kind.isCreature && group.includes($0.ref) }
                    if !members.isEmpty {
                        CombatSectionHeading(title:group == .creatures ? "Companions":group.rawValue,count:members.count,color:group == .attacks ? coral:group == .spells ? sky:group == .items ? gold:accent)
                        ForEach(members) { action in
                            CombatActionRow(hero:$hero,store:store,action:action)
                            Divider().opacity(0.4).padding(.horizontal,12)
                        }
                    }
                }
                if actions.isEmpty {
                    VStack(spacing:8) {
                        Text(favorites ? "No matching favorites":"No ready actions found").font(.system(size:13,weight:.semibold))
                        Text("Equip weapons, prepare spells, or add a feature with uses or rolls. Clear filters to see everything ready.").font(.system(size:12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth:.infinity).padding(24)
                }
            }.background(surface,in:RoundedRectangle(cornerRadius:10))
                .overlay(RoundedRectangle(cornerRadius:10).stroke(ink.opacity(0.07)))
        }
    }
}

struct CombatSectionHeading:View {
    var title:String
    var count:Int
    var color:Color
    var body:some View {
        HStack { Text(title.uppercased()).tracking(1);Text("\(count)").foregroundStyle(.secondary);Spacer() }
            .font(.system(size:10,weight:.semibold)).foregroundStyle(color).padding(.horizontal,12).padding(.top,14).padding(.bottom,8)
    }
}

struct CombatVitals:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var rest:()->Void
    @State private var adjustment:HealthAdjustment?
    @State private var hitDice = false
    @State private var breakdown = false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:16) {
                VStack(alignment:.leading,spacing:6) {
                    HStack(alignment:.firstTextBaseline,spacing:5) {
                        Text("\(hero.hp)").font(.system(size:30,weight:.semibold,design:.rounded)).foregroundStyle(healthColor(hero.hp,hero.maximumHP)).monospacedDigit()
                        Text("/ \(hero.maximumHP) HP").font(.system(size:12)).foregroundStyle(.secondary)
                        Button { breakdown=true } label: { Image(systemName:"questionmark.circle").font(.system(size:12)).foregroundStyle(ink.opacity(0.6)) }.buttonStyle(.plain).accessibilityLabel("Maximum HP breakdown")
                            .popover(isPresented:$breakdown) { Text(hero.maximumHPExplanation).font(.system(size:12)).textSelection(.enabled).padding(16).frame(width:280) }
                    }
                    HealthBar(hp:hero.hp,maximum:hero.maximumHP,height:5)
                }.frame(minWidth:130,maxWidth:.infinity)
                stat("AC","\(hero.armorClass)",explanation:hero.armorClassExplanation)
                RollChoiceButton(explanation:hero.initiativeExplanation) { mode in
                    store.rollTyped(hero.expression("1d20",bonus:hero.initiative,targets:["initiative","checks","check.1"]),"Initiative",hero:hero,kind:.initiative,ability:1,mode:mode)
                } label: { stat("INIT",signed(hero.initiative+hero.testPenalty),explanation:"Roll initiative") }
                stat("SPEED","\(hero.movement)",explanation:"Current movement speed")
                if hero.slots.contains(where:{ $0 > 0 }) || !hero.spells.isEmpty { stat("SAVE DC","\(hero.spellDC)",explanation:hero.spellDCExplanation) }
            }
            ControlFlowLayout(spacing:8) {
                Button { adjustment = .damage } label: { Label("Damage",systemImage:"minus") }.buttonStyle(PageButtonStyle(color:coral)).foregroundStyle(coral)
                Button { adjustment = .healing } label: { Label("Heal",systemImage:"plus") }.buttonStyle(PageButtonStyle(color:leaf)).foregroundStyle(leaf)
                Button { adjustment = .temporary } label: { Text("Temp HP · \(hero.tempHP)").monospacedDigit() }.buttonStyle(PageButtonStyle()).foregroundStyle(sky)
                Button { hitDice=true } label: { Label("Hit dice · \(max(0,hero.level-hero.hitDiceUsed))/\(hero.level)",systemImage:"dice") }.buttonStyle(PageButtonStyle())
                    .popover(isPresented:$hitDice) { HitDicePopup(hero:$hero,store:store) }
                Button { hero.inspiration.toggle() } label: { Image(systemName:hero.inspiration ? "sparkles":"sparkle").foregroundStyle(hero.inspiration ? gold:.secondary) }.buttonStyle(PageButtonStyle()).accessibilityLabel("Inspiration").accessibilityValue(hero.inspiration ? "Available":"Not available")
                Button("Rest…",action:rest).buttonStyle(PageButtonStyle())
            }
            if hero.hp == 0 || hero.deathSuccesses > 0 || hero.deathFailures > 0 { DeathSaveControl(hero:$hero,store:store) }
            if hero.concentratingSpell != nil { ConcentrationChip(hero:$hero,store:store) }
            ConcentrationSavePrompt(hero:$hero,store:store)
        }.padding(14).background(surface,in:RoundedRectangle(cornerRadius:10))
            .overlay(RoundedRectangle(cornerRadius:10).stroke(ink.opacity(0.08)))
            .popover(item:$adjustment) { HealthAmountPopup(hero:$hero,adjustment:$0) }
    }
    func stat(_ title:String,_ value:String,explanation:String)->some View {
        VStack(spacing:4) {
            Text(title).font(.system(size:9,weight:.semibold)).foregroundStyle(.secondary)
            Text(value).font(.system(size:21,weight:.medium,design:.rounded)).monospacedDigit()
        }.frame(minWidth:55).help(explanation)
    }
}

struct CombatConditions:View {
    @Binding var hero:Hero
    @State private var manage = false
    var body:some View {
        ControlFlowLayout(spacing:8) {
            Button { manage=true } label: { Label("Conditions",systemImage:"waveform.path.ecg") }.buttonStyle(.plain).font(.system(size:12,weight:.medium)).foregroundStyle(accent)
            if hero.conditions.isEmpty && (hero.exhaustionLevel ?? 0) == 0 { Text("None active").font(.system(size:11)).foregroundStyle(.secondary) }
            ForEach(hero.conditions,id:\.self) { name in
                Button { hero.conditions.removeAll { $0 == name } } label: { Label(name,systemImage:"xmark").font(.system(size:11)).padding(.horizontal,8).padding(.vertical,5).background(coral.opacity(0.1),in:Capsule()) }.buttonStyle(.plain).foregroundStyle(coral).help("Remove "+name)
            }
            PagePicker(title:"Exhaustion level",selectionTitle:"Exhaustion · \(hero.exhaustionLevel ?? 0)",selection:Binding(get:{ hero.exhaustionLevel ?? 0 },set:{ hero.exhaustionLevel=$0 })) {
                ForEach(0...6,id:\.self) { Text($0 == 0 ? "None":"Level \($0)").tag($0) }
            }
        }.padding(.horizontal,3).sheet(isPresented:$manage) { ConditionsEditor(hero:$hero) }
    }
}

struct CombatResources:View {
    @Binding var hero:Hero
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text("RESOURCES").font(.system(size:10,weight:.semibold)).tracking(1).foregroundStyle(gold)
            ForEach(hero.resourceChoices) { choice in
                HStack(spacing:10) {
                    Text(choice.counter.name).font(.system(size:12)).fixedSize(horizontal:false,vertical:true)
                    Spacer(minLength:4)
                    Text("\(choice.counter.current)/\(choice.counter.maximum)").font(.system(size:12,weight:.semibold,design:.rounded)).monospacedDigit()
                    Button { change(choice,-1) } label: { Image(systemName:"minus") }.disabled(choice.counter.current == 0).accessibilityLabel("Spend "+choice.counter.name)
                    Button { change(choice,1) } label: { Image(systemName:"plus") }.disabled(choice.counter.current >= choice.counter.maximum).accessibilityLabel("Restore "+choice.counter.name)
                }.buttonStyle(.plain).padding(.vertical,5)
            }
        }.padding(12).background(surface,in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(ink.opacity(0.07)))
    }
    func change(_ choice:ResourceChoice,_ amount:Int) {
        guard var counter = hero.resource(choice.ref) else { return }
        counter.current = min(counter.maximum,max(0,counter.current+amount));hero.setResource(choice.ref,counter)
    }
}

struct CombatSaves: View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text("SAVING THROWS").font(.system(size:10,weight:.semibold)).tracking(1).foregroundStyle(sky)
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:3),spacing:6) {
                ForEach(0..<6,id:\.self) { index in
                    RollChoiceButton(explanation:hero.saveExplanation(index)) { mode in
                        store.rollTyped(hero.expression("1d20",bonus:hero.saveBonus(index),targets:["saves","save.\(index)"]),abilities[index]+" saving throw",hero:hero,kind:.save,ability:index,mode:mode)
                    } label: {
                        VStack(spacing:4) {
                            Text(String(abilities[index].prefix(3)).uppercased()).font(.system(size:9,weight:.medium))
                            Text(signed(hero.saveBonus(index)+hero.testPenalty)).font(.system(size:15,weight:.semibold,design:.rounded)).monospacedDigit()
                        }.frame(maxWidth:.infinity).padding(.vertical,8).background(sky.opacity(0.07),in:RoundedRectangle(cornerRadius:6))
                    }.accessibilityLabel(abilities[index]+" saving throw "+signed(hero.saveBonus(index)+hero.testPenalty))
                }
            }
        }.padding(12).background(surface,in:RoundedRectangle(cornerRadius:10))
    }
}
