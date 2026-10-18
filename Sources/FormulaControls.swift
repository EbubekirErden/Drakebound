import SwiftUI

let alignmentChoices=["Lawful Good","Neutral Good","Chaotic Good","Lawful Neutral","Neutral","Chaotic Neutral","Lawful Evil","Neutral Evil","Chaotic Evil","Unaligned"]
let damageTypeChoices=["Acid","Bludgeoning","Cold","Fire","Force","Lightning","Necrotic","Piercing","Poison","Psychic","Radiant","Slashing","Thunder","Healing","None"]
let spellSchoolChoices=["Abjuration","Conjuration","Divination","Enchantment","Evocation","Illusion","Necromancy","Transmutation"]

/// Imported/custom values remain selectable; opening a picker never normalizes or replaces them.
struct OptionField:View {
    var title:String
    @Binding var value:String
    var choices:[String]
    @State private var custom=false
    @State private var draft=""
    var body:some View {
        Picker(title,selection:Binding(get:{ value },set:{ selection in if selection == "__custom__" { draft=value;custom=true } else { value=selection } })) {
            if !choices.contains(value) { Text(value.isEmpty ? "Choose…":value).tag(value) }
            ForEach(choices,id:\.self) { Text($0).tag($0) }
            Divider(); Text("Custom…").tag("__custom__")
        }.labelsHidden().accessibilityLabel(title).popover(isPresented:$custom) {
            VStack(alignment:.leading,spacing:12) { Text("Custom "+title.lowercased()).font(.headline); TextField(title,text:$draft).textFieldStyle(.roundedBorder); HStack { Button("Cancel") { custom=false }; Spacer(); Button("Use value") { value=draft;custom=false }.buttonStyle(.borderedProminent) } }.padding(16).frame(width:300)
        }
    }
}

