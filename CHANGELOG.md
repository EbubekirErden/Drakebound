# Changelog

## 0.31.2

- Creatures → Add creature opens compact compendium search with type, CR, and source filters, previews, a role choice, and direct addition to the current character. Custom creature creation stays available in the same popover.
- Creature empty states use the measured results width for explicit centering.

## 0.31.1

- Centered the Creatures empty state across the full results area and added a matching centered no-search-results state.

## 0.31.0

- Structured feature effects with flat and per-character-level modifiers, active toggles, and recognized/custom/reference-only modes.
- Recognized Tough feats from compendium apply +2 maximum HP per total character level, including future level-ups; duplicate recognized Tough grants do not stack.
- Feature cards show applied effects; health hover explains maximum HP sources.
- Existing compendium Tough entries receive an idempotent upgrade. Imported Fight Club features remain unchanged unless explicitly enabled; recognizable legacy manual Tough bonuses are not doubled.
- Adding effects keeps full-health characters full, preserves wounded/zero current HP, and clamps HP when the maximum falls.
- Feature-effect edits form activity undo boundaries; custom template copies have independent effects.

## 0.30.3

- Browse compendium feats directly from Features & traits, with search, source filters, prerequisites, full previews, and duplicate-aware Add controls for the current character.

## 0.30.2

- Taller character banners across all sheet tabs (275–380 pt) and creature banners (250 pt), with matching crop previews.

## 0.30.1

- Creature cards expand/collapse with an arrow or their header name. Folded cards retain name, HP, AC, active status, and dismiss/deactivate controls.
- Folding respects Reduce Motion and preserves creature data and expanded trait choices.

## 0.30.0

- Add item opens a compact compendium search with type/source filters, preview, Add, and Custom item options.
- Currency popup supports cp/sp/ep/gp/pp and named custom currencies, with exact two-decimal Add/Spend/Set operations. Existing integer GP balances remain compatible.
- Independent currency balances persist in character saves and JSON backups; no automatic conversion.
- Creature cards offer banner, left portrait, and right portrait layouts with image framing.
- Spell/equipment browser empty states fill and center in the results area.
- Decimal parsing, atomic overspend rejection, legacy balances, backup round trips, and creature layout persistence covered by regressions.
- Verified the equipment search empty state, currency popup, and left portrait in the installed native app.

## 0.29.0

- Caster table available directly in the creator’s spell browser.
- Consolidated duplicate catalog spell choices, preserving custom entries and saved character spells.
- Selected features grouped by category, with optional parent-feature links and safe handling of missing parents.
- Equipment selection filters for type and source.
- Prepare all / unprepare all level 1+ controls in creation and the spellbook.
- Visible weapon/armor proficiency roster and direct controls in Training, Equipment, and character editing.
- Regression coverage for catalog duplicates, class-list merging, custom entries, feature-link cycles, and JSON persistence.

## 0.28.0

- Guided ASI/feat choices attached to selected class milestones, with score caps and reversible allocations.
- Source-aware weapon and armor training, feature grants, and linked weapon attack proficiency.
- Features remain available as references during spell and equipment selection.
- Per-class cantrip, prepared/known spell allowances and spell-level access; explicit exemptions for always-prepared extras.
- Recover recognized cantrips omitted from XML level metadata; exact class-list filtering excludes subclass-only entries.
- Starting equipment choices and pack previews, container expansion, and safeguards against duplicate or mutually exclusive kit additions.
- Regression tests cover ASI choices, training, real compendium cantrips, Cleric allowances, and starting kits.

## 0.27.0

- Standard/custom alignment selectors in character creation and editing.
- Equal-height ancestry browse entries and preview buttons.
- Edition-aware origin ability choices, background ability restrictions, allocation validation, and dismissible rule help.
- Fixed/flexible 2014 ancestry handling; no legacy ancestry increases in 2024 creation.
- Regression coverage for origin patterns, legacy adaptation, source changes, score caps, and level-up preservation.

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
