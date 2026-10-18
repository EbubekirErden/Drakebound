import Foundation

enum DeathSaveError:LocalizedError {
    case unavailable,invalidDie
    var errorDescription:String? { self == .unavailable ? "Death saves are rolled at 0 HP, before three successes or failures.":"Enter a natural d20 result from 1 to 20." }
}
extension Hero {
    var needsDeathSave:Bool { hp == 0 && deathSuccesses < 3 && deathFailures < 3 }
    var deathSaveStatus:String { deathFailures >= 3 ? "Three failures":hp > 0 ? "Not needed":deathSuccesses >= 3 ? "Stable":"Death saves needed" }
    mutating func resetDeathSaves() { deathSuccesses = 0; deathFailures = 0 }
    mutating func applyDeathSave(natural:Int,total:Int) throws {
        guard (1...20).contains(natural) else { throw DeathSaveError.invalidDie }
        guard needsDeathSave else { throw DeathSaveError.unavailable }
        if natural == 20 { hp = 1; resetDeathSaves() }
        else if natural == 1 { deathFailures = min(3,deathFailures+2) }
        else if total >= 10 { deathSuccesses = min(3,deathSuccesses+1) }
        else { deathFailures = min(3,deathFailures+1) }
    }
    mutating func rollDeathSave(mode:RollMode = .normal) throws -> RollResult {
        guard needsDeathSave else { throw DeathSaveError.unavailable }
        var result = try performD20(expression("1d20",bonus:flat(["saves"]),targets:["saves"]),label:"Death save",kind:.save,manual:mode)
        let natural = result.keptD20 ?? result.dice.first ?? 0
        try applyDeathSave(natural:natural,total:result.total)
        result.detail = (result.detail.map { $0+" · " } ?? "")+(hp > 0 ? "Natural 20 · regained 1 HP":deathFailures >= 3 ? "Three failed saves":deathSuccesses >= 3 ? "Stable":"\(deathSuccesses) successes · \(deathFailures) failures")
        return result
    }
}
