import Foundation

struct CurrencyBalance:Codable,Equatable,Identifiable {
    var id:String
    var name:String
    var minorUnits:Int = 0
    var formatted:String { Self.format(minorUnits) }
    static let limit=99_999_999_999
    static func format(_ units:Int) -> String { String(units/100)+String(format:".%02d",units%100) }
    static func parse(_ text:String) -> Int? {
        let value=text.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:",",with:".")
        guard value.range(of:"^[0-9]+(?:\\.[0-9]{1,2})?$",options:.regularExpression) != nil else { return nil }
        let parts=value.split(separator:".");guard let whole=Int(parts[0]),whole <= limit/100 else { return nil }
        let fraction=parts.count == 2 ? Int(String(parts[1]).padding(toLength:2,withPad:"0",startingAt:0)) ?? 0:0
        let result=whole*100+fraction;return result <= limit ? result:nil
    }
}
enum CurrencyOperation:String,CaseIterable { case add="Add",spend="Spend",set="Set" }
enum CurrencyError:LocalizedError {
    case invalid,insufficient,duplicate
    var errorDescription:String? { switch self { case .invalid:return "Use a positive amount with up to two decimal places.";case .insufficient:return "Not enough currency to spend that amount.";case .duplicate:return "Choose a unique currency name (up to 32 characters)." } }
}
extension Hero {
    var currencyBalances:[CurrencyBalance] {
        [CurrencyBalance(id:"gp",name:"gp",minorUnits:gold*100+(goldMinorUnits ?? 0))]+["cp","sp","ep","pp"].map { key in (currencies ?? []).first { $0.id == key } ?? CurrencyBalance(id:key,name:key) }+(currencies ?? []).filter { !["gp","cp","sp","ep","pp"].contains($0.id) }
    }
    mutating func addCurrency(named name:String) throws -> String {
        let clean=name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !clean.isEmpty,clean.count <= 32,!currencyBalances.contains(where:{ $0.name.caseInsensitiveCompare(clean) == .orderedSame }) else { throw CurrencyError.duplicate }
        let id=UUID().uuidString;currencies=(currencies ?? [])+[CurrencyBalance(id:id,name:clean)];return id
    }
    mutating func changeCurrency(_ id:String,amount:Int,operation:CurrencyOperation) throws {
        guard (0...CurrencyBalance.limit).contains(amount),let currency=currencyBalances.first(where:{ $0.id == id }) else { throw CurrencyError.invalid }
        let value:Int
        switch operation { case .add:guard currency.minorUnits <= CurrencyBalance.limit-amount else { throw CurrencyError.invalid };value=currency.minorUnits+amount
        case .spend:guard currency.minorUnits >= amount else { throw CurrencyError.insufficient };value=currency.minorUnits-amount
        case .set:value=amount }
        if id == "gp" { gold=value/100;goldMinorUnits=value%100 }
        else { var all=currencies ?? [];if let i=all.firstIndex(where:{ $0.id == id }) { all[i].minorUnits=value } else { var copy=currency;copy.minorUnits=value;all.append(copy) };currencies=all }
    }
}
func validateCurrency(_ hero:Hero) throws {
    let all=hero.currencies ?? []
    guard (0...CurrencyBalance.limit/100).contains(hero.gold),(0...99).contains(hero.goldMinorUnits ?? 0),Set(all.map(\.id)).count == all.count,!all.contains(where:{ $0.id == "gp" }),all.allSatisfy({ !$0.id.isEmpty && !$0.name.isEmpty && $0.name.count <= 32 && (0...CurrencyBalance.limit).contains($0.minorUnits) }),Set(hero.currencyBalances.map { $0.name.lowercased() }).count == hero.currencyBalances.count else { throw CocoaError(.fileReadCorruptFile) }
}
