import SwiftUI

struct AttackEditor: View {
    @State var attack:Attack
    var onSave:(Attack)->Void
    @Environment(\.dismiss) var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("Attack").font(.system(size:20,weight:.semibold)); Spacer(); Button("Cancel") { dismiss() }; Button("Save") { attack.automaticWeaponAttack=false;onSave(attack); dismiss() }.buttonStyle(.borderedProminent).disabled(attack.name.trimmingCharacters(in:.whitespaces).isEmpty || (try? Dice.roll(attack.damage)) == nil) }
            EditorGroup(title:"Identity") { TextField("Attack name",text:$attack.name); HStack { EditorField(title:"Ability") { Picker("Ability",selection:$attack.ability) { ForEach(0..<6,id:\.self) { Text(abilities[$0]).tag($0) } } }; Toggle("Proficient",isOn:$attack.proficient); Toggle("Spell attack",isOn:Binding(get:{ attack.isSpell ?? false },set:{ attack.isSpell = $0 })) } }
            ActionTimingPicker(timing:$attack.timing,defaultLabel:"Default · Action")
            EditorGroup(title:"Damage") { HStack { EditorField(title:"Dice formula") { DiceFormulaField(value:$attack.damage) }; EditorField(title:"Damage type") { OptionField(title:"Damage type",value:$attack.type,choices:damageTypeChoices) } }; Toggle("Add ability modifier",isOn:$attack.addDamageModifier) }
            EditorGroup(title:"Description & properties") { BorderedTextEditor(text:Binding(get:{ attack.description ?? "" },set:{ attack.description = $0 }),height:100); Text("Range, targeting, weapon properties, and special effects.").font(.caption2).foregroundStyle(.secondary) }
        }.padding(20).frame(width:560).textFieldStyle(.roundedBorder).tint(accent)
    }
}

struct HealthPanel: View {
    @Binding var hero: Hero
    @ObservedObject var store: Store
    var rest: () -> Void
    @State private var adjusting: HealthAdjustment?
    @State private var hitDice = false
    @State private var hpBreakdown = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some View {
        Card(title:"Health & recovery",tip:.health) {
            HStack(alignment:.center,spacing:16) {
                HStack(alignment:.firstTextBaseline,spacing:5) {
                    Text("\(hero.hp)").font(.system(size:36,weight:.semibold,design:.rounded)).foregroundStyle(healthColor(hero.hp,hero.maximumHP)).contentTransition(.numericText())
                    Text("/ \(hero.maximumHP)").font(.system(size:16)).foregroundStyle(.secondary).help(hero.maximumHPExplanation)
                    Button { hpBreakdown = true } label: { Image(systemName:"questionmark.circle").font(.system(size:13)).foregroundStyle(.secondary).frame(width:24,height:24) }
                        .buttonStyle(.plain).accessibilityLabel("Maximum HP breakdown").help("How maximum HP is calculated")
                        .popover(isPresented:$hpBreakdown) {
                            VStack(alignment:.leading,spacing:10) { Text("Maximum HP").font(.headline); Text(hero.maximumHPExplanation).font(.system(size:12)).textSelection(.enabled).fixedSize(horizontal:false,vertical:true) }.padding(16).frame(width:300)
                        }
                }
                Spacer()
                DeathSaveControl(hero:$hero,store:store)
                Button { adjusting = .temporary } label: { VStack(spacing:3) { Text("\(hero.tempHP)").font(.system(size:21,weight:.semibold,design:.rounded)); Text("TEMP HP").font(.system(size:8,weight:.bold)).tracking(1) }.foregroundStyle(sky).frame(width:76,height:48).background(sky.opacity(0.09)).clipShape(RoundedRectangle(cornerRadius:8)) }.buttonStyle(.plain).popover(isPresented:Binding(get:{ adjusting == .temporary },set:{ if !$0 { adjusting = nil } })) { HealthAmountPopup(hero:$hero,adjustment:.temporary) }
            }
            HealthBar(hp:hero.hp,maximum:hero.maximumHP,height:7).padding(.vertical,3)
            ControlFlowLayout(spacing:8) {
                healthAction("Damage","minus",coral,.damage)
                healthAction("Heal","plus",leaf,.healing)
                inspirationControl
                Button { hitDice = true } label: { Label("Hit dice · \(max(0,hero.level-hero.hitDiceUsed))/\(hero.level)",systemImage:"dice").padding(.horizontal,12).frame(height:34).background(gold.opacity(0.09)).foregroundStyle(gold).clipShape(RoundedRectangle(cornerRadius:7)) }.buttonStyle(.plain).popover(isPresented:$hitDice) { HitDicePopup(hero:$hero,store:store) }
                Button(action:rest) { Label("Rest",systemImage:"moon.stars").padding(.horizontal,12).frame(height:34).background(sky.opacity(0.09)).foregroundStyle(sky).clipShape(RoundedRectangle(cornerRadius:7)) }.buttonStyle(.plain)
            }.font(.system(size:12,weight:.medium))
            if hero.concentratingSpell != nil { ConcentrationChip(hero:$hero,store:store) }
            ConcentrationSavePrompt(hero:$hero,store:store)

        }.animation(reduceMotion ? nil:.easeOut(duration:0.3),value:hero.hp)
    }
    var inspirationControl:some View {
        Button { hero.inspiration.toggle() } label: { Label("Inspiration",systemImage:hero.inspiration ? "sparkles":"sparkle").font(.system(size:11,weight:.medium)).padding(.horizontal,10).padding(.vertical,6).foregroundStyle(hero.inspiration ? gold:Color.secondary).background(gold.opacity(hero.inspiration ? 0.13:0.035)).clipShape(Capsule()).overlay(Capsule().stroke(gold.opacity(hero.inspiration ? 0.4:0.12))) }.buttonStyle(.plain).accessibilityValue(hero.inspiration ? "Available":"Not available").help("Toggle Inspiration")
    }
    func healthAction(_ title:String,_ icon:String,_ color:Color,_ type:HealthAdjustment) -> some View {
        Button { adjusting = type } label: { Label(title,systemImage:icon).padding(.horizontal,12).frame(height:34).background(color.opacity(0.09)).foregroundStyle(color).clipShape(RoundedRectangle(cornerRadius:7)) }.buttonStyle(.plain)
            .popover(isPresented:Binding(get:{ adjusting == type },set:{ if !$0 { adjusting = nil } })) { HealthAmountPopup(hero:$hero,adjustment:type) }
    }

}

