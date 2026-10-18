import Foundation

struct BannerCrop: Codable, Equatable {
    var x = 0.5
    var y = 0.3
    var zoom = 1.0
}
enum RollMode: String, CaseIterable, Codable { case normal = "Normal", advantage = "ADV", disadvantage = "DIS" }
enum D20Kind: String, CaseIterable, Codable { case check = "Ability check", save = "Saving throw", attack = "Attack", initiative = "Initiative" }
struct ConditionDefinition: Identifiable {
    var id: String { name }
    var name: String
    var summary: String
    var reminder: String
}
let conditionDefinitions = [
    ConditionDefinition(name:"Blinded",summary:"Attack disadvantage.",reminder:"Sight checks fail; incoming attacks gain advantage."),
    ConditionDefinition(name:"Charmed",summary:"Cannot harm the charmer.",reminder:"Charmer gains social-check advantage; choose targets manually."),
    ConditionDefinition(name:"Deafened",summary:"Hearing checks fail.",reminder:"Judge hearing-dependent checks at the table."),
    ConditionDefinition(name:"Frightened",summary:"Check/attack disadvantage while the source is visible.",reminder:"Cannot willingly approach the source."),
    ConditionDefinition(name:"Grappled",summary:"Speed becomes zero.",reminder:"Resolve escape, dragging, and target-specific penalties manually."),
    ConditionDefinition(name:"Incapacitated",summary:"Actions and casting unavailable.",reminder:"Concentration ends. 2024 initiative has disadvantage."),
    ConditionDefinition(name:"Invisible",summary:"Attack advantage against creatures unable to see you.",reminder:"Incoming attacks and detection depend on senses."),
    ConditionDefinition(name:"Paralyzed",summary:"Incapacitated; no movement; STR/DEX saves fail.",reminder:"Incoming advantage and nearby critical hits are table effects."),
    ConditionDefinition(name:"Petrified",summary:"Incapacitated; no movement; STR/DEX saves fail.",reminder:"Apply damage resistance and poison immunity at the table."),
    ConditionDefinition(name:"Poisoned",summary:"Attack and check disadvantage.",reminder:"Poison damage is separate from this condition."),
    ConditionDefinition(name:"Prone",summary:"Attack disadvantage.",reminder:"Crawling, standing, and incoming attacks depend on distance."),
    ConditionDefinition(name:"Restrained",summary:"No movement; attack and DEX-save disadvantage.",reminder:"Incoming attacks gain advantage."),
    ConditionDefinition(name:"Stunned",summary:"Incapacitated; STR/DEX saves fail.",reminder:"2014 prevents movement; 2024 does not. Incoming advantage."),
    ConditionDefinition(name:"Unconscious",summary:"Incapacitated; no movement; STR/DEX saves fail.",reminder:"Also prone; resolve awareness and nearby critical hits manually.")
]
extension Hero {
    var edition: String { rulesEdition ?? (characterClass.contains("2024") ? "2024":"2014") }
    func hasCondition(_ name:String) -> Bool { conditions.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }
    var isIncapacitated: Bool { ["Incapacitated","Paralyzed","Petrified","Stunned","Unconscious"].contains(where:hasCondition) }
    var canAct: Bool { !isIncapacitated && (exhaustionLevel ?? 0) < 6 }
    var movementPrevented: Bool { ["Grappled","Restrained","Paralyzed","Petrified","Unconscious"].contains(where:hasCondition) || (edition == "2014" && hasCondition("Stunned")) || (exhaustionLevel ?? 0) >= (edition == "2014" ? 5:6) }
    var testPenalty: Int { edition == "2024" ? -2*(exhaustionLevel ?? 0):0 }
    func rollMode(for kind:D20Kind,ability:Int? = nil,manual:RollMode = .normal) -> RollMode {
        let exhaustion = exhaustionLevel ?? 0
        var advantage = manual == .advantage
        var disadvantage = manual == .disadvantage
        if kind == .attack {
            advantage = advantage || (hasCondition("Invisible") && invisibleToTarget == true)
            disadvantage = disadvantage || ["Blinded","Restrained","Prone"].contains(where:hasCondition)
        }
        if kind == .check || kind == .attack || kind == .initiative {
            disadvantage = disadvantage || (hasCondition("Poisoned") && !hasCondition("Petrified")) || (hasCondition("Frightened") && fearSourceVisible == true)
        }
        if kind == .save && ability == 1 && hasCondition("Restrained") { disadvantage = true }
        if kind == .initiative && edition == "2024" && isIncapacitated { disadvantage = true }
        if kind == .initiative && edition == "2024" && hasCondition("Invisible") { advantage = true }
        if edition == "2014" {
            if exhaustion >= 1 && (kind == .check || kind == .initiative) { disadvantage = true }
            if exhaustion >= 3 && (kind == .attack || kind == .save) { disadvantage = true }
        }
        return advantage == disadvantage ? .normal:advantage ? .advantage:.disadvantage
    }
    func performD20(_ expression:String,label:String,kind:D20Kind,ability:Int? = nil,manual:RollMode = .normal) throws -> RollResult {
        if kind == .attack && !canAct { throw ActionError.cannotAct }
        if kind == .save, let ability, [0,1].contains(ability), ["Paralyzed","Petrified","Stunned","Unconscious"].contains(where:hasCondition) {
            return RollResult(label:label,expression:"Automatic failure · active condition",dice:[],total:0,event:true)
        }
        let adjusted = testPenalty == 0 ? expression:expression+signed(testPenalty)
        return try Dice.d20(adjusted,label:label,mode:rollMode(for:kind,ability:ability,manual:manual))
    }
    func performNamedRoll(_ roll:NamedRoll,source:String,spell:Spell? = nil,slot:Int = 0,manual:RollMode = .normal) throws -> RollResult {
        let expression = try resolveRoll(roll.expression,spell:spell,slot:slot)
        if let kind = roll.kind { return try performD20(expression,label:"\(source) · \(roll.name)",kind:kind,ability:roll.ability,manual:manual) }
        return try Dice.d20(expression,label:"\(source) · \(roll.name)",mode:manual)
    }
}
extension Dice {
    static func bounds(_ expression:String) -> ClosedRange<Int>? {
        let clean = expression.lowercased().filter { !$0.isWhitespace }
        guard let regex = try? NSRegularExpression(pattern:"([+-]?)([0-9]+d[0-9]+|[0-9]+)") else { return nil }
        let ns = clean as NSString
        let matches = regex.matches(in:clean,range:NSRange(location:0,length:ns.length))
        guard !matches.isEmpty, matches.map({ ns.substring(with:$0.range) }).joined() == clean else { return nil }
        var low = 0; var high = 0
        for m in matches {
            let negative = ns.substring(with:m.range(at:1)) == "-"
            let token = ns.substring(with:m.range(at:2))
            if token.contains("d") {
                let parts = token.split(separator:"d").compactMap { Int($0) }
                guard parts.count == 2, (1...100).contains(parts[0]), (2...1000).contains(parts[1]) else { return nil }
                low += negative ? -parts[0]*parts[1]:parts[0]
                high += negative ? -parts[0]:parts[0]*parts[1]
            } else { guard let value = Int(token), value <= 100000 else { return nil }; low += negative ? -value:value; high += negative ? -value:value }
        }
        return low...high
    }
    static func d20(_ expression:String,label:String,mode:RollMode) throws -> RollResult {
        var result = try roll(expression,label:label)
        guard mode != .normal, expression.lowercased().filter({ !$0.isWhitespace }).hasPrefix("1d20"), result.sides.first == 20 else { return result }
        let first = result.dice[0]; let second = Int.random(in:1...20)
        let kept = mode == .advantage ? max(first,second):min(first,second)
        result.total += kept-first; result.dice.insert(second,at:1); result.sides.insert(20,at:1)
        result.keptD20 = kept
        result.keptD20Index = first == kept ? 0:1
        result.detail = "\(mode.rawValue) · d20 \(first), \(second) → \(kept)"
        return result
    }
}
