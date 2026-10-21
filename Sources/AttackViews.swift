import SwiftUI

struct AttacksAndResourcesPanel:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var width:CGFloat
    var edit:(Attack)->Void
    var body:some View {
        SheetCard(title:"Attacks & resources",summary:"\(hero.readyAttacks.count) attacks · \(hero.resourceChoices.count) resources") {
            if width >= 760 {
                HStack(alignment:.top,spacing:20) {
                    SheetAttackList(hero:$hero,store:store,edit:edit).frame(maxWidth:.infinity)
                    SheetResources(hero:$hero).frame(width:max(260,(width-48)*0.38))
                }
            } else {
                SheetAttackList(hero:$hero,store:store,edit:edit)
                Divider().opacity(0.4)
                SheetResources(hero:$hero)
            }
        }
    }
}

struct SheetAttackList:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var edit:(Attack)->Void
    @State private var details:Attack?
    @State private var stowed=false
    var body:some View {
        VStack(alignment:.leading,spacing:7) {
            HStack {
                Text("ATTACKS").font(.system(size:10,weight:.semibold)).tracking(0.8).foregroundStyle(coral)
                Spacer()
                Button("Add",systemImage:"plus") { edit(Attack(name:"")) }.font(.system(size:11)).buttonStyle(.plain).foregroundStyle(coral).accessibilityLabel("Add attack")
            }
            ForEach(hero.readyAttacks) { attack in
                HStack(spacing:10) {
                    Button { details=attack } label: { Text(attack.name).font(.system(size:12,weight:.medium)).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle()) }.buttonStyle(.plain).help("Details for "+attack.name)
                    RollChoiceButton(explanation:hero.attackExplanation(attack)) { mode in store.performAction(SheetActionRef(kind:.attack,sourceID:attack.id),heroID:hero.id,mode:mode) } label: { Text(signed(hero.attackBonus(attack)+hero.testPenalty)).font(.system(size:12,weight:.semibold,design:.rounded)).foregroundStyle(sky).frame(minWidth:34,minHeight:28) }.accessibilityLabel(attack.name+" attack roll").disabled(hero.attackUnavailableReason(attack) != nil)
                    Button { store.performAction(SheetActionRef(kind:.attackDamage,sourceID:attack.id),heroID:hero.id) } label: { Text(hero.expression(attack.damage,bonus:hero.damageBonus(attack),targets:hero.attackTargets(attack,damage:true))).font(.system(size:11,weight:.medium,design:.monospaced)).foregroundStyle(coral).lineLimit(1).truncationMode(.middle).frame(minWidth:65,maxWidth:110,minHeight:28) }.buttonStyle(.plain).help(hero.damageExplanation(attack)).accessibilityLabel(attack.name+" damage")
                        .disabled(hero.attackUnavailableReason(attack) != nil)
                }.padding(.vertical,2)
                    .contextMenu {
                        Button("Attack details…") { details=attack }
                        Button("Edit attack…") { edit(attack) }
                        Button("Critical damage") { store.performAction(SheetActionRef(kind:.attackDamage,sourceID:attack.id),heroID:hero.id,critical:true) }.disabled(hero.attackUnavailableReason(attack) != nil)
                        Divider();Button("Remove attack",role:.destructive) { hero.removeWeaponAttack(attack.id) }
                    }
            }
            if hero.readyAttacks.isEmpty { Text("No ready attacks").font(.caption).foregroundStyle(.secondary) }
            if !hero.stowedAttacks.isEmpty {
                DisclosureGroup("Stowed · \(hero.stowedAttacks.count)",isExpanded:$stowed) {
                    ForEach(hero.stowedAttacks) { attack in
                        HStack(spacing:8) {
                            Button(attack.name) { details=attack }.buttonStyle(.plain)
                            Spacer()
                            if let item=hero.linkedEquipment(attack),item.quantity > 0 { Button("Equip") { hero.setItemEquipped(item.id,true,compendium:store.compendium) } }
                            Button("Edit") { edit(attack) }
                        }.font(.system(size:11)).padding(.vertical,4)
                    }
                }.font(.system(size:11)).foregroundStyle(.secondary)
            }
        }.popover(item:$details) { attack in AttackDescription(name:attack.name,text:attack.description ?? "",edit:{ details=nil;edit(attack) }) }
    }
}

