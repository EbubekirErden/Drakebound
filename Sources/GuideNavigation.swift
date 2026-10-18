import Foundation

enum GuideStep:String,CaseIterable {
    case identity = "Identity", origin = "Class & origin", abilities = "Abilities", vitality = "Hit points", training = "Training", features = "Features", loadout = "Spells & gear", review = "Review"
    var heading:String { switch self { case .identity:return "Meet your adventurer"; case .origin:return "Choose your path"; case .abilities:return "Shape your abilities"; case .vitality:return "Grow your resilience"; case .training:return "Choose your training"; case .features:return "Make your feature choices"; case .loadout:return "Prepare for adventure"; case .review:return "Review your character" } }
    var hint:String { switch self { case .identity:return "Start with a name and rules edition. You can add a portrait now or later."; case .origin:return "Use a familiar class, browse your compendium, or enter a custom option."; case .abilities:return "Assign scores and any explicit increases. The preview updates as you choose."; case .vitality:return "Choose fixed HP, roll a hit die, or enter your table’s roll."; case .training:return "Record only the saves, skills, languages, and tools your choices grant."; case .features:return "Read and select the features you gain. Subclass and optional features are individual choices."; case .loadout:return "Set slot totals, choose spells, and add equipment. Preview any choice before adding it."; case .review:return "Check each summary below. Expand a row for details or use Edit to revisit a step." } }
}
struct GuideIssue:Identifiable {
    var message:String
    var step:GuideStep
    var id:String
}
extension CharacterBuildDraft {
    var guideSteps:[GuideStep] {
        isLevelUp ? [.origin]+(asiAvailable || !abilityOverrideReason.isEmpty ? [.abilities]:[])+[.vitality,.training,.features,.loadout,.review]:[.identity,.origin,.abilities,.training,.features,.loadout,.review]
    }
    var guideIssues:[GuideIssue] {
        let abilitiesStep:GuideStep = guideSteps.contains(.abilities) ? .abilities:.features
        return problems.enumerated().map { index,message in
            let text=message.lowercased()
            let destination:GuideStep
            if originBonusProblems.contains(message) || improvementProblems.contains(message) { destination=abilitiesStep }
            else if text == "give your character a name." { destination=isLevelUp ? .review:.identity }
            else if text.contains("class skills") { destination = .training }
            else if text.contains("ability") || text.contains("asi ") || text.contains("point buy") || text.contains("six ability") { destination=abilitiesStep }
            else if text.contains("hp") || text.contains("hit point") { destination=isLevelUp ? .vitality:.abilities }
            else if text.contains("slot totals") { destination = .loadout }
            else if text.contains("class") || text.contains("ancestry") || text.contains("background") || text.contains("level 20") { destination = .origin }
            else { destination = .review }
            return GuideIssue(message:message,step:destination,id:"\(index):\(message)")
        }
    }
}
