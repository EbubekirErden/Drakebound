# Changelog

## 0.26.0 - Initial Git baseline

This release records the current Drakebound application after its initial development. Earlier application version numbers predate this repository history; these commits do not reconstruct those earlier releases.

### Features

- Native offline macOS character sheets, character creation, and class-level advancement.
- Fight Club character/compendium XML imports and local JSON backups.
- Compendium filtering, custom entries, multi-select transfers, and explicit destination selection.
- Character and active-creature actions, independent counters, concentration, death saves, and play-history undo.
- Equipment containers and modifiers; visual journal editing; image banners and framing.
- Compact two-page printable character/spell sheets with optional reference appendices.
- Option-based attack/spell editors and a reusable dice calculator with deterministic formula previews.

### Repository baseline

- `feat:` captures the app source, native build, and icon generator.
- `test:` captures the regression suites and test runners.
- `fix:` excludes generated builds and personal exports.
- `milestone:` records this baseline and its documentation.
- Annotated release tag: `v0.26.0`.

## Future releases

Use focused commits with prefixes such as `feat:`, `fix:`, `test:`, and `milestone:`. Add release notes here and create a new version tag when a release is ready. Do not move an existing release tag to later work.
