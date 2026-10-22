# Changelog

## Unreleased

- Combat shows spell save DC and spell attack bonus together in a compact strip, including separate casting abilities and current attack-roll penalties.

## 1.1.0 — 2026-10-21

- Dedicated Combat tab replaces Actions, with compact ready-action rows, spells grouped by level, saving throws, spell slots, resources, and condition controls. Existing numeric shortcuts keep their destinations.
- Unified search (⌘K) finds all characters, journal titles/text/tags, owned spells, equipment, features, attacks, active/inactive companions, and references. Results identify their owner and open the actual entry; copied content IDs remain isolated by character.
- Compact Sheet features open descriptions and use controls in popovers. Attacks and resources share a responsive section. Spellbooks, equipment and creature attacks use smaller rows with direct controls and on-demand details.
- Click equipment quantities for ±1 or Add/Remove/Set controls. Quantity zero retains the inventory entry; changes update weight.
- Concentration and pending saves have a separate status card near combat conditions and saving throws. HP section height stays fixed when concentration changes.
- Conditions is a searchable Compendium category with the same resizable Preview sidebar and detail overlay as other references. Category navigation scrolls horizontally.
- Character banners default to expanded on Sheet and compact on other tabs. The size button remembers per-tab overrides and offers a page-default reset.
- Optional tabs can be hidden per character. Rest reviews are compact; successful imports and selected undoable changes use non-blocking notices. Character JSON/PDF export is separate from the all-character backup entry point. Welcome uses consistent app branding.
- Dice result windows follow Light/Dark/System appearance. Narrow-window and large-text checks cover the main play pages; development bundles stay outside Launchpad indexing.
- Character saves are encoded and written in order on a background queue, skipping unchanged data. Quit, import and level-up still flush pending writes. The character archive format is unchanged.
- Simplified creature-reference score rendering and made save-error task captures explicit for compatibility with older Swift compilers in CI.
- Test and preview Stores use explicit isolated data directories. Regression harnesses compile in parallel and skip unchanged builds; CI verifies rules/data and the app build.

## 1.0.0 — 2026-10-18

- Included offline SRD compendium: 339 spells, 12 core classes with SRD subclasses and progression tables, 9 species, 4 backgrounds, 17 feats, 963 equipment/magic-item references and variants, and 331 creature references. New users can create and browse without importing a library.
- Bundled rules load separately from user records. Stable reference IDs prevent duplicate records on relaunch; imports, custom edits, and existing characters are preserved. 2024 references are labeled by edition and never silently selected for a 2014 class.
- Help includes rules attribution, the CC BY 4.0 license, and the unmodified official SRD 5.2.1 PDF. Sources and adaptation details are included in the app and repository; only the SRD content has this license.
- Creation and level-up discover supported spells directly from compendium references as well as the saved library.


- First launch opens Welcome with guided creation, character import instructions, an optional demo preview, and compendium browsing. Existing character archives open directly into the workspace. Cancelling creation returns to Welcome without creating a character.
- Empty character rosters now save and reload correctly, including after removing the last character. Unreadable archives enter a protected recovery screen and cannot be overwritten by normal saves, creation, or imports.

- Light-mode character, creature, and creation-preview banners blend into the page with soft sage overlays, dark text, and light control backgrounds. Dark-mode image overlays remain unchanged.

- Quick note opens from Journal, the dock, or ⇧⌘J without leaving the current page. Capture text and optional tags, then Add note or ⌘Return; the first nonempty line becomes the title. Capture shows its character and saves into the existing journal. Closing keeps a separate in-memory draft for each character until the app quits.

- Light mode uses softer sage-gray backgrounds and muted off-white cards to reduce glare while preserving text contrast.

- Appearance offers Light, Dark, and System choices in the app menu. The adaptive palette covers existing pages, sheets, popovers, and dice results without changing character rules or layouts; Dark remains the default. Journal rich text stays readable in either appearance.
- Journal notes support optional comma-separated tags, clickable tag chips, and a tag filter. Search includes tags; existing notes, pinning, ordering, and explicit Save/Cancel remain supported.

- Action cards share the tallest natural height in each responsive row, with aligned footers. Spell range/duration tiles also match heights when text wraps; row sizing preserves each card’s natural content height.

- Journal notes support pinning and drag-to-reorder within pinned/unpinned groups. Pins and manual order persist in saves and JSON backups; older notes load unpinned.
- Equipment drag handles reorder items within their current container or Carried group. Cross-container and cross-character drops are rejected; hidden filtered entries retain their positions.
- Note and equipment menus include Move up/Move down alternatives. Reordering commits on drop and preserves entry contents, quantities, equipment state, and container membership.

- Action cards use natural content height, distinct type icons and accents, stronger attack/damage values, and spell range/duration with short description previews. Existing cast, roll, cost, favorite, and critical controls remain available.
- Weapon & armor proficiency fits its content and scrolls when the training list is long, replacing the oversized fixed-height popover.
- Note editor text fills the remaining sheet height instead of staying at 210 points inside an outer scroll view. Image controls remain below the editor, with a compact clickable image preview.

