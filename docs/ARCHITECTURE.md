# Repository and source map

[Project overview](../README.md) · [Contributing](../CONTRIBUTING.md)

Drakebound uses SwiftUI and AppKit with no third-party dependencies. It is compiled directly by shell scripts, rather than through a Swift package or an Xcode project.

## Layout and build constraints

Application sources live directly in `Sources/`. `scripts/build.sh` compiles `Sources/*.swift`, generates icon assets through `scripts/icon.swift`, writes the bundle metadata, and ad-hoc signs `build/products.noindex/Drakebound.app`.

Tests are executable Swift harnesses under `Tests/`. Scripts compile explicit source lists for different areas. Moving a file into a nested source directory requires updating the build glob and every affected test input list. Keep the existing layout until a dedicated structural refactor can be tested independently.

`build/` and `output/` are generated/local directories and are ignored by Git. Personal archives belong outside tracked source. `docs/` contains detailed documentation; `.github/` contains collaboration templates.

## Where to start

| Area | Representative files in `Sources/` |
| --- | --- |
| Application shell | `App.swift`, `AppCommands.swift` |
| State and persistence | `Store.swift` (state), `StorePersistence.swift` (saving, imports, backups), `ArchiveWriter.swift` (ordered background writes), `Models.swift` |
| Main workspace and navigation | `ContentViews.swift`, `NavigationViews.swift`, `Appearance.swift` |
| Creation and level-up | `CharacterGuide.swift`, `GuideStore.swift`, `GuideSteps.swift`, `Progression.swift` |
| Rules and play state | `Mechanics.swift`, `PlayActions.swift`, `Conditions.swift`, `Concentration.swift`, `DeathSaves.swift`, `Activity.swift` |
| Actions and spells | `Actions.swift`, `ActionViews.swift`, `SpellRowViews.swift`, `SpellUpcastViews.swift` |
| Inventory and equipment | `Inventory.swift`, `EquipmentViews.swift`, `WeaponAutomation.swift`, `EquipmentTraining.swift` |
| Compendium and XML imports | `Compendium.swift`, `CompendiumSearch.swift`, `CompendiumTransfer.swift`, `FightClubImport.swift` |
| Journal and quick capture | `JournalEditor.swift`, `JournalText.swift`, `QuickNote.swift`, `QuickNoteViews.swift` |
| Export and images | `CharacterPDF.swift`, `PDFExportView.swift`, `ImageSupport.swift` |

This is a navigation aid, not a strict module boundary; many views and rules share the central models. Verify call sites before changing persistence or calculations.

## Bundled reference data

`Resources/SRD/` contains generated CC BY 4.0 references, notices, provenance, and the official PDF. The build copies this directory into the signed app. `BundledSRD.swift` validates and loads resources, merges by stable IDs with user records, and removes unchanged bundled copies when persisting the local library. Modified records and custom copies remain persisted. Character data is not a content source. See the resource README for conversion inputs and licensing.

## Persistence boundaries

The application retains the historical `Fellowship5e` save-directory name. Character archives, compendium data, and local activity history have separate files. Images are embedded in character data. JSON character exports are editable backups; PDFs are static snapshots. Activity history is separate from character backup exports.

Fixtures and previews must never create a Store at the live save location. The backup, isolation, and hash-verification requirements in [AGENTS.md](../AGENTS.md) apply before development and execution.
