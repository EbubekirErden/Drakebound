import SwiftUI

struct GuideLevelPreview:View {
    var draft:CharacterBuildDraft
    var body:some View {
        let hero=draft.result
        let old=draft.original!
        let changes=draft.changeSummary.filter { !$0.hasPrefix("Total level:") && !$0.hasPrefix("Maximum HP:") && !$0.hasPrefix("Proficiency:") && !$0.hasPrefix(draft.chosenClass.name+" →") }
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:9) { Portrait(data:hero.portrait,name:hero.name,size:36);VStack(alignment:.leading,spacing:4) { Text(hero.name).font(.system(size:14,weight:.semibold));Text("Level \(old.level) → \(hero.level)").font(.system(size:11)).foregroundStyle(accent) } }
            Text(draft.chosenClass.name+" · class level \(draft.classLevel)").font(.system(size:12,weight:.medium)).foregroundStyle(sky)
            VStack(spacing:0) {
                delta("Maximum HP",old:String(old.maximumHP),new:String(hero.maximumHP),index:0)
                delta("Armor class",old:String(old.armorClass),new:String(hero.armorClass),index:1)
                delta("Proficiency",old:signed(old.proficiency),new:signed(hero.proficiency),index:2)
                delta("Current HP",old:String(old.hp),new:String(hero.hp),index:3)
            }.clipShape(RoundedRectangle(cornerRadius:7))
            if !draft.guideIssues.isEmpty { Label("\(draft.guideIssues.count) required \(draft.guideIssues.count == 1 ? "choice":"choices") left",systemImage:"exclamationmark.circle").font(.system(size:11)).foregroundStyle(gold) }
            GuideSection("This level",summary:"\(changes.count) changes",expanded:true) {
                if changes.isEmpty { Text("No additional choices yet.").font(.system(size:11)).foregroundStyle(.secondary) }
                ForEach(Array(changes.enumerated()),id:\.offset) { _,line in Text(line).font(.system(size:11)).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading) }
            }
            GuideSection("Final abilities") {
                ForEach(0..<6,id:\.self) { i in HStack { Text(String(abilities[i].prefix(3)));Spacer();Text("\(hero.effectiveScore(i)) · \(signed(hero.modifier(i)))").foregroundStyle(sky) }.font(.system(size:11)) }
            }
            Text("Draft only · existing spent resources stay preserved.").font(.system(size:10)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
    private func delta(_ label:String,old:String,new:String,index:Int)->some View {
        HStack(spacing:6) { Text(label).foregroundStyle(.secondary);Spacer(minLength:0);if old != new { Text(old+" →").foregroundStyle(.secondary) };Text(new).foregroundStyle(old == new ? ink:accent).fontWeight(.semibold) }.font(.system(size:11)).modifier(GuideTableRow(index:index))
    }
}
