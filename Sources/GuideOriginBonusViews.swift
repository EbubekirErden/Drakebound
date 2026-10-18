import SwiftUI

extension CharacterGuide {
    var originBonusControls:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Picker("Origin increases",selection:Binding(get:{ draft.originBonusMethod },set:{ draft.setOriginBonusMethod($0) })) {
                    if draft.hero.edition == "2014",GuideRules.fixedAncestryBonuses(draft.ancestryTemplate) != nil { Text(OriginBonusMethod.reference.rawValue).tag(OriginBonusMethod.reference) }
                    Text(OriginBonusMethod.twoOne.rawValue).tag(OriginBonusMethod.twoOne)
                    Text(OriginBonusMethod.threeOnes.rawValue).tag(OriginBonusMethod.threeOnes)
                    Text(OriginBonusMethod.custom.rawValue).tag(OriginBonusMethod.custom)
                }
                Button { originHelp=true } label: { Image(systemName:"questionmark.circle") }.buttonStyle(.plain).accessibilityLabel("Origin ability increase rules")
            }
            HStack {
                Text(draft.originBonusSource).lineLimit(1)
                Spacer()
                if draft.originBonusMethod != .custom && draft.originBonusMethod != .reference { Text("\(draft.originAdjustments.reduce(0,+)) / 3 assigned").monospacedDigit().foregroundStyle(accent) }
            }.font(.caption2).foregroundStyle(.secondary)
        }.popover(isPresented:$originHelp) {
            VStack(alignment:.leading,spacing:12) {
                HStack { Text("Origin ability increases").font(.headline); Spacer(); Button("Close") { originHelp=false } }
                if draft.hero.edition == "2024" {
                    Text("2024: increases come from your background. Choose +2 to one listed ability and +1 to another, or +1 to all three. These increases cannot raise a score above 20.")
                    if let indices=GuideRules.backgroundAbilities(draft.backgroundTemplate) { Text("Your background allows: "+indices.map { abilities[$0] }.joined(separator:", ")+".") }
                    else if draft.backgroundTemplate?.sourceMark == .revised { Text("This imported background does not provide a clear three-ability list. Check its reference and choose the allowed abilities manually.") }
                    else { Text("Older backgrounds: choose any two abilities for +2/+1, or any three for +1/+1/+1. Custom backgrounds can use your table’s chosen abilities.") }
                    Text("Ignore ability increases printed in an older species/ancestry. They do not stack with the background increases.")
                } else {
                    Text("2014: use the ability increases granted by your chosen ancestry or subrace. Backgrounds normally do not grant ability increases.")
                    Text("Unambiguous fixed XML bonuses are filled in from the ancestry reference. Flexible ancestries offer +2/+1 or +1/+1/+1. For other traits or house rules, use Custom and check the reference.")
                }
                Text("The origin column changes base scores once. Other feat and equipment modifiers remain separate. Custom / table rule explicitly allows nonstandard adjustments.").foregroundStyle(.secondary)
                Link("Official 2024 character creation rules",destination:URL(string:"https://www.dndbeyond.com/sources/dnd/br-2024/creating-a-character")!)
            }.font(.system(size:12)).padding(18).frame(width:390)
        }
    }
}
