#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
xcrun swiftc -module-cache-path build/module-cache Sources/CreationGuidance.swift Sources/EquipmentTraining.swift Sources/StarterKits.swift Sources/OriginBonuses.swift Sources/CompendiumTransfer.swift Sources/CreatureActions.swift Sources/Activity.swift Sources/DeathSaves.swift Sources/Concentration.swift Sources/SourceFilters.swift Sources/PlayActions.swift Sources/Inventory.swift Sources/StatExplanations.swift Sources/GuideCatalog.swift Sources/BuildRules.swift Sources/Templates.swift Sources/Progression.swift Sources/Catalog.swift Sources/Compendium.swift Sources/Models.swift Sources/Mechanics.swift Sources/Content.swift Sources/Actions.swift Sources/Conditions.swift Sources/FightClubImport.swift Sources/CharacterPDF.swift Tests/CharacterPDFTests.swift -o build/CharacterPDFTests -framework AppKit -framework PDFKit
build/CharacterPDFTests "$@"
