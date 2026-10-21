# Drakebound

An offline fifth-edition character tracker for Mac. Manage your character sheet, spells, equipment, dice, and notes in one place.

**Apple silicon · macOS 14+ · Built with SwiftUI**

## Download

Get the app ZIP from [Releases](https://github.com/EbubekirErden/Drakebound/releases), extract it, and drag **Drakebound.app** to Applications.

Current builds are not notarized, so macOS may require approval to open them.

## Features

- Guided character creation and level-up.
- Character sheets and a dedicated Combat tab with attacks, saves, dice, and resource tracking.
- Compact spellbooks, inventory, journals, and companions, with unified quick-access search (⌘K).
- Offline SRD library and Fight Club XML imports.
- JSON backups and printable character PDFs.

Your characters and imported content stay on your Mac.

## Build

With the macOS Swift toolchain installed, run from the repository root:

```sh
bash scripts/build.sh
```

The app is created at `build/products.noindex/Drakebound.app`. See [Contributing](CONTRIBUTING.md) before development or testing.

## Documentation

[User guide](docs/USER_GUIDE.md) · [Changelog](CHANGELOG.md) · [Report an issue](https://github.com/EbubekirErden/Drakebound/issues)

## Credits

Independent project; not affiliated with Lion’s Den or Wizards of the Coast. Included SRD content is licensed under [CC BY 4.0](Resources/SRD/CC-BY-4.0.txt); see [attribution](Resources/SRD/ATTRIBUTION.txt). No license has been declared for the application code.