struct SkillsPanel: View {
    @Binding var hero: Hero
    @ObservedObject var store: Store
    var body: some View {
        SheetCard(title:"Skills",summary:"\(skills.filter { hero.effectiveSkillRank($0.0) > 0 }.count) trained · \(skills.filter { hero.effectiveSkillRank($0.0) == 2 }.count) expertise") {
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:18),count:3),spacing:2) {
                ForEach(skills,id:\.0) { name,ability in
                    HStack(spacing:8) {
                        Button { hero.skillRanks[name] = ((hero.skillRanks[name] ?? 0)+1)%3 } label: { Text(["○","●","◆"][hero.effectiveSkillRank(name)]).foregroundStyle(accent).frame(width:14) }.buttonStyle(.plain).help("Manual rank: none / proficiency / expertise · "+hero.trainingSources("skill."+name).joined(separator:" · "))
                        Text(name).font(.system(size:12)); Text(String(abilities[ability].prefix(3)).uppercased()).font(.system(size:8)).foregroundStyle(.secondary); Spacer(minLength:0)
                        rollButton(hero.skillBonus(name,ability),["checks","check.\(ability)","skill.\(name)"],name,kind:.check,ability:ability,explanation:hero.skillExplanation(name,ability:ability))
                    }.padding(.vertical,8).overlay(alignment:.bottom) { Rectangle().fill(ink.opacity(0.04)).frame(height:1) }
                }
            }
        }
    }
    func rollButton(_ bonus:Int,_ targets:[String],_ label:String,kind:D20Kind,ability:Int,explanation:String) -> some View {
        RollChoiceButton(explanation:explanation) { mode in store.rollTyped(hero.expression("1d20",bonus:bonus,targets:targets),label,hero:hero,kind:kind,ability:ability,mode:mode) } label: { Text(signed(bonus+hero.testPenalty)).font(.system(size:13,weight:.semibold,design:.monospaced)).foregroundStyle(accent).frame(minWidth:30,minHeight:24) }.accessibilityLabel(label+" "+signed(bonus+hero.testPenalty))
    }
}