- Empty Frequent/Recent Actions and filtered action lists offer Show all actions, which clears view filters without changing favorites or usage history.
- Sheet sections fold from their headers, retaining key summaries and independent interface preferences. Health stays expanded; the banner menu offers Compact Sheet and Expand all Sheet sections. Compact Sheet keeps attacks, resources, and conditions visible.

- Compendium filters wrap into visible rows and expose removable active-filter chips, result totals, and shown-reference counts. Preview controls distinguish viewing beside results from a larger detail view.
- Shared page toolbars move search and actions onto separate rows when needed, retaining stable popover anchors. Actions, Equipment, and spell filters wrap, with direct reset controls and filtered-result counts.
- Sheet statistics use compact equal-height tiles; feature cards adapt their column count to available width, preserving rolls, feature controls, and existing character rules.

- Creation and level-up use a labeled Preview toggle with a split-panel icon and a visible active state for the preview beside the form.
- Feature eye previews keep presentation state local instead of rebuilding the draft screen. Progress and footer validation avoid repeated evaluations during a refresh.
- Feature, spell, equipment, and reference previews share consistent headings, readable details, and Done controls; source credits appear below reference content. Draft spell and equipment rows and Review lists offer read-only eye previews alongside editing.
- Spellbook and Review expose per-class spell counts and allowances, extra/always-prepared exclusions, and unmatched casting assignments. These summaries preserve existing selection and validation rules.
- Equipment review shows entry, quantity, equipped, attunement, and recorded-weight totals. Starting-pack descriptions and Add equipment controls align left, with source credits below.

- Creation and level-up use shared expandable rows for class settings, origins, training, HP and slot controls; ability scores use an aligned alternating-row table with modifiers.
- Features have searchable Available, Selected, and Needs choice views with inline descriptions and retained configuration controls.
- Spells & gear separates Spells, Equipment, and Attacks, with searchable draft lists, inline details, and matching action controls. Review Edit links open the matching loadout section.
- Level-up preview emphasizes before/after values and changes instead of repeating the full portrait sheet. Reference and spell browsers use shared search/action controls.

- Character creation and level-up review use expandable alternating rows, before/after statistics, a changes-only view, and direct Edit/Fix links; the full change log remains available.
- Wizard Continue explains missing requirements at the current step. Back and direct step navigation stay available; completion markers follow validation and reviewed steps.
- Compendium inspector resizing uses a fixed coordinate space and a drag guide, committing width only on release. Clear all filters is visible beside results, and custom/starter spell cards use the inspector too.

- Detail panels retain their dimensions after dragging; the corner control also expands/restores on click. The compendium inspector has a draggable width divider.
- Source attribution moves into a collapsed Sources section below reference content.
- Spell identity fits in one row, casting panels match heights, and roll fields group formula, effects, and scaling with manual level options in a disclosure.
- Main descriptions support basic Markdown previews, bold/italic and bullet lists; Enter continues a bullet and a second Enter ends the list. Text stays portable through imports and exports.

- Custom editors keep identity and descriptions full-width, with wider adaptive settings columns, consistent Save/Cancel controls, and alternating repeated rows.
- Compendium filters sit together with a spell class-list filter. Multi-term, accent-insensitive search includes classes and sources, with optional description search and closer name matches first.
- Optional right detail inspector keeps browsing visible; expanded details remain available. Detail resize handles have reserved space below action buttons.

- Actions uses the shared page toolbar and matching search/filter controls while retaining its card grid; Manage slots matches the adjacent spell statistics in height.

- Import and Export share an aligned sidebar row; character banners keep Edit/Expand visible and group other actions in the character menu.
- Equipment, Spells, Journal and Creatures share responsive search/action toolbars. Equipment utilities are grouped in a menu; training remains editable in a focused popover.

- Sidebar branding uses a transparent dragon mark; click it to toggle compact mode without a second compact-mode row. Added a local character name/class filter.

- Presentation-only refresh: resizable character sidebar with a compact portrait mode, larger readable character rows, and a consolidated PDF/JSON export menu.
- Shorter character banners with an expand control, matching crop previews, and controls grouped at the top right.
- The dice dock keeps its Roll label on one line and lets die shortcuts scroll when space is tight.
- Journal and creature search share their section headers; spell-slot management sits beside the spell summary. Existing top tabs, character data, rules, and action handlers are preserved.


## 0.33.0

- Edit material requirements below V/S/M; retain embedded component details and import separate XML material fields.
- Damage rolls have an optional damage-type selector and an explicit automatic upcasting rule, with per-slot previews. Casting and separate damage rolls use the chosen slot while preserving existing manual roll options.
- Shared centered empty states and compact V/S/M controls with explicit selected indicators.

## 0.32.0

- Equipping a recognized weapon creates a linked attack, using stored/compendium damage, finesse or ranged ability, and source-aware proficiency.
- Existing equipped weapons are reconciled when loading/saving; manual attacks are preserved and unambiguous existing attacks are linked instead of duplicated.
- Unequipped attacks remain stowed. Removing an attack disables automatic creation for its item; custom weapon stats and automatic creation can be configured in the item editor.
- Structured magic weapon bonuses apply only to the linked attack while item effects are active, and reusable templates exclude generated attack links.


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
