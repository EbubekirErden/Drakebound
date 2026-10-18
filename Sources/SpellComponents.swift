import Foundation

/// Split only at top-level commas; material requirements may contain their own commas.
struct SpellComponents {
    var parts: [String]
    init(_ value: String) {
        var depth = 0, current = "", result: [String] = []
        for c in value {
            if c == "(" { depth += 1 }
            if c == ")" { depth = max(0, depth - 1) }
            if c == "," && depth == 0 { result.append(current.trimmingCharacters(in: .whitespaces)); current = "" }
            else { current.append(c) }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))
        parts = result.filter { !$0.isEmpty }
    }
    func matches(_ part: String, _ component: String) -> Bool {
        let name = ["V":"VERBAL","S":"SOMATIC","M":"MATERIAL"][component] ?? component
        let upper = part.uppercased()
        return [component,name].contains { upper == $0 || upper.hasPrefix($0 + " ") || upper.hasPrefix($0 + "(") }
    }
    func contains(_ component: String) -> Bool { parts.contains { matches($0, component) } }
    func segment(_ component: String) -> String? { parts.first { matches($0, component) } }
    func setting(_ component: String, enabled: Bool, restored: String? = nil) -> String {
        var updated = parts.filter { !matches($0, component) }
        if enabled { updated.append(restored ?? component) }
        let order = ["V", "S", "M"]
        return updated.sorted { a, b in
            (order.firstIndex { matches(a, $0) } ?? 3) < (order.firstIndex { matches(b, $0) } ?? 3)
        }.joined(separator: ", ")
    }
}

extension SpellComponents {
    var material: String {
        guard let part = segment("M") else { return "" }
        let prefix = part.uppercased().hasPrefix("MATERIAL") ? 8:1
        let tail = String(part.dropFirst(prefix)).trimmingCharacters(in:.whitespacesAndNewlines)
        return tail.hasPrefix("(") && tail.hasSuffix(")") ? String(tail.dropFirst().dropLast()):tail
    }
    func settingMaterial(_ text: String) -> String {
        let detail = text
        return setting("M",enabled:true,restored:detail.isEmpty ? "M":"M (" + detail + ")")
    }
}