struct CounterEditor: View {
    @State var counter: ResourceCounter
    var onSave:(ResourceCounter)->Void
    var onDelete:()->Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Resource counter").font(.headline)
            Form {
                TextField("Name",text:$counter.name)
                TextField("Maximum",value:$counter.maximum,format:.number)
                TextField("Remaining",value:$counter.current,format:.number)
                CounterResetPicker(counter:$counter)
            }
            Text("Rest choices are independent. A short-rest counter only refills on a long or full rest if you select those too.").font(.caption).foregroundStyle(.secondary)
            HStack { Button("Remove",role:.destructive) { onDelete(); dismiss() }; Spacer(); Button("Cancel") { dismiss() }; Button("Save") { counter.current = min(counter.maximum,counter.current); onSave(counter); dismiss() }.buttonStyle(.borderedProminent).disabled(counter.name.trimmingCharacters(in:.whitespaces).isEmpty || !(1...999).contains(counter.maximum) || !(0...max(0,counter.maximum)).contains(counter.current)) }
        }.padding(24).frame(width:420).tint(accent).onChange(of:counter.maximum) { _,n in counter.current = max(0,min(counter.current,n)) }
    }
}

struct BonusPanel: View {
    @Binding var hero: Hero
    @State var editing: Bonus?
    var body: some View {
        SheetCard(title:"Feats & bonuses",summary:"\(hero.activeBonuses.count) active effects") {
            ForEach(hero.bonuses ?? []) { bonus in
                HStack {
                    Toggle("",isOn:Binding(get:{ bonus.enabled },set:{ flag in if let i = hero.bonuses?.firstIndex(where:{ $0.id == bonus.id }) { hero.bonuses?[i].enabled = flag } })).labelsHidden().toggleStyle(.checkbox)
                    Button { editing = bonus } label: { HStack { Text(bonus.name).font(.system(size:12)); Spacer(); Text(bonusSummary(bonus,hero:hero)).font(.system(size:10)).foregroundStyle(.secondary) } }.buttonStyle(.plain)
                }
            }
            Button { editing = Bonus() } label: { Label("Bonus / feat effect",systemImage:"plus") }.buttonStyle(.plain).font(.caption).foregroundStyle(accent)
            if !hero.activeBonuses.isEmpty {
                DisclosureGroup("Active effects · \(hero.activeBonuses.count)") {
                    ForEach(hero.activeBonuses) { b in HStack { Text(b.name).font(.system(size:11)); Spacer(); Text(bonusSummary(b,hero:hero)).font(.system(size:10)).foregroundStyle(.secondary) } }
                }.font(.caption)
            }
        }.sheet(item:$editing) { bonus in BonusEditor(bonus:bonus,hero:hero,onSave:{ updated in var all = hero.bonuses ?? []; if let i = all.firstIndex(where:{ $0.id == updated.id }) { all[i] = updated } else { all.append(updated) }; hero.bonuses = all },onDelete:{ hero.bonuses?.removeAll { $0.id == bonus.id } }) }
    }
}
func bonusTargets(_ hero:Hero) -> [(String,String)] { baseBonusTargets + hero.attacks.flatMap { [("attack.\($0.id.uuidString)","\($0.name) · attack"),("damage.\($0.id.uuidString)","\($0.name) · damage")] } }
func bonusSummary(_ bonus:Bonus,hero:Hero) -> String {
    "\(signed(bonus.amount))\(bonus.dice.isEmpty ? "" : " + \(bonus.dice)") \(bonusTargets(hero).first(where:{ $0.0 == bonus.target })?.1 ?? "Removed attack")"
}
struct BonusEditor: View {
    @State var bonus: Bonus
    var hero: Hero
    var onSave:(Bonus)->Void
    var onDelete:()->Void
    @Environment(\.dismiss) var dismiss
    var diceValid: Bool { !allowsBonusDice(bonus.target) || bonus.dice.isEmpty || (try? Dice.roll(bonus.dice)) != nil }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Bonus / feat effect").font(.headline)
            Form {
                TextField("Source / name",text:$bonus.name)
                Picker("Applies to",selection:$bonus.target) { ForEach(bonusTargets(hero),id:\.0) { Text($0.1).tag($0.0) } }
                Stepper("Flat bonus: \(signed(bonus.amount))",value:$bonus.amount,in:-100...100)
                if allowsBonusDice(bonus.target) { DiceFormulaField(value:$bonus.dice,allowEmpty:true) }
                Toggle("Active",isOn:$bonus.enabled)
            }
            Text("Each effect is explicit and adds to the selected value. Add separate effects for feats with multiple bonuses. Names and descriptions do not apply rules automatically.").font(.caption).foregroundStyle(.secondary)
            HStack { Button("Remove",role:.destructive) { onDelete(); dismiss() }; Spacer(); Button("Cancel") { dismiss() }; Button("Save") { if !allowsBonusDice(bonus.target) { bonus.dice = "" }; onSave(bonus); dismiss() }.buttonStyle(.borderedProminent).disabled(!diceValid || bonus.name.trimmingCharacters(in:.whitespaces).isEmpty) }
        }.padding(24).frame(width:470).tint(accent)
    }
}

