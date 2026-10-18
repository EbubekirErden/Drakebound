import Foundation

struct ConcentrationSave:Codable,Identifiable,Equatable {
    var id = UUID()
    var spellID:UUID
    var damage:Int
    var dc:Int
}
extension Hero {
    var concentrationSaves:[ConcentrationSave] { (pendingConcentrationSaves ?? []).filter { $0.spellID == concentrationSpellID && concentratingSpell != nil && hp > 0 && !isIncapacitated } }
    mutating func endConcentration() { concentrationSpellID = nil; pendingConcentrationSaves = nil }
    mutating func queueConcentrationSave(damage:Int) {
        reconcileConcentration()
        guard damage > 0,let id = concentrationSpellID else { return }
        let dc = max(10,damage/2)
        pendingConcentrationSaves = concentrationSaves + [ConcentrationSave(spellID:id,damage:damage,dc:edition == "2024" ? min(30,dc):dc)]
    }
    var concentrationSaveExpression:String { expression("1d20",bonus:saveBonus(2),targets:["saves","save.2"]) }
    func concentrationRollMode(_ manual:RollMode) -> RollMode {
        let conditional = rollMode(for:.save,ability:2,manual:manual)
        let advantage = concentrationSaveAdvantage == true || manual == .advantage
        let disadvantage = manual == .disadvantage || (edition == "2014" && (exhaustionLevel ?? 0) >= 3)
        if advantage && disadvantage { return .normal }
        return advantage ? .advantage:conditional
    }
    mutating func resolveConcentrationSave(_ id:UUID,total:Int,dc:Int? = nil) throws -> RollResult {
        guard let save = concentrationSaves.first(where:{ $0.id == id }),(-100000...100000).contains(total),(1...100000).contains(dc ?? save.dc) else { throw PlayError.missingAction }
        let target = dc ?? save.dc
        let name = concentratingSpell!.name
        let success = total >= target
        pendingConcentrationSaves?.removeAll { $0.id == id }
        if pendingConcentrationSaves?.isEmpty == true { pendingConcentrationSaves = nil }
        if !success { endConcentration() }
        return RollResult(label:"Concentration · "+name,expression:"Manual total \(total) · DC \(target)",dice:[],total:total,event:true,detail:success ? "Success · concentration maintained":"Failed · concentration ended")
    }
    mutating func rollConcentrationSave(_ id:UUID,manual:RollMode = .normal,dc:Int? = nil) throws -> RollResult {
        guard let save = concentrationSaves.first(where:{ $0.id == id }),(1...100000).contains(dc ?? save.dc) else { throw PlayError.missingAction }
        // Conditions and exhaustion are handled once; concentration-only advantage is combined above.
        var result = try Dice.d20(concentrationSaveExpression+(testPenalty == 0 ? "":signed(testPenalty)),label:"Concentration · "+concentratingSpell!.name,mode:concentrationRollMode(manual))
        let outcome = try resolveConcentrationSave(id,total:result.total,dc:dc)
        result.detail = [result.detail,"DC \(dc ?? save.dc)",outcome.detail].compactMap { $0 }.joined(separator:" · ")
        return result
    }
}
