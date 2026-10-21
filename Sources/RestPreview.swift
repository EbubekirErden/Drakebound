import Foundation

struct RestPreview {
    struct Row:Identifiable {
        var title:String
        var value:String
        var id:String { title }
    }
    var after:Hero
    var rows:[Row] = []
    var resources:[String] = []
    var note:String
    init(hero:Hero,event:CounterReset) {
        var recovered = hero
        switch event {
        case .shortRest: recovered.resetCounters(for:.shortRest)
        case .longRest: recovered.longRest()
        case .fullRest: recovered.fullRest()
        case .manual: break
        }
        after = recovered
        func change(_ before:Int,_ after:Int) -> String { before == after ? "\(after)":"\(before) → \(after)" }
        rows.append(Row(title:"HP",value:change(hero.hp,recovered.hp)+" / \(hero.maximumHP)"))
        let slots = hero.slots.indices.filter { hero.slots[$0] > 0 }.map { i in
            "L\(i+1) "+change(max(0,hero.slots[i]-hero.usedSlots[i]),max(0,recovered.slots[i]-recovered.usedSlots[i]))
        }
        if !slots.isEmpty { rows.append(Row(title:"Slots left",value:slots.joined(separator:" · "))) }
        rows.append(Row(title:"Hit dice left",value:change(max(0,hero.level-hero.hitDiceUsed),max(0,recovered.level-recovered.hitDiceUsed))+" / \(hero.level)"))
        if (hero.exhaustionLevel ?? 0) > 0 { rows.append(Row(title:"Exhaustion",value:change(hero.exhaustionLevel ?? 0,recovered.exhaustionLevel ?? 0))) }
        if hero.tempHP != recovered.tempHP { rows.append(Row(title:"Temporary HP",value:change(hero.tempHP,recovered.tempHP))) }
        if hero.deathSuccesses != recovered.deathSuccesses || hero.deathFailures != recovered.deathFailures { rows.append(Row(title:"Death saves",value:"Cleared")) }
        if hero.concentratingSpell != nil && recovered.concentratingSpell == nil { rows.append(Row(title:"Concentration",value:"Ends")) }
        for choice in hero.resourceChoices {
            if let counter = recovered.resourceChoices.first(where:{ $0.ref == choice.ref })?.counter,counter.current > choice.counter.current { resources.append(choice.counter.name) }
        }
        for spell in hero.spells {
            if let maximum = spell.freeUses,maximum > 0,
               let restored = recovered.spells.first(where:{ $0.id == spell.id }),
               (restored.freeRemaining ?? maximum) > (spell.freeRemaining ?? maximum) { resources.append(spell.name+" free uses") }
        }
        switch event {
        case .shortRest: note = "Spend hit dice using Hit dice on the Sheet. Only resources assigned to Short rest refill."
        case .longRest: note = "Full HP recovery · \(hero.edition) hit-dice recovery. Only resources assigned to Long rest refill."
        case .fullRest: note = "House rule: full HP and hit-dice recovery; clears all exhaustion. Resources follow their Full rest settings."
        case .manual: note = "Manual recovery."
        }
    }
}