struct ItemEditor: View {
    @State var item:Item
    var hero:Hero
    var onSave:(Item)->Void
    @State private var saveToCompendium = false
    @Environment(\.templateSaveAction) private var saveTemplate
    @Environment(\.dismiss) var dismiss
    @State private var editingBonus:Bonus?
    var valid:Bool { !item.name.trimmingCharacters(in:.whitespaces).isEmpty && (0...999).contains(item.quantity) && item.weight.isFinite && (0...100000).contains(item.weight) && validRolls(item.rolls,hero:hero) && (item.weaponProfile?.valid ?? true) }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Equipment").font(.system(size:20,weight:.semibold)); Spacer(); Button("Cancel") { dismiss() }.buttonStyle(PageButtonStyle()); Button("Save item") { if saveToCompendium { saveTemplate?(TemplateFactory.item(item)) }; onSave(item); dismiss() }.buttonStyle(PageButtonStyle(prominent:true)).disabled(!valid) }
            SaveTemplateToggle(selected:$saveToCompendium)
            ScrollView {
                VStack(spacing:12) {
                    EditorGroup(title:"Item") {
                        TextField("Item name",text:$item.name)
                        Picker("Container",selection:$item.containerID) { Text("Carried").tag(Optional<UUID>.none); ForEach(hero.inventoryContainers) { storage in Text(storage.name).tag(Optional(storage.id)) } }
                        HStack { EditorField(title:"Type") { Picker("Type",selection:Binding(get:{ item.equipmentKind },set:{ item.kind = $0 })) { ForEach(EquipmentKind.allCases,id:\.self) { Text($0.rawValue).tag($0) } } }; EditorField(title:"Quantity") { TextField("Quantity",value:$item.quantity,format:.number) }.frame(width:75); EditorField(title:"Weight each · lb") { TextField("Weight",value:$item.weight,format:.number) }.frame(width:100) }
                        HStack { Toggle("Equipped",isOn:$item.equipped); Toggle("Requires attunement",isOn:Binding(get:{ item.requiresAttunement ?? false },set:{ item.requiresAttunement = $0 })); if item.requiresAttunement == true { Toggle("Attuned",isOn:Binding(get:{ item.attuned ?? false },set:{ item.attuned = $0 })) } }.font(.caption)
                    }
                    EditorGroup(title:"Description & properties") { BorderedTextEditor(text:$item.notes,height:90,markdown:true) }
                    EditorColumns {
                        WeaponProfileEditor(item:$item)
                    EditorGroup(title:"Armor & modifiers") {
                        Toggle("Use as base armor",isOn:Binding(get:{ item.armorBase != nil },set:{ item.armorBase = $0 ? 12:nil }))
                        if item.armorBase != nil {
                            Stepper("Base AC \(item.armorBase ?? 12)",value:Binding(get:{ item.armorBase ?? 12 },set:{ item.armorBase = $0 }),in:0...30)
                            HStack { Toggle("Add Dexterity",isOn:Binding(get:{ item.armorAddsDexterity ?? false },set:{ item.armorAddsDexterity = $0 })); if item.armorAddsDexterity == true { Stepper("Cap \(item.armorDexterityCap ?? 20)",value:Binding(get:{ item.armorDexterityCap ?? 20 },set:{ item.armorDexterityCap = $0 }),in:0...20) } }
                        }
                        ForEach(item.bonuses ?? []) { bonus in Button { editingBonus = bonus } label: { HStack { Text(bonus.name); Spacer(); Text(bonusSummary(bonus,hero:hero)).font(.caption).foregroundStyle(gold) } }.buttonStyle(.plain) }
                        Button("Add modifier") { editingBonus = Bonus(name:item.name.isEmpty ? "Item modifier":item.name) }
                        Text("Effects apply while equipped and, if required, attuned. Shields use an AC modifier.").font(.caption2).foregroundStyle(.secondary)
                    }
                    } trailing: {
                        EditorGroup(title:"Action timing") { ActionTimingPicker(timing:$item.timing) }
                    EditorGroup(title:"Custom rolls") { RollListEditor(rolls:$item.rolls,hero:hero) }
                    }
                }
            }
        }.padding(20).modifier(CustomEditorFrame()).textFieldStyle(.roundedBorder).tint(accent)
        .sheet(item:$editingBonus) { bonus in BonusEditor(bonus:bonus,hero:hero,onSave:{ updated in var all = item.bonuses ?? []; if let i = all.firstIndex(where:{ $0.id == updated.id }) { all[i] = updated } else { all.append(updated) }; item.bonuses = all },onDelete:{ item.bonuses?.removeAll { $0.id == bonus.id } }) }
    }
}

