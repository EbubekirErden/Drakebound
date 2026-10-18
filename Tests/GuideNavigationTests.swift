import Foundation
@main struct GuideNavigationTests {
 static func main() throws {
  var creation=CharacterBuildDraft()
  let originalProblems=creation.problems
  assert(creation.guideIssues.map(\.message) == originalProblems)
  assert(creation.guideIssues.first { $0.message.contains("name.") }?.step == .identity)
  assert(creation.guideIssues.first { $0.message.contains("ancestry") }?.step == .origin)
  assert(creation.guideIssues.first { $0.message.contains("background") }?.step == .origin)
  assert(creation.guideIssues.first { $0.message.contains("class skills") }?.step == .training)
  assert(creation.guideIssues.filter { creation.originBonusProblems.contains($0.message) }.allSatisfy { $0.step == .abilities })
  creation.changeAbilityMethod(.pointBuy);creation.manualScores=Array(repeating:15,count:6)
  assert(creation.guideIssues.first { $0.message.contains("Point buy") }?.step == .abilities)
  creation.hpAdjustment = -200
  assert(creation.guideIssues.first { $0.message.contains("Maximum HP") }?.step == .abilities)
  assert(!creation.guideSteps.contains(.vitality))
  let hero=Hero.sample
  let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys
  let encoded=try encoder.encode(hero)
  var level=CharacterBuildDraft(hero:hero);level.hpMethod = .rolled
  assert(level.guideIssues.first { $0.message.contains("HP die") }?.step == .vitality)
  level.hero.slots[0]=0;level.hero.usedSlots[0]=1
  assert(level.guideIssues.first { $0.message.contains("Slot totals") }?.step == .loadout)
  for issue in level.guideIssues { assert(level.guideSteps.contains(issue.step)) }
  let after=try encoder.encode(hero);assert(after == encoded)
  assert(level.guideIssues.map(\.message) == level.problems)
  print("PASS: guide issue destinations, origin bonuses, creation HP routing, level-up slots, available steps and unchanged validation/data")
 }
}
