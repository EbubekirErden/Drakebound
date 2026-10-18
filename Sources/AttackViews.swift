import SwiftUI

struct AttacksPanel: View {
    @Binding var hero: Hero
    @ObservedObject var store: Store
    var edit: (Attack)->Void
    @State private var details:Attack?
    @State private var showStowed = false
    var body: some View {
        SheetCard(title:"Attacks",summary:"\(hero.readyAttacks.count) ready · \(hero.stowedAttacks.count) stowed") {
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:12),count:min(3,max(1,hero.readyAttacks.count))),spacing:12) {
                ForEach(hero.readyAttacks) { attack in
                    let unavailable = hero.attackUnavailableReason(attack)
                    VStack(alignment:.leading,spacing:14) {
                        HStack(spacing:10) {
                            Image(systemName:attack.isSpell == true ? "sparkles":"scope").foregroundStyle(attack.isSpell == true ? sky:coral).frame(width:30,height:30).background((attack.isSpell == true ? sky:coral).opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:7))
                            Button { details = attack } label: { VStack(alignment:.leading,spacing:3) { Text(attack.name).font(.system(size:14,weight:.semibold)).lineLimit(1); Text(attack.type).font(.system(size:10)).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain)
                            Menu { Button("Edit attack") { edit(attack) }; Button("Remove attack",role:.destructive) { hero.removeWeaponAttack(attack.id) } } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).frame(width:20)
                        }
                        Label(unavailable ?? (hero.linkedEquipment(attack) != nil ? "Equipped":attack.isSpell == true ? "Spell attack":"Attack"),systemImage:unavailable != nil ? "backpack":"checkmark.circle").font(.system(size:10,weight:.medium)).foregroundStyle(unavailable != nil ? gold:Color.secondary).frame(height:13)
                        HStack(spacing:8) {
                            RollChoiceButton(explanation:hero.attackExplanation(attack)) { mode in store.performAction(SheetActionRef(kind:.attack,sourceID:attack.id),heroID:hero.id,mode:mode) } label: {
                                attackField("TO HIT",signed(hero.attackBonus(attack)+hero.testPenalty),hero.rollMode(for:.attack,manual:store.rollMode).rawValue,sky)
                            }
                            Button { store.roll(hero.expression(attack.damage,bonus:hero.damageBonus(attack),targets:hero.attackTargets(attack,damage:true)),"\(attack.name) · damage") } label: {
                                attackField("DAMAGE",hero.expression(attack.damage,bonus:hero.damageBonus(attack),targets:hero.attackTargets(attack,damage:true)),attack.type,coral)
                            }.buttonStyle(.plain).help(hero.damageExplanation(attack))
                        }.disabled(unavailable != nil).opacity(unavailable == nil ? 1:0.45)
                    }.padding(12).background(paper.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(ink.opacity(0.05)))
                }
            }
            if hero.readyAttacks.isEmpty { Text("Equip a weapon or add a custom attack to put it here.").font(.caption).foregroundStyle(.secondary).padding(.vertical,6) }
            if !hero.stowedAttacks.isEmpty {
                DisclosureGroup("Stowed weapons · \(hero.stowedAttacks.count)",isExpanded:$showStowed) {
                    ForEach(hero.stowedAttacks) { attack in HStack(spacing:10) {
                        Button { details = attack } label: { Text(attack.name).frame(maxWidth:.infinity,alignment:.leading) }.buttonStyle(.plain)
                        Text(hero.attackUnavailableReason(attack) ?? "Stowed").foregroundStyle(.secondary)
                        if let item = hero.linkedEquipment(attack),item.quantity > 0 { Button("Equip") { hero.setItemEquipped(item.id,true,compendium:store.compendium) }.accessibilityLabel("Equip \(item.name) for attacks") }
                        Button { edit(attack) } label: { Image(systemName:"pencil") }.help("Edit \(attack.name)")
                    }.font(.system(size:11)).padding(.vertical,6) }
                }.font(.caption).foregroundStyle(.secondary)
            }
            Button { edit(Attack(name:"")) } label: { Label("Add attack",systemImage:"plus") }.buttonStyle(.plain).font(.caption).foregroundStyle(coral)
        }.popover(item:$details) { attack in AttackDescription(name:attack.name,text:attack.description ?? "",edit:{ details = nil; edit(attack) }) }
    }
    func attackField(_ title:String,_ value:String,_ subtitle:String,_ color:Color) -> some View {
        AttackRollField(title:title,value:value,subtitle:subtitle,color:color)
    }
}
