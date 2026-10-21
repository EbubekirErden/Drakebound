import SwiftUI

struct SpellSlotGrid:View {
    @Binding var hero:Hero
    var manage:(()->Void)?
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text("SPELL SLOTS").font(.system(size:10,weight:.semibold)).tracking(1).foregroundStyle(sky)
                Spacer(minLength:4)
                if let manage { Button("Manage",action:manage).buttonStyle(.plain).font(.system(size:11)).foregroundStyle(sky) }
            }
            LazyVGrid(columns:[GridItem(.flexible(),spacing:8),GridItem(.flexible(),spacing:8)],spacing:8) {
                ForEach(0..<9,id:\.self) { index in
                    if hero.slots[index] > 0 {
                        slot(index)
                    }
                }
            }
            if !hero.slots.contains(where:{ $0 > 0 }) { Text("No spell slots configured").font(.system(size:11)).foregroundStyle(.secondary) }
        }.padding(12).background(surface,in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(ink.opacity(0.07)))
    }
    func slot(_ index:Int)->some View {
        let total = hero.slots[index],left = max(0,hero.slots[index]-hero.usedSlots[index])
        return VStack(spacing:7) {
            HStack(spacing:4) {
                Text("Level \(index+1)").font(.system(size:10,weight:.medium))
                Spacer(minLength:0)
                Text("\(left)/\(total)").font(.system(size:12,weight:.semibold,design:.rounded)).monospacedDigit().foregroundStyle(left == 0 ? Color.secondary:sky)
            }
            HStack(spacing:4) {
                Button { hero.usedSlots[index] = min(total,hero.usedSlots[index]+1) } label: { Image(systemName:"minus").frame(width:22,height:22).contentShape(Rectangle()) }.disabled(left == 0).accessibilityLabel("Spend level \(index+1) spell slot")
                GeometryReader { geometry in
                    Capsule().fill(sky.opacity(0.12))
                        .overlay(alignment:.leading) { Capsule().fill(sky).frame(width:geometry.size.width*CGFloat(left)/CGFloat(max(1,total))) }
                }.frame(height:4).accessibilityHidden(true)
                Button { hero.usedSlots[index] = max(0,hero.usedSlots[index]-1) } label: { Image(systemName:"plus").frame(width:22,height:22).contentShape(Rectangle()) }.disabled(hero.usedSlots[index] == 0).accessibilityLabel("Restore level \(index+1) spell slot")
            }.font(.system(size:10)).buttonStyle(.plain).foregroundStyle(sky)
        }.padding(8).background(paper.opacity(0.6),in:RoundedRectangle(cornerRadius:7))
            .accessibilityElement(children:.contain).accessibilityLabel("Level \(index+1), \(left) of \(total) spell slots remaining")
    }
}
