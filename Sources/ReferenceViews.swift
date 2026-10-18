import SwiftUI

struct ReferenceBody:View {
    var entry:CompendiumEntry
    var scalar:[ReferenceField] { entry.fields.filter { $0.children.isEmpty && $0.name != "name" && !$0.text.isEmpty } }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            if entry.category == .monster { CreatureReferenceStats(entry:entry) }
            else if entry.category != .race { ReferenceMetadataTable(fields:scalar.filter { !["text","description"].contains($0.name) },equipment:entry.category == .item) }
            ForEach(Array(scalar.filter { ["text","description"].contains($0.name) }.enumerated()),id:\.offset) { _,field in
                Text(field.text).font(.system(size:13)).lineSpacing(4).textSelection(.enabled).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading)
            }
            ForEach(Array(entry.fields.filter { !$0.children.isEmpty && !(entry.category == .race && GuideRules.isOriginMetadata($0.children.first { $0.name == "name" }?.text ?? "")) }.enumerated()),id:\.offset) { _,field in ReferenceDisclosure(field:field) }
            if entry.category == .race { ReferenceMetadataTable(fields:GuideRules.originFacts(entry)) }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}

struct ReferenceMetadataTable:View {
    var fields:[ReferenceField]
    var equipment = false
    var body:some View {
        if !fields.isEmpty {
            VStack(spacing:0) {
                ForEach(Array(fields.enumerated()),id:\.offset) { index,field in
                    HStack(alignment:.top,spacing:14) {
                        Text(referenceLabel(field.name)).font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary).frame(width:98,alignment:.leading)
                        Text(equipment && field.name == "type" ? EquipmentKind.code(field.text).rawValue:field.text).font(.system(size:12)).textSelection(.enabled).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading)
                    }.padding(.horizontal,12).padding(.vertical,9).background(index.isMultiple(of:2) ? paper.opacity(0.55):Color.clear)
                    if index < fields.count-1 { Divider().opacity(0.4) }
                }
            }.clipShape(RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(ink.opacity(0.09)))
        }
    }
}

struct CreatureReferenceStats:View {
    var entry:CompendiumEntry
    private let identity = ["size","alignment"]
    private let combat = ["ac","hp","speed"]
    private let scores = ["str","dex","con","int","wis","cha"]
    var remaining:[ReferenceField] { entry.fields.filter { $0.children.isEmpty && !["name","text","description"].contains($0.name) && !(identity+combat+scores).contains($0.name) && !$0.text.isEmpty } }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            statRow(identity)
            statRow(combat)
            if scores.contains(where:{ !entry.value($0).isEmpty }) {
                HStack(spacing:0) {
                    ForEach(scores,id:\.self) { key in
                        VStack(spacing:6) {
                            Text(key.uppercased()).font(.system(size:9,weight:.semibold)).foregroundStyle(.secondary)
                            Text(entry.value(key).isEmpty ? "—":entry.value(key)).font(.system(size:19,weight:.semibold,design:.rounded)).monospacedDigit()
                            Text(Int(entry.value(key)).map { signed(Int(floor(Double($0-10)/2))) } ?? "—").font(.system(size:11,weight:.medium)).foregroundStyle(sky).monospacedDigit()
                        }.frame(maxWidth:.infinity).padding(.vertical,12)
                            .overlay(alignment:.trailing) { if key != "cha" { Rectangle().fill(ink.opacity(0.09)).frame(width:1) } }
                            .accessibilityElement(children:.combine).accessibilityLabel(referenceLabel(key)+" "+entry.value(key)+", modifier "+(Int(entry.value(key)).map { signed(Int(floor(Double($0-10)/2))) } ?? "unknown"))
                    }
                }.background(paper.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(ink.opacity(0.09)))
            }
            ReferenceMetadataTable(fields:remaining)
        }
    }
    func statRow(_ keys:[String]) -> some View {
        HStack(alignment:.top,spacing:8) {
            ForEach(keys,id:\.self) { key in
                if !entry.value(key).isEmpty {
                    VStack(alignment:.leading,spacing:6) {
                        Text(referenceLabel(key).uppercased()).font(.system(size:9,weight:.semibold)).tracking(0.5).foregroundStyle(.secondary)
                        Text(display(key)).font(.system(size:12,weight:.medium)).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
                    }.frame(maxWidth:.infinity,minHeight:42,alignment:.topLeading).padding(11).background(paper.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(ink.opacity(0.09)))
                }
            }
        }
    }
    func display(_ key:String) -> String {
        let value = entry.value(key)
        return key == "size" ? (["T":"Tiny","S":"Small","M":"Medium","L":"Large","H":"Huge","G":"Gargantuan"][value] ?? value):value
    }
}

private func referenceLabel(_ value:String) -> String {
    ["hd":"Hit die","numSkills":"Skill choices","slotsReset":"Slot recovery","dmg1":"Damage","dmg2":"Two-handed","dmgType":"Damage type","property":"Properties","cr":"Challenge","ac":"Armor class","hp":"Hit points","str":"Strength","dex":"Dexterity","con":"Constitution","int":"Intelligence","wis":"Wisdom","cha":"Charisma","save":"Saving throws","skill":"Skills","resist":"Resistances","vulnerable":"Vulnerabilities","immune":"Immunities","conditionImmune":"Condition immunities","passive":"Passive Perception"][value] ?? value.capitalized
}

struct ReferenceDisclosure:View {
    var field:ReferenceField
    @State private var expanded = false
    var title:String { field.name == "autolevel" ? "Level \(field.attributes["level"] ?? "?")":field.children.first(where:{ $0.name == "name" })?.text ?? field.name.capitalized }
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            Button { withAnimation(.easeOut(duration:0.15)) { expanded.toggle() } } label: { HStack(spacing:9) { Image(systemName:expanded ? "chevron.down":"chevron.right").font(.system(size:9)); Text(title).font(.system(size:13,weight:.medium)); Spacer(); if field.name == "autolevel" { Text("\(field.children.filter { $0.name == "feature" }.count) features").font(.caption2).foregroundStyle(.secondary) } }.contentShape(Rectangle()) }.buttonStyle(.plain)
            if expanded {
                ForEach(Array(field.children.filter { $0.name != "name" }.enumerated()),id:\.offset) { _,child in
                    if child.children.isEmpty { if !child.text.isEmpty { Text(["text","description"].contains(child.name) ? child.text:"\(child.name.capitalized): \(child.text)").font(.system(size:12)).lineSpacing(3).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) } }
                    else { ReferenceDisclosure(field:child) }
                }
            }
        }.padding(12).background(paper.opacity(field.name == "autolevel" ? 0.6:0.3)).clipShape(RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(ink.opacity(0.07)))
    }
}
