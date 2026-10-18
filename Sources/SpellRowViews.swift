import SwiftUI

struct PreparedCasting:ViewModifier {
    var prepared:Bool
    @ViewBuilder func body(content:Content) -> some View {
        if prepared { content }
        else { content.disabled(true).opacity(0.4).help("Not prepared. Prepare this spell to cast it.") }
    }
}
struct ConcentrationOutline:ViewModifier {
    var active:Bool
    func body(content:Content) -> some View {
        content.background(active ? sky.opacity(0.045):Color.clear)
            .overlay { RoundedRectangle(cornerRadius:8).stroke(sky.opacity(active ? 0.8:0),lineWidth:1.5).allowsHitTesting(false) }
    }
}
struct SpellbookRow:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var spell:Spell
    var navigationIDs:[UUID]
    var body:some View {
        HStack(spacing:10) {
            Button { if let i = hero.spells.firstIndex(where:{ $0.id == spell.id }) { hero.spells[i].prepared.toggle() } } label: { Image(systemName:spell.prepared ? "checkmark.circle.fill":"circle") }.buttonStyle(.plain).help("Toggle prepared").accessibilityLabel("Toggle prepared for "+spell.name)
            Button { store.openSpell(spell,hero:hero,ids:navigationIDs) } label: {
                VStack(alignment:.leading,spacing:5) { Text(spell.name).font(.system(size:14,weight:.semibold)); Text("\(spell.school) · \(spell.time) · \(spell.range)").font(.system(size:11)).foregroundStyle(.secondary).lineLimit(1) }.frame(maxWidth:.infinity,alignment:.leading)
            }.buttonStyle(.plain)
            SpellConcentrationMark(hero:$hero,spell:spell)
            CastControl(hero:$hero,store:store,spell:spell)
            Button { if hero.concentrationSpellID == spell.id { hero.endConcentration() }; hero.spells.removeAll { $0.id == spell.id } } label: { Image(systemName:"minus.circle") }.buttonStyle(.plain).help("Remove spell")
        }.padding(.horizontal,9).padding(.vertical,8).modifier(ConcentrationOutline(active:hero.concentrationSpellID == spell.id))
    }
}
