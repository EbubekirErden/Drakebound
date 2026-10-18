#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
CORE=(Sources/BundledSRD.swift Sources/QuickNote.swift Sources/ListOrdering.swift Sources/GuideLoadoutSummary.swift Sources/GuideNavigation.swift Sources/CompendiumSearch.swift Sources/SpellComponents.swift Sources/WeaponAutomation.swift Sources/FeatureEffects.swift Sources/Currency.swift Sources/CreationGuidance.swift Sources/EquipmentTraining.swift Sources/StarterKits.swift Sources/OriginBonuses.swift Sources/DiceDraft.swift Sources/CompendiumTransfer.swift Sources/CreatureActions.swift Sources/Activity.swift Sources/DeathSaves.swift Sources/Concentration.swift Sources/SourceFilters.swift Sources/PlayActions.swift Sources/Inventory.swift Sources/StatExplanations.swift Sources/GuideCatalog.swift Sources/BuildRules.swift Sources/Templates.swift Sources/Progression.swift Sources/Catalog.swift Sources/Compendium.swift Sources/Models.swift Sources/Mechanics.swift Sources/Content.swift Sources/Actions.swift Sources/Conditions.swift Sources/FightClubImport.swift)
TEST_CASES=(BundledSRDTests ModelTests ImportActionTests ConditionTests CompendiumTests ProgressionTests PlaySheetTests SessionActionsTests ConcentrationTests ActivityTests CreatureTransferTests DiceDraftTests OriginBonusTests CreationGuidanceTests CurrencyTests FeatureEffectTests WeaponAutomationTests SpellScalingTests CompendiumSearchTests GuideNavigationTests GuideLoadoutSummaryTests ListOrderingTests JournalTagTests QuickNoteTests WelcomeArchiveTests)
if [ "${3:-}" = "--progression" ]; then TEST_CASES=(ProgressionTests OriginBonusTests CreationGuidanceTests CurrencyTests FeatureEffectTests WeaponAutomationTests SpellScalingTests); fi
if [ "${3:-}" = "--play" ]; then TEST_CASES=(PlaySheetTests SessionActionsTests ConcentrationTests ActivityTests CreatureTransferTests DiceDraftTests OriginBonusTests CreationGuidanceTests CurrencyTests FeatureEffectTests WeaponAutomationTests SpellScalingTests); fi
if [ "${3:-}" = "--journal" ]; then TEST_CASES=(ModelTests); fi
if [ "${3:-}" = "--spells" ]; then TEST_CASES=(SpellScalingTests SessionActionsTests); fi
for TEST in "${TEST_CASES[@]}"; do
  xcrun swiftc -module-cache-path build/module-cache "${CORE[@]}" "Tests/$TEST.swift" -o "build/$TEST"
  if { [ "$TEST" = "ProgressionTests" ] || [ "$TEST" = "PlaySheetTests" ]; } && [ "$#" -gt 1 ]; then
    "build/$TEST" "$1" "$2"
  elif [ "$TEST" = "ImportActionTests" ] && [ "$#" -gt 0 ]; then
    "build/$TEST" "$1"
  elif { [ "$TEST" = "CreationGuidanceTests" ] || [ "$TEST" = "WeaponAutomationTests" ]; } && [ "$#" -gt 1 ]; then
    "build/$TEST" "$2"
  elif [ "$TEST" = "CompendiumTests" ] && [ "$#" -gt 1 ]; then
    "build/$TEST" "$2" "$1"
  else
    "build/$TEST"
  fi
done
xcrun swiftc -module-cache-path build/module-cache Sources/ImageSupport.swift Tests/ImageTests.swift -o build/ImageTests -framework AppKit -framework ImageIO
build/ImageTests

xcrun swiftc -module-cache-path build/module-cache "${CORE[@]}" Sources/JournalText.swift Sources/JournalFormatting.swift Tests/JournalTests.swift -o build/JournalTests -framework AppKit
build/JournalTests

xcrun swiftc -module-cache-path build/module-cache Sources/SpellComponents.swift Tests/SpellComponentsTests.swift -o build/SpellComponentsTests
build/SpellComponentsTests

xcrun swiftc -module-cache-path build/module-cache Sources/DescriptionMarkdownRules.swift Tests/DescriptionMarkdownTests.swift -o build/DescriptionMarkdownTests
build/DescriptionMarkdownTests
