import Foundation

enum CompendiumSource:String,CaseIterable { case revised = "2024",ua = "UA",homebrew = "Homebrew",custom = "Custom",unmarked = "Unmarked" }
enum CompendiumScope:String,CaseIterable { case all = "All sources",curated = "2024 + custom",ua = "Unearthed Arcana",homebrew = "Homebrew",custom = "Custom only",unmarked = "Unmarked sources"
    func includes(_ entry:CompendiumEntry,ua:Bool = false,homebrew:Bool = false) -> Bool {
        if self == .all { return true }
        let source = entry.sourceMark
        switch self {
        case .all:return true
        case .curated:return source == .revised || source == .custom || (ua && source == .ua) || (homebrew && source == .homebrew)
        case .ua:return source == .ua
        case .homebrew:return source == .homebrew
        case .custom:return source == .custom
        case .unmarked:return source == .unmarked
        }
    }
}
extension CompendiumEntry {
    var sourceLabels:[String] {
        func labels(_ fields:[ReferenceField]) -> [String] {
            fields.flatMap { field -> [String] in
                let own = field.name.lowercased() == "source" ? [field.text]:field.text.components(separatedBy:.newlines).compactMap { line -> String? in
                    let trimmed = line.trimmingCharacters(in:.whitespaces)
                    guard trimmed.lowercased().hasPrefix("source:") else { return nil }
                    return String(trimmed.dropFirst(7)).trimmingCharacters(in:.whitespaces)
                }
                return own+labels(field.children)
            }
        }
        return Array(Set(labels(fields).filter { !$0.isEmpty })).sorted()
    }
    var sourceMark:CompendiumSource {
        if custom == true { return .custom }
        // A class's optional subclass sources do not identify the parent class.
        let direct = fields.filter { $0.children.isEmpty }
        let metadata = ([name]+direct.flatMap { field -> [String] in
            if field.name.lowercased() == "source" { return [field.text] }
            return field.text.components(separatedBy:.newlines).compactMap { line in
                let trimmed = line.trimmingCharacters(in:.whitespaces)
                return trimmed.lowercased().hasPrefix("source:") ? String(trimmed.dropFirst(7)):nil
            }
        }).joined(separator:" ").lowercased()
        if metadata.contains("unearthed arcana") || metadata.contains("[ua]") || metadata.contains("(ua)") { return .ua }
        if metadata.contains("homebrew") || metadata.contains("[hb]") || metadata.contains("(hb)") { return .homebrew }
        if metadata.contains("2024") { return .revised }
        return .unmarked
    }
    var sourceDescription:String { ([sourceMark.rawValue]+sourceLabels).joined(separator:" · ") }
}
