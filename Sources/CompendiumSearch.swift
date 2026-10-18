import Foundation

enum CompendiumSearch {
    static func normalized(_ text:String) -> String {
        text.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX")).trimmingCharacters(in:.whitespacesAndNewlines)
    }
    static func classNames(_ entry:CompendiumEntry) -> [String] {
        (entry.template?.spell?.classes ?? entry.value("classes")).components(separatedBy:",").map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    static func matches(name:String,summary:String,classes:String,source:String,description:String = "",query:String,includeDescription:Bool = false) -> Bool {
        let terms = normalized(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return true }
        let haystack = normalized([name,summary,classes,source,includeDescription ? description:""].joined(separator:" "))
        return terms.allSatisfy { haystack.contains($0) }
    }
    static func matches(_ entry:CompendiumEntry,query:String,includeDescription:Bool = false) -> Bool {
        if normalized(query).isEmpty { return true }
        return matches(name:entry.name,summary:entry.summary,classes:classNames(entry).joined(separator:", "),source:entry.sourceDescription,description:includeDescription ? entry.text:"",query:query,includeDescription:includeDescription)
    }
    static func precedes(_ a:CompendiumEntry,_ b:CompendiumEntry,query:String) -> Bool {
        let query = normalized(query)
        func rank(_ name:String) -> Int {
            let name = normalized(name)
            if query.isEmpty { return 3 }
            if name == query { return 0 }
            if name.hasPrefix(query) { return 1 }
            return query.split(whereSeparator: \.isWhitespace).allSatisfy { name.contains($0) } ? 2:3
        }
        let first=rank(a.name),second=rank(b.name)
        return first == second ? a.name.localizedStandardCompare(b.name) == .orderedAscending:first < second
    }
}