struct SheetResources:View {
    @Binding var hero:Hero
    @State private var detail:ResourceRef?
    @State private var editing:ResourceCounter?
    @State private var editingRef:ResourceRef?
    @State private var all=false
    var choices:[ResourceChoice] { all ? hero.resourceChoices:Array(hero.resourceChoices.prefix(4)) }
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text("RESOURCES").font(.system(size:10,weight:.semibold)).tracking(0.8).foregroundStyle(gold)
                Spacer()
                Button("Add",systemImage:"plus") { editingRef=nil;editing=ResourceCounter() }.font(.system(size:11)).buttonStyle(.plain).foregroundStyle(gold).accessibilityLabel("Add resource")
            }
            ControlFlowLayout(spacing:6) {
                ForEach(choices) { choice in
                    Button { detail=choice.ref } label: {
                        HStack(spacing:8) { Text(choice.counter.name).lineLimit(1);Text("\(choice.counter.current)/\(choice.counter.maximum)").fontWeight(.semibold).monospacedDigit().foregroundStyle(gold) }.font(.system(size:11)).padding(.horizontal,9).padding(.vertical,7).background(gold.opacity(0.06),in:RoundedRectangle(cornerRadius:6))
                    }.buttonStyle(.plain).help("Adjust "+choice.counter.name+" · "+choice.counter.resetSummary)
                        .accessibilityLabel("Adjust resource "+choice.counter.name)
                        .accessibilityValue("\(choice.counter.current) of \(choice.counter.maximum) remaining")
                        .contextMenu { Button("Resource details…") { detail=choice.ref };Button("Edit resource…") { editingRef=choice.ref;editing=choice.counter } }
                }
            }
            if hero.resourceChoices.count > 4 { Button(all ? "Show fewer":"Show all \(hero.resourceChoices.count) resources") { all.toggle() }.font(.system(size:11)).buttonStyle(.plain).foregroundStyle(gold) }
            if hero.resourceChoices.isEmpty { Text("No tracked resources").font(.caption).foregroundStyle(.secondary) }
        }
        .popover(item:$detail) { ref in
            if let counter=hero.resource(ref) {
                VStack(alignment:.leading,spacing:14) {
                    HStack { Text(counter.name).font(.headline);Spacer();Button("Done") { detail=nil } }
                    HStack(spacing:14) {
                        Button { change(ref,-1) } label: { Image(systemName:"minus") }.disabled(counter.current == 0).accessibilityLabel("Spend resource "+counter.name)
                        Text("\(counter.current) / \(counter.maximum)").font(.system(size:26,weight:.medium,design:.rounded)).monospacedDigit().foregroundStyle(gold)
                        Button { change(ref,1) } label: { Image(systemName:"plus") }.disabled(counter.current >= counter.maximum).accessibilityLabel("Restore resource "+counter.name)
                    }
                    Text(counter.resetSummary).font(.caption).foregroundStyle(.secondary)
                    Button("Edit resource") { detail=nil;editingRef=ref;editing=counter }.buttonStyle(PageButtonStyle())
                }.padding(18).frame(width:310).background(surface).foregroundStyle(ink)
            }
        }
        .sheet(item:$editing) { counter in CounterEditor(counter:counter,onSave:{ updated in
            if let ref=editingRef { hero.setResource(ref,updated) } else { hero.counters=(hero.counters ?? [])+[updated] }
        },onDelete:{ if let ref=editingRef { hero.setResource(ref,nil) } }) }
    }
    func change(_ ref:ResourceRef,_ amount:Int) {
        guard var counter=hero.resource(ref) else { return }
        counter.current=min(counter.maximum,max(0,counter.current+amount));hero.setResource(ref,counter)
    }
}
