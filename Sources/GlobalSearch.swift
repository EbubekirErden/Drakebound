import Foundation

enum SearchTarget:Equatable {
    case spell(UUID),item(UUID),feature(UUID),attack(UUID),creature(UUID),action(SheetActionRef)
    case reference(UUID),librarySpell(UUID),condition(String)
}
struct GlobalSearchResult:Identifiable,Equatable {
    var id:String
    var name:String
    var subtitle:String
    var kind:String
    var character:Bool
    var target:SearchTarget
    var searchable:String
    init(name:String,subtitle:String,kind:String,character:Bool,target:SearchTarget,id:String,keywords:String = "") {
        self.name=name;self.subtitle=subtitle;self.kind=kind;self.character=character;self.target=target;self.id=id
        searchable=CompendiumSearch.normalized([name,subtitle,kind,keywords].joined(separator:" "))
    }
}
struct GlobalSearchIndex {
    var entries:[GlobalSearchResult] = []
    init(hero:Hero?,library:[Spell],compendium:[CompendiumEntry]) {
        if let hero {
            for spell in hero.spells {
                entries.append(GlobalSearchResult(name:spell.name,subtitle:(spell.level == 0 ? "Cantrip":"Level \(spell.level)")+" · "+spell.school+(spell.prepared ? "":" · not prepared"),kind:"Spell",character:true,target:.spell(spell.id),id:"spell:"+spell.id.uuidString,keywords:spell.classes ?? ""))
            }
            for item in hero.items {
                entries.append(GlobalSearchResult(name:item.name,subtitle:item.equipmentKind.rawValue+(item.equipped ? " · equipped":" · carried"),kind:"Equipment",character:true,target:.item(item.id),id:"item:"+item.id.uuidString))
            }
            for feature in hero.featureEntries ?? [] {
                entries.append(GlobalSearchResult(name:feature.name,subtitle:feature.category?.rawValue ?? "Feature",kind:"Feature",character:true,target:.feature(feature.id),id:"feature:"+feature.id.uuidString,keywords:feature.source ?? ""))
            }
            for attack in hero.attacks {
                entries.append(GlobalSearchResult(name:attack.name,subtitle:hero.attackUnavailableReason(attack) ?? "Ready attack",kind:"Attack",character:true,target:.attack(attack.id),id:"attack:"+attack.id.uuidString))
            }
            for creature in hero.creatures ?? [] {
                entries.append(GlobalSearchResult(name:creature.name,subtitle:creature.type+" · companion",kind:"Creature",character:true,target:.creature(creature.id),id:"creature:"+creature.id.uuidString))
            }
            for action in hero.creatureActions {
                entries.append(GlobalSearchResult(name:action.name,subtitle:action.subtitle,kind:"Companion action",character:true,target:.action(action.ref),id:"action:"+action.id))
            }
        }
        for condition in conditionReferences {
            entries.append(GlobalSearchResult(name:condition.name,subtitle:condition.summary,kind:"Condition",character:false,target:.condition(condition.id),id:"condition:"+condition.id,keywords:condition.text+" rules"))
        }
        for entry in compendium {
            entries.append(GlobalSearchResult(name:entry.name,subtitle:entry.summary,kind:entry.category.singular,character:false,target:.reference(entry.id),id:"reference:"+entry.id.uuidString,keywords:entry.sourceDescription))
        }
        let referenceIDs=Set(compendium.map(\.id))
        for spell in library where !referenceIDs.contains(spell.id) {
            entries.append(GlobalSearchResult(name:spell.name,subtitle:(spell.level == 0 ? "Cantrip":"Level \(spell.level)")+" · "+spell.school,kind:"Spell",character:false,target:.librarySpell(spell.id),id:"library:"+spell.id.uuidString,keywords:spell.classes ?? ""))
        }
    }
    func search(_ query:String,limit:Int = 60)->[GlobalSearchResult] {
        let normalized=CompendiumSearch.normalized(query)
        let terms=normalized.split(whereSeparator:\.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return [] }
        func rank(_ entry:GlobalSearchResult)->Int {
            let name=CompendiumSearch.normalized(entry.name)
            return name == normalized ? 0:name.hasPrefix(normalized) ? 1:terms.allSatisfy { name.contains($0) } ? 2:3
        }
        return Array(entries.filter { entry in terms.allSatisfy { entry.searchable.contains($0) } }.sorted { a,b in
            if a.character != b.character { return a.character }
            let first=rank(a),second=rank(b)
            if first != second { return first < second }
            let order=a.name.localizedStandardCompare(b.name)
            return order == .orderedSame ? a.id < b.id:order == .orderedAscending
        }.prefix(max(0,limit)))
    }
}
