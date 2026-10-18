import SwiftUI

struct AbilityTable:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var body:some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:0) {
                rowLabel("Ability",height:24)
                rowLabel("Score",height:36)
                rowLabel("Check",height:32)
                rowLabel("Save",height:32)
            }.frame(width:58)
            ForEach(0..<6,id:\.self) { i in
                VStack(spacing:0) {
                    Text(String(abilities[i].prefix(3)).uppercased()).font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary).frame(maxWidth:.infinity).frame(height:24)
                    Text("\(hero.effectiveScore(i))").font(.system(size:20,weight:.semibold,design:.rounded)).frame(maxWidth:.infinity).frame(height:36).accessibilityElement(children:.ignore).accessibilityLabel("\(abilities[i]) score \(hero.effectiveScore(i))").help(hero.scoreExplanation(i))
                    roll(i,save:false).frame(height:32).background(accent.opacity(0.04))
                    roll(i,save:true).frame(height:32).background(sky.opacity(0.04)).overlay(alignment:.leading) {
                        Button {
                            if hero.saveProficiencies.contains(i) { hero.saveProficiencies.removeAll { $0 == i } }
                            else { hero.saveProficiencies.append(i) }
                        } label: { Image(systemName:hero.isSaveProficient(i) ? "circle.inset.filled":"circle").font(.system(size:9)).foregroundStyle(sky) }
                            .buttonStyle(.plain).padding(.leading,10).accessibilityLabel("\(abilities[i]) manual save proficiency")
                            .help("Toggle manual save proficiency. Feature-granted proficiency stays active.\n"+hero.trainingSources("save.\(i)").joined(separator:" · "))
                    }
                }.frame(maxWidth:.infinity).overlay(alignment:.leading) { Rectangle().fill(ink.opacity(0.06)).frame(width:1) }
            }
        }.padding(10).background(surface).clipShape(RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(ink.opacity(0.08)))
    }
    func rowLabel(_ label:String,height:CGFloat) -> some View {
        Text(label).font(.system(size:10,weight:.medium)).foregroundStyle(.secondary).frame(height:height)
    }
    func roll(_ i:Int,save:Bool) -> some View {
        let bonus = save ? hero.saveBonus(i):hero.abilityCheckBonus(i)
        let targets = save ? ["saves","save.\(i)"]:["checks","check.\(i)"]
        let title = abilities[i]+(save ? " saving throw":" ability check")
        return RollChoiceButton(explanation:save ? hero.saveExplanation(i):hero.checkExplanation(i)) { mode in
            store.rollTyped(hero.expression("1d20",bonus:bonus,targets:targets),title,hero:hero,kind:save ? .save:.check,ability:i,mode:mode)
        } label: {
            Text(signed(bonus+hero.testPenalty)).font(.system(size:13,weight:.semibold,design:.monospaced)).foregroundStyle(save ? sky:accent).frame(maxWidth:.infinity).frame(height:30).contentShape(Rectangle())
        }.accessibilityLabel(title+" "+signed(bonus+hero.testPenalty))
    }
}
