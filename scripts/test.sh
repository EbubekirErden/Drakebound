#!/bin/bash
# Compiles every regression harness in parallel (skipping ones whose inputs are unchanged), then runs them in order.
# Optional fixture arguments are unchanged: test.sh [character.xml] [compendium.xml] [--progression|--play|--journal|--spells]
# Harnesses never touch live character data. Set DRAKEBOUND_ARCHIVE_FIXTURE to a COPY of an archive to also verify it decodes.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache build/test-logs
CORE=(Sources/GlobalSearch.swift Sources/CharacterExport.swift Sources/RestPreview.swift Sources/ArchiveWriter.swift Sources/BundledSRD.swift Sources/QuickNote.swift Sources/ListOrdering.swift Sources/GuideLoadoutSummary.swift Sources/GuideNavigation.swift Sources/CompendiumSearch.swift Sources/SpellComponents.swift Sources/WeaponAutomation.swift Sources/FeatureEffects.swift Sources/Currency.swift Sources/CreationGuidance.swift Sources/EquipmentTraining.swift Sources/StarterKits.swift Sources/OriginBonuses.swift Sources/DiceDraft.swift Sources/CompendiumTransfer.swift Sources/CreatureActions.swift Sources/Activity.swift Sources/DeathSaves.swift Sources/Concentration.swift Sources/SourceFilters.swift Sources/PlayActions.swift Sources/Inventory.swift Sources/StatExplanations.swift Sources/GuideCatalog.swift Sources/BuildRules.swift Sources/Templates.swift Sources/Progression.swift Sources/Catalog.swift Sources/Compendium.swift Sources/Models.swift Sources/Mechanics.swift Sources/Content.swift Sources/Actions.swift Sources/Conditions.swift Sources/FightClubImport.swift)
TEST_CASES=(CombatSearchTests ArchiveWriterTests BundledSRDTests ModelTests ImportActionTests ConditionTests CompendiumTests ProgressionTests PlaySheetTests SessionActionsTests ConcentrationTests ActivityTests CreatureTransferTests DiceDraftTests OriginBonusTests CreationGuidanceTests CurrencyTests FeatureEffectTests WeaponAutomationTests SpellScalingTests CompendiumSearchTests GuideNavigationTests GuideLoadoutSummaryTests ListOrderingTests JournalTagTests QuickNoteTests WelcomeArchiveTests)
if [ "${3:-}" = "--progression" ]; then TEST_CASES=(ProgressionTests OriginBonusTests CreationGuidanceTests CurrencyTests FeatureEffectTests WeaponAutomationTests SpellScalingTests); fi
if [ "${3:-}" = "--play" ]; then TEST_CASES=(PlaySheetTests SessionActionsTests ConcentrationTests ActivityTests CreatureTransferTests DiceDraftTests OriginBonusTests CreationGuidanceTests CurrencyTests FeatureEffectTests WeaponAutomationTests SpellScalingTests); fi
if [ "${3:-}" = "--journal" ]; then TEST_CASES=(ModelTests); fi
if [ "${3:-}" = "--spells" ]; then TEST_CASES=(SpellScalingTests SessionActionsTests); fi
JOBS="${DRAKEBOUND_TEST_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

# name|extra swiftc inputs (besides the test file)|use core sources (1/0)|extra flags
SPECS=()
for TEST in "${TEST_CASES[@]}"; do SPECS+=("$TEST||1|"); done
SPECS+=("ImageTests|Sources/ImageSupport.swift|0|-framework AppKit -framework ImageIO")
SPECS+=("JournalTests|Sources/JournalText.swift Sources/JournalFormatting.swift|1|-framework AppKit")
SPECS+=("SpellComponentsTests|Sources/SpellComponents.swift|0|")
SPECS+=("DescriptionMarkdownTests|Sources/DescriptionMarkdownRules.swift|0|")

compile_one() {
  IFS='|' read -r NAME EXTRA USE_CORE FLAGS <<< "$1"
  INPUTS=(); [ "$USE_CORE" = "1" ] && INPUTS+=("${CORE[@]}")
  # shellcheck disable=SC2206
  INPUTS+=($EXTRA "Tests/$NAME.swift")
  OUT="build/$NAME"
  if [ -x "$OUT" ]; then
    FRESH=1; for F in "${INPUTS[@]}"; do [ "$F" -nt "$OUT" ] && { FRESH=0; break; }; done
    [ "$FRESH" = "1" ] && [ "scripts/test.sh" -ot "$OUT" ] && return 0
  fi
  # shellcheck disable=SC2086
  xcrun swiftc -module-cache-path build/module-cache "${INPUTS[@]}" -o "$OUT" $FLAGS > "build/test-logs/$NAME.compile.log" 2>&1 \
    || { echo "COMPILE FAILED: $NAME"; cat "build/test-logs/$NAME.compile.log"; return 1; }
}
export -f compile_one
export CORE_LIST="${CORE[*]}"
printf '%s\n' "${SPECS[@]}" | xargs -P "$JOBS" -I{} bash -c 'IFS=" " read -r -a CORE <<< "$CORE_LIST"; compile_one "$1"' _ {} 

run_test() {
  local TEST="$1"
  if { [ "$TEST" = "ProgressionTests" ] || [ "$TEST" = "PlaySheetTests" ]; } && [ -n "${ARG1:-}" ] && [ -n "${ARG2:-}" ]; then "build/$TEST" "$ARG1" "$ARG2"
  elif [ "$TEST" = "ImportActionTests" ] && [ -n "${ARG1:-}" ]; then "build/$TEST" "$ARG1"
  elif { [ "$TEST" = "CreationGuidanceTests" ] || [ "$TEST" = "WeaponAutomationTests" ]; } && [ -n "${ARG2:-}" ]; then "build/$TEST" "$ARG2"
  elif [ "$TEST" = "CompendiumTests" ] && [ -n "${ARG2:-}" ]; then "build/$TEST" "$ARG2" "${ARG1:-}"
  else "build/$TEST"; fi
}
ARG1="${1:-}"; ARG2="${2:-}"
FAILED=()
for SPEC in "${SPECS[@]}"; do
  NAME="${SPEC%%|*}"
  run_test "$NAME" || FAILED+=("$NAME")
done
if [ "${#FAILED[@]}" -gt 0 ]; then echo "FAILED: ${FAILED[*]}"; exit 1; fi
echo "All ${#SPECS[@]} harnesses passed."
