import SwiftUI

// Local state prevents a read-only preview from rebuilding the character draft screen.
struct GuidePreviewButton<Content:View>:View {
    var name:String
    @ViewBuilder var content:()->Content
    @State private var presented=false
    var body:some View {
        Button { presented=true } label: { Image(systemName:"eye").frame(minWidth:24,minHeight:28) }
            .buttonStyle(.plain).help("Preview "+name).accessibilityLabel("Preview "+name)
            .sheet(isPresented:$presented,content:content)
    }
}
struct GuideFeaturePreviewButton:View {
    var feature:CharacterFeature
    var body:some View { GuidePreviewButton(name:feature.name) { GuideFeaturePreview(feature:feature) } }
}
struct GuideDetailPreview<Content:View>:View {
    var title:String
    var subtitle:String = ""
    var source:String = ""
    @ViewBuilder var content:()->Content
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(alignment:.top,spacing:14) {
                VStack(alignment:.leading,spacing:5) {
                    Text(title).font(.system(size:22,weight:.semibold)).textSelection(.enabled)
                    if !subtitle.isEmpty { Text(subtitle).font(.system(size:12)).foregroundStyle(sky) }
                }.frame(maxWidth:.infinity,alignment:.leading)
                Button("Done") { dismiss() }.buttonStyle(PageButtonStyle()).keyboardShortcut(.cancelAction)
            }
            Divider()
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    content()
                    if !source.isEmpty {
                        Divider()
                        DisclosureGroup("Sources") { Text(source).font(.system(size:11)).foregroundStyle(.secondary).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(.top,6) }.font(.system(size:11)).foregroundStyle(.secondary)
                    }
                }.padding(2).frame(maxWidth:.infinity,alignment:.leading)
            }
        }.padding(22).frame(width:640,height:580).background(surface).foregroundStyle(ink).tint(accent)
    }
}
struct GuideFeaturePreview:View {
    var feature:CharacterFeature
    var body:some View {
        GuideDetailPreview(title:feature.name,subtitle:feature.category?.rawValue ?? "Feature",source:feature.source ?? "") {
            DescriptionText(text:feature.text.isEmpty ? "No description yet.":feature.text)
            if let counter=feature.counter { Text("Uses: \(counter.current) / \(counter.maximum) · \(counter.resetSummary)").font(.system(size:12)).foregroundStyle(sky) }
            GuidePreviewRolls(rolls:feature.rolls ?? [])
        }
    }
}
struct GuideSpellPreview:View {
    var spell:Spell
    var body:some View {
        GuideDetailPreview(title:spell.name,subtitle:(spell.level == 0 ? "Cantrip":"Level \(spell.level)")+" · "+spell.school) {
            ReferenceMetadataTable(fields:[ReferenceField(name:"Casting time",text:spell.time),ReferenceField(name:"Range",text:spell.range),ReferenceField(name:"Duration",text:spell.duration),ReferenceField(name:"Components",text:spell.components)])
            HStack(spacing:16) {
                if spell.ritual == true { Label("Ritual",systemImage:"book.closed") }
                if spell.concentration == true { Label("Concentration",systemImage:"sparkles") }
            }.font(.system(size:11)).foregroundStyle(sky)
            DescriptionText(text:spell.text.isEmpty ? "No description yet.":spell.text)
            GuidePreviewRolls(rolls:spell.rolls ?? [])
            if let classes=spell.classes,!classes.isEmpty { Text("Class lists: "+classes).font(.system(size:11)).foregroundStyle(.secondary) }
        }
    }
}
struct GuideItemPreview:View {
    var item:Item
    var body:some View {
        GuideDetailPreview(title:item.name,subtitle:item.equipmentKind.rawValue) {
            ReferenceMetadataTable(fields:[ReferenceField(name:"Quantity",text:String(item.quantity)),ReferenceField(name:"Weight",text:String(format:"%.1f lb each · %.1f lb total",item.weight,Double(item.quantity)*item.weight)),ReferenceField(name:"Status",text:item.equipped ? "Equipped":"Carried")])
            if item.requiresAttunement == true { Label(item.attuned == true ? "Attuned":"Requires attunement",systemImage:"seal").font(.system(size:12)).foregroundStyle(sky) }
            DescriptionText(text:item.notes.isEmpty ? "No description yet.":item.notes)
            if let armor=item.armorBase { Text("Base armor class: \(armor)").font(.system(size:12)) }
            if let weapon=item.weaponProfile { Text("Damage: "+weapon.damage+" · "+weapon.damageType).font(.system(size:12)).foregroundStyle(sky) }
            ForEach(item.bonuses ?? []) { bonus in Text(bonus.name+" · "+signed(bonus.amount)).font(.system(size:12)) }
            GuidePreviewRolls(rolls:item.rolls ?? [])
        }
    }
}
private struct GuidePreviewRolls:View {
    var rolls:[NamedRoll]
    var body:some View {
        if !rolls.isEmpty {
            VStack(alignment:.leading,spacing:8) {
                Text("Configured rolls").font(.system(size:11,weight:.semibold)).foregroundStyle(.secondary)
                ForEach(rolls) { roll in HStack(alignment:.top) { Text(roll.name);Spacer();Text(roll.expression).font(.system(size:12,design:.monospaced)).foregroundStyle(sky) }.font(.system(size:12)) }
            }
        }
    }
}
