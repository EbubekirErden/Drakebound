import SwiftUI

struct ConcentrationStatus:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text("CONCENTRATION").font(.system(size:10,weight:.semibold)).tracking(1).foregroundStyle(sky)
            if let spell=hero.concentratingSpell {
                HStack(alignment:.top,spacing:8) {
                    Label(spell.name,systemImage:"sparkle.magnifyingglass").font(.system(size:12,weight:.medium)).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading)
                    Button { hero.endConcentration() } label: { Label("End",systemImage:"xmark").font(.system(size:10,weight:.medium)) }.buttonStyle(.plain).foregroundStyle(sky).accessibilityLabel("End concentration on "+spell.name)
                }
            } else { Text("Not concentrating").font(.system(size:11)).foregroundStyle(.secondary) }
            ConcentrationSavePrompt(hero:$hero,store:store)
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(surface,in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(ink.opacity(0.07)))
    }
}

struct ConcentrationSavePrompt:View {
    @Binding var hero:Hero
    @ObservedObject var store:Store
    @State private var details:ConcentrationSave?
    @State private var outcome = ""
    @State private var succeeded = true
    var body:some View {
        Group {
            if let save = hero.concentrationSaves.first {
                VStack(alignment:.leading,spacing:8) {
                    HStack(spacing:8) {
                    Image(systemName:"shield.lefthalf.filled").foregroundStyle(gold)
                    VStack(alignment:.leading,spacing:3) {
                        Text("Concentration save · DC \(save.dc)").font(.system(size:11,weight:.semibold))
                        Text("\(save.damage) damage"+(hero.concentrationSaves.count > 1 ? " · \(hero.concentrationSaves.count) pending":"")).font(.system(size:9)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength:4)
                    if hero.concentrationSaveAdvantage == true { Text("ADV").font(.system(size:9,weight:.semibold)).foregroundStyle(gold).help("Concentration advantage is enabled in save details. Opposing disadvantage cancels it.") }
                    }
                    ControlFlowLayout(spacing:8) {
                    RollChoiceButton(explanation:hero.saveExplanation(2)+"\nConcentration advantage: \(hero.concentrationSaveAdvantage == true ? "enabled":"off")") { mode in
                        do { record(try hero.rollConcentrationSave(save.id,manual:mode ?? store.rollMode)) } catch { store.error = error.localizedDescription }
                    } label: { Text("Roll save").font(.system(size:11,weight:.semibold)).foregroundStyle(sky).padding(7).background(sky.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:6)) }
                    Button("Enter result…") { details = save }.font(.system(size:11)).help("Enter a physical-dice total, adjust the DC, or configure concentration advantage")
                    }
                }.padding(9).background(gold.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(gold.opacity(0.22)))
            } else if !outcome.isEmpty {
                HStack { Text(outcome).font(.system(size:10)).foregroundStyle(succeeded ? leaf:coral); Spacer(); Button { outcome = "" } label: { Image(systemName:"xmark").font(.system(size:9)) }.buttonStyle(.plain).accessibilityLabel("Dismiss concentration save result") }
            }
        }.popover(item:$details) { save in ConcentrationSaveDetails(hero:$hero,save:save,defaultMode:store.rollMode,onResult:record,onError:{ store.error = $0 }) }
    }
    func record(_ result:RollResult) {
        store.record(result)
        outcome = result.detail ?? "Save resolved"
        succeeded = hero.concentratingSpell != nil
    }
}
struct ConcentrationSaveDetails:View {
    @Binding var hero:Hero
    var save:ConcentrationSave
    var defaultMode:RollMode
    var onResult:(RollResult)->Void
    var onError:(String)->Void
    @FocusState private var totalFocused:Bool
    @State private var total = ""
    @State private var dcText = ""
    @Environment(\.dismiss) private var dismiss
    var dc:Int? { guard let number = Int(dcText),(1...100000).contains(number) else { return nil }; return number }
    var manualTotal:Int? { guard let number = Int(total),(-100000...100000).contains(number) else { return nil }; return number }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Text("Concentration save").font(.headline); Spacer(); Button("Done") { dismiss() } }
            Text(hero.concentratingSpell?.name ?? "Concentration ended").font(.system(size:12,weight:.medium)).foregroundStyle(sky)
            HStack { Text("DC"); TextField("DC",text:$dcText).frame(width:60).accessibilityLabel("Concentration save DC"); Spacer(); Text("\(save.damage) damage").foregroundStyle(.secondary) }.font(.caption)
            Text(hero.edition == "2024" ? "2024: higher of 10 or half damage rounded down, capped at DC 30." : "2014: higher of 10 or half damage rounded down.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            Toggle("Advantage on concentration saves",isOn:Binding(get:{ hero.concentrationSaveAdvantage ?? false },set:{ hero.concentrationSaveAdvantage = $0 })).font(.caption)
            Text("Enable for a feature such as War Caster. Feature text does not enable this automatically; disadvantage still cancels advantage.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            Text("CON save: "+hero.concentrationSaveExpression+(hero.testPenalty == 0 ? "":signed(hero.testPenalty))).font(.system(size:11,design:.monospaced)).help(hero.saveExplanation(2))
            Divider()
            TextField("Physical dice · final total",text:$total).focused($totalFocused).accessibilityLabel("Physical concentration save total").onSubmit(resolveManual)
            Text("Enter the final total including modifiers. Closing this panel leaves the save pending.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            HStack {
                RollChoiceButton(explanation:hero.saveExplanation(2)) { mode in
                    guard let dc else { return }
                    do { onResult(try hero.rollConcentrationSave(save.id,manual:mode ?? defaultMode,dc:dc)); dismiss() } catch { onError(error.localizedDescription) }
                } label: { Text("Roll CON save") }.disabled(dc == nil)
                Spacer()
                Button("Apply total",action:resolveManual).buttonStyle(.borderedProminent).disabled(manualTotal == nil || dc == nil)
            }.font(.caption)
        }.padding(18).frame(width:350).textFieldStyle(.roundedBorder).tint(sky).onAppear { dcText = String(save.dc); totalFocused = true }
    }
    func resolveManual() {
        guard let dc,let manualTotal else { return }
        do { onResult(try hero.resolveConcentrationSave(save.id,total:manualTotal,dc:dc)); dismiss() } catch { onError(error.localizedDescription) }
    }
}