struct DiceDock: View {
    @ObservedObject var store: Store
    var selectedHero:Hero? { store.heroes.first { $0.id == store.selected } }
    var resolvedExpression:String { DiceDraft(expression:expression).summary(hero:selectedHero,allowTokens:true)?.resolved ?? expression }
    @State var expression = "1d20"
    @State private var diceCalculator = false
    var body: some View {
        HStack(spacing:10) {
            Image(systemName:"dice").foregroundStyle(accent)
            Button { diceCalculator=true } label: { HStack(spacing:6) { Text(expression).font(.system(size:11,design:.monospaced)).lineLimit(1); Image(systemName:"plus.forwardslash.minus").foregroundStyle(accent) }.frame(width:120,height:28).background(ink.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius:6)) }.buttonStyle(.plain).accessibilityLabel("Open dice calculator").onReceive(store.$commandRequest) { request in if let request,request.action == .diceInput && store.consume(request) { diceCalculator=true } }.popover(isPresented:$diceCalculator) { DiceCalculator(initial:expression,hero:selectedHero,spell:nil,slot:0,allowTokens:selectedHero != nil,allowEmpty:false,onApply:{ expression=$0;diceCalculator=false },onCancel:{ diceCalculator=false },onRoll:{ store.roll($0,"Custom roll") }) }

            RollChoiceButton(enabled:resolvedExpression.lowercased().hasPrefix("1d20")) { mode in store.roll(resolvedExpression,"Custom roll",mode:mode) } label: { Text("Roll").fixedSize().padding(.horizontal,12).padding(.vertical,7).background(accent.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius:7)) }
            ScrollView(.horizontal) {
                HStack(spacing:10) {
                    ForEach([4,6,8,10,12,20,100],id:\.self) { sides in RollChoiceButton(enabled:sides == 20) { mode in store.roll("1d\(sides)","d\(sides)",mode:mode) } label: { Text("d\(sides)").font(.system(size:11)).foregroundStyle(.secondary).padding(.vertical,5) } }
                }.fixedSize(horizontal:true,vertical:false)
            }.scrollIndicators(.visible).frame(minWidth:60,maxWidth:210).frame(height:30)

