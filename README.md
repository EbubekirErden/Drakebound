# Drakebound for Mac

A native, offline character companion for tabletop fifth-edition play. Keep your character sheet, spells, equipment, dice, notes, and companions together in a personal macOS workspace.

Built with SwiftUI for **Apple silicon Macs running macOS 14 or later**. No server or subscription is required.

[Download releases](https://github.com/EbubekirErden/Drakebound/releases) · [User guide](docs/USER_GUIDE.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)

## Get started

1. Open the [Releases page](https://github.com/EbubekirErden/Drakebound/releases) and choose a release with a downloadable app attached. GitHub's automatic source archives do not contain a built app.
2. Download and extract the app archive, then drag `Drakebound.app` into Applications.
3. Open Drakebound and create a character or import a Drakebound JSON backup or compatible Fight Club character XML.
4. Import your own compendium XML for additional spells, equipment, creatures, and character options.

If no app download is attached yet, see [Build from source](#build-from-source). Local builds are ad-hoc signed and are not Developer ID signed or notarized; macOS may require explicit approval to open a downloaded build. See [Apple's guidance](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).

## What you can do

| Area | Features |
| --- | --- |
| Character sheet | Ability checks, saves, skills, HP, temporary HP, death saves, conditions, and resource counters. |
| Actions and dice | Attack and damage rolls, custom formulas, favorites, concentration, and play history with undo for supported changes. |
| Spells | Searchable spellbook, preparation, slots, casting, upcasting, and configurable rolls. |
| Equipment | Containers, quantities, currencies, attunement, armor effects, and linked weapon attacks. |
| Creation and advancement | Guided character creation and level-up with explicit choices and a review before applying. |
| Journal and companions | Notes, images, tags, quick capture, and creature records with independent HP and attacks. |
| References | Searchable compendium, custom entries, and Fight Club XML imports. |
| Portability | Additive JSON backup import, backup export, and printable character PDFs. |

See the [user guide](docs/USER_GUIDE.md) for detailed controls and compatibility notes. Documentation describes the current working tree; check the selected release's notes for what its download includes.

## Your data

Character data stays on your Mac. For compatibility with earlier versions, Drakebound uses:

```text
~/Library/Application Support/Fellowship5e/
```

The main character archive is `characters.json`; compendium and activity history use separate JSON files. Character images are embedded in the saved archive. Use **Export → Backup JSON…** regularly and before replacing an app version. A character PDF is a printable snapshot, not an editable backup.

JSON imports add characters with new IDs rather than replacing existing ones. Character backup JSON does not include the separate local activity history. For a complete local safety copy, preserve the entire save folder. Never attach your private archives or compendium library to a public issue.

## Compatibility and scope

Drakebound is a personal character tracker. Imported reference descriptions do not automatically implement every rule, prerequisite, or class choice; manual overrides remain part of the workflow.

- Fight Club character XML import supports tested export shapes; edited-character XML export and full two-way compatibility are not implemented.
- The starter library is small. Import references you have permission to use; this repository does not provide a complete rules database.
- Cloud sync, encounter initiative ordering, and automatic familiar/summon rules are not implemented.
- Multiclass Spellcasting and Pact Magic do not have separate automatic slot pools; mixed Pact Magic needs a manual counter.

## Build from source

Requires macOS, Apple silicon, and Xcode or Command Line Tools with the macOS Swift toolchain. There are no third-party package dependencies.

```sh
git clone https://github.com/EbubekirErden/Drakebound.git
cd Drakebound
bash scripts/build.sh
```

The app is written to `build/Drakebound.app`. The build script targets `arm64-apple-macosx14.0` and ad-hoc signs the bundle. Read [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) before development, tests, or previews to protect existing character data.

## Repository layout

```text
Sources/       Swift application, views, importers, and character rules
Tests/         Regression and interaction test harnesses
scripts/       Build, test, and generated-icon scripts
docs/          User guide, architecture notes, and release checklist
.github/       Issue and pull request templates
build/         Generated apps, binaries, and caches (ignored)
output/        Private backups, exports, and previews (ignored)
```

Read [the architecture notes](docs/ARCHITECTURE.md) to navigate the source and [the release checklist](docs/RELEASING.md) before packaging a download.

## Feedback and contributions

[Report a bug or suggest an improvement](https://github.com/EbubekirErden/Drakebound/issues). Include the app version, macOS version, reproduction steps, and a redacted screenshot when useful. See [CONTRIBUTING.md](CONTRIBUTING.md) for development and validation guidance.

Drakebound is independently built and is not affiliated with Lion’s Den or Wizards of the Coast. Product names belong to their respective owners. No open-source license has been declared in this repository; public availability alone does not grant reuse rights.