struct DiceFormulaField:View {
    @Binding var value:String
    var hero:Hero? = nil
    var spell:Spell? = nil
    var slot=0
    var allowTokens=false
    var allowEmpty=false
    var compact=false
    var onRoll:((String)->Void)? = nil
    @State private var showing=false
    var body:some View {
        Button { showing=true } label: {
            HStack(spacing:8) { Text(value.isEmpty ? "Choose dice…":value).font(.system(size:compact ? 11:12,weight:.medium,design:.monospaced)).lineLimit(1); Spacer(minLength:2); Image(systemName:"plus.forwardslash.minus").font(.system(size:11)).foregroundStyle(accent) }.padding(.horizontal,9).frame(height:28).frame(maxWidth:.infinity).background(ink.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius:6)).overlay(RoundedRectangle(cornerRadius:6).stroke(ink.opacity(0.12)))
        }.buttonStyle(.plain).accessibilityLabel("Build dice formula: "+(value.isEmpty ? "empty":value)).help("Open dice calculator").popover(isPresented:$showing) {
            DiceCalculator(initial:value,hero:hero,spell:spell,slot:slot,allowTokens:allowTokens,allowEmpty:allowEmpty,onApply:{ value=$0;showing=false },onCancel:{ showing=false },onRoll:onRoll)
        }
    }
}
private enum DiceKeyPage:String,CaseIterable { case dice="Dice",abilities="Abilities",values="Values" }
struct DiceCalculator:View {
    var initial:String
    var hero:Hero?
    var spell:Spell?
    var slot:Int
    var allowTokens:Bool
    var allowEmpty:Bool
    var onApply:(String)->Void
    var onCancel:()->Void
    var onRoll:((String)->Void)?
    @State private var draft=DiceDraft(expression:"")
    @State private var page=DiceKeyPage.dice
    @State private var advanced=false
    @State private var customSides=12
    @State private var customDie=false
    var summary:DiceFormulaSummary? { draft.summary(hero:hero,spell:spell,slot:slot,allowTokens:allowTokens) }
    var body:some View {
        VStack(alignment:.leading,spacing:11) {
            HStack { Text("Dice calculator").font(.headline); Spacer(); Button("Cancel",action:onCancel).font(.caption) }
            VStack(alignment:.leading,spacing:6) {
                Text(draft.expression.isEmpty ? "0":draft.expression).font(.system(size:20,weight:.semibold,design:.monospaced)).lineLimit(2).frame(maxWidth:.infinity,minHeight:34,alignment:.trailing).accessibilityLabel("Formula preview: "+draft.expression)
                if let summary {
                    Text((summary.resolved == draft.expression ? "":summary.resolved+"  ·  ")+"Range \(summary.minimum)…\(summary.maximum)  ·  Average "+String(format:"%.1f",summary.average)).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(2)
                } else { Text(draft.expression.isEmpty ? "Choose dice or enter a number":"Finish the formula to apply it").font(.system(size:10)).foregroundStyle(.secondary) }
            }.padding(12).frame(maxWidth:.infinity).background(paper.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius:8))
            if allowTokens && hero != nil {
                Picker("Keypad",selection:$page) { ForEach(DiceKeyPage.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            }
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:4),spacing:6) {
                ForEach(Array(keys.enumerated()),id:\.offset) { _,key in keyButton(key) }
            }
            HStack(spacing:6) { Button("Clear") { draft.expression="" }; Button { draft.backspace() } label: { Image(systemName:"delete.left") }.accessibilityLabel("Delete last character or value"); Spacer(); if let onRoll,let summary { Button("Roll") { onRoll(summary.resolved) }.tint(sky) }; Button("Use formula") { onApply(draft.expression) }.buttonStyle(.borderedProminent).disabled(summary == nil && !(allowEmpty && draft.expression.isEmpty)) }
            DisclosureGroup("Advanced formula",isExpanded:$advanced) { TextField("e.g. 2d6+3",text:$draft.expression).font(.system(size:12,design:.monospaced)).textFieldStyle(.roundedBorder).padding(.top,4) }.font(.caption)
        }.padding(16).frame(width:330).tint(accent).onAppear { draft.expression=initial }
        .popover(isPresented:$customDie) { VStack(alignment:.leading,spacing:12) { Text("Custom die").font(.headline); Stepper("Sides: \(customSides)",value:$customSides,in:2...1000); HStack { Button("Cancel") { customDie=false }; Spacer(); Button("Add die") { draft.die(customSides);customDie=false } } }.padding(16).frame(width:240) }
    }
    var keys:[String] {
        let top:[String]
        switch page { case .dice:top=["d4","d6","d8","d10","d12","d20","d100","dx"];case .abilities:top=["STR","DEX","CON","INT","WIS","CHA","PROF","SPELL"];case .values:top=["PROF","LEVEL","SLOT","SPELL","ATTACK","DC","+","−"] }
        return top+["7","8","9","+","4","5","6","−","1","2","3","⌫","0","00","C","±"]
    }
    func keyButton(_ key:String) -> some View {
        Button { press(key) } label: { Text(key).font(.system(size:key.count > 4 ? 10:14,weight:.medium,design:.rounded)).frame(maxWidth:.infinity).frame(height:34).foregroundStyle(["+","−","±"].contains(key) ? accent:ink).background(ink.opacity(key.first == "d" || key.first?.isLetter == true ? 0.07:0.035)).clipShape(RoundedRectangle(cornerRadius:5)) }.buttonStyle(.plain).accessibilityLabel("Calculator "+key)
    }
    func press(_ key:String) {
        switch key {
        case "+":draft.operation("+")
        case "−":draft.operation("-")
        case "±":draft.toggleSign()
        case "⌫":draft.backspace()
        case "C":draft.expression=""
        case "00":draft.digit(0);draft.digit(0)
        case "dx":customDie=true
        default:
            if key.hasPrefix("d"),let sides=Int(key.dropFirst()) { draft.die(sides) }
            else if let number=Int(key) { draft.digit(number) }
            else { draft.token(key.lowercased()) }
        }
    }
}