            Picker("D20 mode",selection:$store.rollMode) { ForEach(RollMode.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.labelsHidden().pickerStyle(.menu).frame(width:88).help("Combines with condition advantage/disadvantage for typed rolls")
            Spacer(minLength:0)
            if let r = store.rolls.first { VStack(alignment:.trailing,spacing:3) { Text(r.label).font(.system(size:11)).lineLimit(1).frame(maxWidth:120); if r.event { Text(r.expression).font(.system(size:9)).foregroundStyle(.secondary).lineLimit(1) } }; if !r.event { Text("\(r.total)").font(.system(size:21,weight:.semibold,design:.rounded)).foregroundStyle(accent).fixedSize() } }
            QuickNoteButton(store:store)
            ActivityButton(store:store)
            RollHistory(rolls:store.rolls)
        }.padding(.horizontal,18).padding(.vertical,12).background(surface)
    }
}
struct DiceAnimation: View {
    let roll: RollResult
    var onDismiss:()->Void
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var faces:[Int]
    @State private var angle = 0.0
    @State private var settled = false
    init(roll:RollResult,onDismiss:@escaping ()->Void) { self.roll = roll; self.onDismiss = onDismiss; _faces = State(initialValue:Array(roll.dice.prefix(24))) }
    var columns:Int { min(4,max(1,faces.count)) }
    var body: some View {
        VStack(spacing:12) {
            HStack { Text(roll.label).font(.system(size:12,weight:.medium)).lineLimit(1); Spacer(); Button(action:onDismiss) { Image(systemName:"xmark") }.buttonStyle(.plain).help("Dismiss dice") }
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:8),count:columns),spacing:10) {
                ForEach(Array(faces.enumerated()),id:\.offset) { index,face in
                    let dropped = settled && roll.keptD20Index != nil && index < 2 && index != roll.keptD20Index
                    VStack(spacing:3) {
                        ZStack {
                            DieShape().fill([accent,sky,gold,coral,leaf][index%5].opacity(0.12))
                            DieShape().stroke([accent,sky,gold,coral,leaf][index%5].opacity(0.8),lineWidth:1.2)
                            Text("\(face)").font(.system(size:faces.count <= 2 ? 34:23,weight:.semibold,design:.rounded)).foregroundStyle([accent,sky,gold,coral,leaf][index%5])
                        }.frame(width:faces.count <= 2 ? 80:54,height:faces.count <= 2 ? 88:60).rotation3DEffect(.degrees(angle+Double(index)*3),axis:(x:1,y:0.6,z:0.4))
                        if roll.keptD20Index != nil && index < 2 { Text(settled ? dropped ? "DROPPED":"KEPT":"D20").font(.system(size:7,weight:.bold)).foregroundStyle(dropped ? .secondary:accent) }
                    }.opacity(dropped ? 0.22:1).scaleEffect(dropped ? 0.9:1).frame(maxWidth:.infinity)
                }
            }.padding(.top,5)
            HStack(alignment:.firstTextBaseline,spacing:10) { Text(roll.expression).font(.system(size:12,design:.monospaced)).foregroundStyle(.secondary).lineLimit(2); Spacer(minLength:4); Text(settled ? "\(roll.total)":"…").font(.system(size:38,weight:.semibold,design:.rounded)).lineLimit(1).minimumScaleFactor(0.4) }.padding(.top,3)
            if let detail = roll.detail { Text(detail).font(.system(size:10)).foregroundStyle(gold).multilineTextAlignment(.center) }
            if roll.dice.count > 24 { Text("Showing 24 of \(roll.dice.count) dice · all results in history").font(.caption2).foregroundStyle(.secondary) }
        }.foregroundStyle(ink).padding(18).frame(width:faces.count <= 2 ? 280:320).background(surface).clipShape(RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(accent.opacity(0.28)))
        .task {
            if !reduceMotion {
                withAnimation(.easeOut(duration:0.8)) { angle = 720 }
                for _ in 0..<12 { do { try await Task.sleep(nanoseconds:65_000_000) } catch { return }; faces = Array(roll.dice.prefix(24).enumerated()).map { i,value in Int.random(in:1...(roll.sides.indices.contains(i) ? roll.sides[i]:20)) * (value < 0 ? -1:1) } }
            }
            withAnimation(.spring(response:0.3,dampingFraction:0.7)) { angle = 0; faces = Array(roll.dice.prefix(24)); settled = true }
            do { try await Task.sleep(nanoseconds:4_500_000_000) } catch { return }; onDismiss()
        }.accessibilityElement(children:.combine).accessibilityLabel("\(roll.label), \(roll.expression), total \(roll.total)")
    }
}

struct DieShape: Shape {
    func path(in r:CGRect) -> Path {
        var p = Path(); let points = [CGPoint(x:r.midX,y:r.minY),CGPoint(x:r.maxX,y:r.height*0.25),CGPoint(x:r.maxX,y:r.height*0.75),CGPoint(x:r.midX,y:r.maxY),CGPoint(x:r.minX,y:r.height*0.75),CGPoint(x:r.minX,y:r.height*0.25)]
        p.addLines(points); p.closeSubpath(); return p
    }
}
