# Contributing to Drakebound

Drakebound is a native, offline personal character tracker. Keep changes focused, preserve imported/custom character choices, and explain any change to saved data or game calculations.

## Set up

Use an Apple silicon Mac with macOS 14 or later and the macOS Swift toolchain from Xcode or Command Line Tools. No package manager setup is required. See [README.md](README.md#build-from-source) for the build command and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for a source map.

## Protect character data first

Follow [AGENTS.md](AGENTS.md) before development, tests, previews, installations, or repairs:

- Back up `characters.json`, `compendium.json`, and `activity.json` from `~/Library/Application Support/Fellowship5e/`, including portraits in the character archive. Validate JSON and verify SHA-256 hashes of the copies.
- Keep timestamped, verified copies in both `output/backups/` and `~/Documents/Drakebound Backups/`; preserve older backups. Never commit them.
- Run fixtures and previews against a physically separate temporary save directory. Check the path before creating a Store or writing fixtures.
- Hash live saves before and after preview/test runs. If anything changes unexpectedly, stop and investigate. Never restore a test snapshot over live character data.

## Work alongside other changes

Check `git status` and existing diffs before editing. Preserve unrelated work. Coordinate edits to shared files, especially `Sources/Models.swift`, `Sources/App.swift`, the README, and the changelog. Keep source files in their current locations: the build discovers `Sources/*.swift`, while test scripts list many inputs explicitly.

## Validate the change

After completing the backup and isolation steps, run checks relevant to the files changed:

| Command | Purpose |
| --- | --- |
| `bash scripts/test.sh` | Model, rules, import, and supporting regression harnesses. |
| `bash scripts/test-ui.sh` | Editor interaction, resizing, responsive layout, and appearance checks. |
| `bash scripts/test-pdf.sh` | Character PDF export checks. |
| `bash scripts/test-quick-note.sh` | Isolated quick-note interaction checks. |
| `bash scripts/build.sh` | Compile and ad-hoc sign the app. |

These scripts compile harnesses and can write generated files. They do not replace the backup and live-save checks. Additional feature-specific scripts may be present under `scripts/`; inspect them before running. Do not run builds while another contributor is using the same generated output directory.

Optional importer checks accept private local fixtures:

```sh
bash scripts/test.sh "/path/to/character.xml" "/path/to/compendium.xml"
```

Keep fixtures out of Git. Documentation-only edits need link and diff review rather than an app rebuild.

## Submit a change

Explain the problem, resulting behavior, validation performed, and any remaining limitations. Use focused commit messages such as `feat:`, `fix:`, `docs:`, or `test:`. Update the user guide for behavioral changes and the Unreleased section of [CHANGELOG.md](CHANGELOG.md) for user-visible changes.

Use synthetic examples and redacted screenshots. Do not submit character archives, personal journal entries, portraits, or third-party compendium content. This repository currently has no declared license; do not assume an open-source license or add one without the owner's decision.
