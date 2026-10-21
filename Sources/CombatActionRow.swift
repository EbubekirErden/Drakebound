import SwiftUI

struct CombatActionRow:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var action:SheetAction
    @State private var details = false
    @State private var costs = false
    var attack:Attack? { hero.attacks.first { $0.id == action.ref.sourceID && action.ref.group.kind == .attack } }
    var spell:Spell? { hero.spells.first { $0.id == action.ref.sourceID && action.ref.group.kind == .spell } }
    var feature:CharacterFeature? { hero.featureEntries?.first { $0.id == action.ref.sourceID && action.ref.group.kind == .featureUse } }
    var creature:Creature? { hero.creatureSource(action.ref) }
    var creatureAttack:CreatureAttack? { hero.creatureAttack(action.ref) }
    var creatureFeature:CharacterFeature? { hero.creatureFeature(action.ref) }
    var rolls:[NamedRoll] { hero.quickRolls(action.ref) }
    var unavailable:String? {
        if let creature { return !creature.isActive || creature.hp == 0 ? "Companion unavailable":nil }
        if let attack { return hero.attackUnavailableReason(attack) ?? (!hero.canAct ? "Unable to act":nil) }
        return nil
    }
    var subtitle:String {
        if let attack { return unavailable ?? [attack.type,hero.actionTiming(action.ref).rawValue].joined(separator:" · ") }
        if let spell { return [spell.level == 0 ? "Cantrip":"Level \(spell.level)",spell.time,spell.range].filter { !$0.isEmpty }.joined(separator:" · ") }
        return unavailable ?? action.subtitle
    }
    var body:some View {
        CombatRowLayout {
            HStack(spacing:9) {
                Button { hero.toggleActionFavorite(action.ref) } label: { Image(systemName:hero.actionIsFavorite(action.ref) ? "star.fill":"star").font(.system(size:11)).foregroundStyle(hero.actionIsFavorite(action.ref) ? gold:ink.opacity(0.3)).frame(width:22,height:28).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel((hero.actionIsFavorite(action.ref) ? "Unfavorite ":"Favorite ")+action.name)
                Button { openDetails() } label: {
                    VStack(alignment:.leading,spacing:4) {
                        HStack(spacing:5) {
                            Text(action.name).font(.system(size:13,weight:.medium)).fixedSize(horizontal:false,vertical:true)
                            if hero.concentrationSpellID == action.ref.sourceID { Image(systemName:"sparkle.magnifyingglass").font(.system(size:10)).foregroundStyle(sky).accessibilityLabel("Concentrating") }
                        }
                        Text(subtitle).font(.system(size:10)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                    }.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                }.buttonStyle(.plain).help("Open "+action.name)
            }
            controls.fixedSize(horizontal:true,vertical:false)
        }.padding(.horizontal,10).padding(.vertical,10)
            .background(hero.concentrationSpellID == action.ref.sourceID ? sky.opacity(0.06):Color.clear)
            .popover(isPresented:$details) {
                VStack(alignment:.leading,spacing:12) {
                    HStack { Text(action.name).font(.headline);Spacer();Button("Done") { details=false } }
                    ScrollView {
                        Text(DescriptionMarkdown.attributed(attack?.description ?? feature?.text ?? creatureAttack?.description ?? creatureFeature?.text ?? "No description provided.")).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                    }
                }.padding(18).frame(width:380,height:260)
            }
    }
    @ViewBuilder var controls:some View {
        HStack(spacing:7) {
            if let attack {
                RollChoiceButton(explanation:hero.attackExplanation(attack)) { mode in store.performAction(action.ref,heroID:hero.id,mode:mode) } label: {
                    Text("Hit "+signed(hero.attackBonus(attack)+hero.testPenalty)).font(.system(size:12,weight:.semibold,design:.rounded)).foregroundStyle(sky).padding(.horizontal,9).frame(height:30).background(sky.opacity(0.08),in:RoundedRectangle(cornerRadius:6))
                }
                damageButton(hero.expression(attack.damage,bonus:hero.damageBonus(attack),targets:hero.attackTargets(attack,damage:true)),ref:SheetActionRef(kind:.attackDamage,sourceID:attack.id),critical:true)
            } else if let creatureAttack,let creature {
                if creatureAttack.resolution != .damage {
                    RollChoiceButton(explanation:creature.name+" attack") { mode in store.performAction(action.ref,heroID:hero.id,mode:mode) } label: { Text("Hit "+signed(creatureAttack.bonus)).font(.system(size:12,weight:.semibold)).foregroundStyle(sky).padding(7).background(sky.opacity(0.08),in:RoundedRectangle(cornerRadius:6)) }
                }
                damageButton(creatureAttack.damage,ref:SheetActionRef(kind:.creatureDamage,sourceID:creatureAttack.id,creatureID:creature.id),critical:creatureAttack.resolution != .damage)
            } else if let spell {
                CastControl(hero:$hero,store:store,spell:spell,compact:true,showsOptionsButton:true)
            } else {
                if feature?.counter != nil || feature?.resourceCost != nil || creatureFeature != nil {
                    Button("Use") { store.performAction(action.ref,heroID:hero.id) }.buttonStyle(.plain).font(.system(size:12,weight:.semibold)).foregroundStyle(accent).padding(.horizontal,10).frame(height:30).background(accent.opacity(0.08),in:RoundedRectangle(cornerRadius:6)).help(hero.actionCostDetails(action.ref))
                }
                if !rolls.isEmpty {
                    Menu("Roll") {
                        ForEach(rolls) { roll in
                            let level = roll.slotLevel ?? spell?.level ?? 0
                            Button(roll.name+" · "+roll.expression) {
                                let kind:SheetActionKind = action.ref.kind == .itemRoll ? .itemRoll:.featureRoll
                                store.performAction(SheetActionRef(kind:kind,sourceID:action.ref.sourceID,rollID:roll.id),heroID:hero.id,slot:level)
                            }
                        }
                    }.menuStyle(.borderlessButton).fixedSize().font(.system(size:12)).foregroundStyle(sky).help("Custom rolls spend only their configured resources.")
                }
            }
        }.disabled(unavailable != nil)
    }
    func damageButton(_ expression:String,ref:SheetActionRef,critical:Bool)->some View {
        HStack(spacing:2) {
            Button { store.performAction(ref,heroID:hero.id) } label: { Text(expression).font(.system(size:12,weight:.medium,design:.monospaced)).padding(.horizontal,8).frame(height:30).background(coral.opacity(0.08),in:RoundedRectangle(cornerRadius:6)) }.buttonStyle(.plain).foregroundStyle(coral).accessibilityLabel(action.name+" damage")
            if critical {
                Menu { Button("Critical damage") { store.performAction(ref,heroID:hero.id,critical:true) } } label: { Image(systemName:"chevron.down").font(.system(size:9)).frame(width:16,height:30) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(coral).accessibilityLabel(action.name+" critical damage options")
            }
        }
    }
    func openDetails() {
        if let spell { store.openSpell(spell,hero:hero,ids:hero.spells.filter { $0.prepared || $0.level == 0 }.map(\.id)) }
        else if action.ref.kind == .itemRoll { store.itemDetail = ItemPresentation(heroID:hero.id,itemID:action.ref.sourceID,ids:hero.items.map(\.id)) }
        else { details=true }
    }
}

// Each control has one presentation anchor, even when a narrow row puts it below its title.
struct CombatRowLayout:Layout {
    func metrics(_ width:CGFloat,_ subviews:Subviews)->(CGSize,CGSize,Bool) {
        let controls = subviews[1].sizeThatFits(.unspecified)
        let stacked = width < 150+controls.width+12
        let title = subviews[0].sizeThatFits(ProposedViewSize(width:stacked ? width:width-controls.width-12,height:nil))
        return (title,controls,stacked)
    }
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ())->CGSize {
        let width = proposal.width ?? 500
        let (title,controls,stacked) = metrics(width,subviews)
        return CGSize(width:width,height:stacked ? title.height+8+controls.height:max(title.height,controls.height))
    }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        let (title,controls,stacked) = metrics(bounds.width,subviews)
        subviews[0].place(at:CGPoint(x:bounds.minX,y:bounds.minY),anchor:.topLeading,proposal:ProposedViewSize(width:stacked ? bounds.width:bounds.width-controls.width-12,height:title.height))
        subviews[1].place(at:CGPoint(x:stacked ? bounds.minX+31:bounds.maxX-controls.width,y:stacked ? bounds.minY+title.height+8:bounds.minY+(bounds.height-controls.height)/2),anchor:.topLeading,proposal:ProposedViewSize(controls))
    }
}
