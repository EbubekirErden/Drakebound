import SwiftUI

struct DeathSaveControl:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    @State private var open = false
    var body:some View {
        Button { open = true } label: {
            VStack(spacing:4) {
                HStack(spacing:6) { dots(hero.deathSuccesses,leaf); dots(hero.deathFailures,coral) }
                Text(hero.hp == 0 ? hero.deathSaveStatus == "Stable" ? "STABLE":"DEATH SAVES":"DEATH SAVES").font(.system(size:8,weight:.bold)).tracking(0.5)
            }.foregroundStyle(hero.hp == 0 ? coral:Color.secondary).frame(width:84,height:48).background((hero.hp == 0 ? coral:Color.gray).opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:8)).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("Death saves: \(hero.deathSuccesses) successes, \(hero.deathFailures) failures").help("Open death saves · "+hero.deathSaveStatus)
        .popover(isPresented:$open) {
            VStack(alignment:.leading,spacing:14) {
                HStack { Text("Death saves").font(.headline); Spacer(); TipButton(topic:.health); Button("Done") { open = false } }
                Text(hero.deathSaveStatus).font(.caption).foregroundStyle(hero.hp == 0 ? coral:Color.secondary)
                track("Successes",value:$hero.deathSuccesses,color:leaf)
                track("Failures",value:$hero.deathFailures,color:coral)
                HStack {
                    RollChoiceButton(explanation:"Roll a death save · hold or right-click for advantage / disadvantage") { mode in
                        do { store.record(try hero.rollDeathSave(mode:mode ?? store.rollMode)) } catch { store.error = error.localizedDescription }
                    } label: { Label("Roll death save",systemImage:"dice").font(.caption.bold()).padding(9).background(coral.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius:6)) }.disabled(!hero.needsDeathSave)
                    Spacer()
                    Button("Reset") { hero.resetDeathSaves() }.font(.caption)
                }
                if hero.hp == 0 && hero.deathFailures < 3 { Button("Mark stable") { hero.deathSuccesses = 3; hero.deathFailures = 0 }.font(.caption).disabled(hero.deathSuccesses == 3) }
            }.padding(18).frame(width:315).tint(accent)
        }
    }
    func dots(_ count:Int,_ color:Color) -> some View { HStack(spacing:2) { ForEach(0..<3,id:\.self) { i in Circle().fill(i < count ? color:color.opacity(0.15)).frame(width:6,height:6) } } }
    func track(_ title:String,value:Binding<Int>,color:Color) -> some View {
        HStack { Text(title).font(.caption).frame(width:72,alignment:.leading); ForEach(1...3,id:\.self) { n in Button { value.wrappedValue = value.wrappedValue == n ? n-1:n } label: { Image(systemName:value.wrappedValue >= n ? "circle.fill":"circle").foregroundStyle(color).frame(width:26,height:26).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel("\(title) \(n)") }; Spacer(); Text("\(value.wrappedValue)/3").font(.caption).monospacedDigit() }
    }
}
