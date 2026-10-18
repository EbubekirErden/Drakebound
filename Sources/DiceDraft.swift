import Foundation

struct DiceFormulaSummary:Equatable {
    var resolved:String
    var minimum:Int
    var maximum:Int
    var average:Double
}
/// Button composition and previews never roll dice or mutate a character.
struct DiceDraft {
    var expression:String
    mutating func digit(_ number:Int) { guard (0...9).contains(number),expression.count < 256 else { return }; let term=expression.split(whereSeparator:{ $0 == "+" || $0 == "-" }).last.map(String.init) ?? ""
        if (expression.last != "+" && expression.last != "-") && (term.lowercased().contains("d") || expression.last == "}") { expression += "+" }
        expression += String(number)
    }
    mutating func operation(_ sign:String) {
        guard sign == "+" || sign == "-" else { return }
        if expression.last == "+" || expression.last == "-" { expression.removeLast() }
        if !expression.isEmpty || sign == "-" { expression += sign }
    }
    mutating func die(_ sides:Int) {
        guard (2...1000).contains(sides) else { return }
        // A number currently being entered becomes the die count; a completed term starts a new one.
        let term=expression.split(whereSeparator:{ $0 == "+" || $0 == "-" }).last.map(String.init) ?? ""
        if expression.last != "+" && expression.last != "-" && !term.isEmpty && term.allSatisfy(\.isNumber) { expression += "d\(sides)" }
        else { appendTerm("1d\(sides)") }
    }
    mutating func token(_ name:String) { guard ["str","dex","con","int","wis","cha","prof","spell","attack","dc","level","slot"].contains(name) else { return }; appendTerm("{\(name)}") }
    mutating func appendTerm(_ value:String) {
        if let last=expression.last,last != "+" && last != "-" { expression += "+" }
        expression += value
    }
    mutating func backspace() {
        guard !expression.isEmpty else { return }
        if expression.last == "}",let start=expression.lastIndex(of:"{") { expression.removeSubrange(start...) }
        else {
            let start=expression.lastIndex(where:{ $0 == "+" || $0 == "-" }).map { expression.index(after:$0) } ?? expression.startIndex
            if expression[start...].lowercased().contains("d") { expression.removeSubrange(start...) }
            else { expression.removeLast() }
        }
    }
    mutating func toggleSign() {
        if let sign=expression.lastIndex(where:{ $0 == "+" || $0 == "-" }) {
            expression.replaceSubrange(sign...sign,with:expression[sign] == "+" ? "-":"+")
            if expression.first == "+" { expression.removeFirst() }
        } else { expression="-"+expression }
    }
    func summary(hero:Hero? = nil,spell:Spell? = nil,slot:Int = 0,allowTokens:Bool = false) -> DiceFormulaSummary? {
        var value=expression.lowercased().filter { !$0.isWhitespace }
        guard !value.isEmpty,value.count <= 2048 else { return nil }
        if allowTokens,let hero {
            let casting=spell?.castingAbility ?? hero.castingAbility
            let tokens=["str":hero.modifier(0),"dex":hero.modifier(1),"con":hero.modifier(2),"int":hero.modifier(3),"wis":hero.modifier(4),"cha":hero.modifier(5),"prof":hero.proficiency,"spell":hero.modifier(casting),"attack":hero.proficiency+hero.modifier(casting)+hero.flat(["attack","spellAttack"]),"dc":8+hero.proficiency+hero.modifier(casting)+hero.flat(["spellDC"]),"level":hero.level,"slot":slot]
            for (key,number) in tokens { value=value.replacingOccurrences(of:"{\(key)}",with:String(number)) }
            value=value.replacingOccurrences(of:"%0",with:String(hero.modifier(casting)))
        }
        if allowTokens && hero != nil { for _ in 0..<3 { value=value.replacingOccurrences(of:"+-",with:"-").replacingOccurrences(of:"--",with:"+").replacingOccurrences(of:"-+",with:"-").replacingOccurrences(of:"++",with:"+") } }
        guard let regex=try? NSRegularExpression(pattern:"([+-]?)([0-9]+d[0-9]+|[0-9]+)") else { return nil }
        let ns=value as NSString, matches=regex.matches(in:value,range:NSRange(location:0,length:ns.length))
        guard !matches.isEmpty,matches.count <= 100,matches.map({ ns.substring(with:$0.range) }).joined() == value else { return nil }
        var low=0,high=0,average=0.0
        for match in matches {
            let sign=ns.substring(with:match.range(at:1)) == "-" ? -1:1
            let part=ns.substring(with:match.range(at:2))
            if part.contains("d") {
                let pair=part.split(separator:"d").compactMap { Int($0) }
                guard pair.count == 2,(1...100).contains(pair[0]),(2...1000).contains(pair[1]) else { return nil }
                let minimum=pair[0],maximum=pair[0]*pair[1]
                low += sign > 0 ? minimum:-maximum; high += sign > 0 ? maximum:-minimum
                average += Double(sign*pair[0])*Double(pair[1]+1)/2
            } else {
                guard let amount=Int(part),amount <= 100000 else { return nil }
                low += sign*amount;high += sign*amount;average += Double(sign*amount)
            }
        }
        return DiceFormulaSummary(resolved:value,minimum:low,maximum:high,average:average)
    }
}
