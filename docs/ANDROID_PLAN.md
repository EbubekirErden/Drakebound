# Drakebound Android plan

Plan updated — 22 October 2026. Android is the priority; iOS is outside this plan. The owner subsequently authorized the native interaction prototype in `android/`; the broader milestones below remain the product roadmap.

## Product direction

Build an offline Android character companion optimized for use at the table. Preserve Drakebound's visual identity and rules behavior while designing navigation and controls for touch. Optimize for fast actions, readable information, reliable saves, and modest memory and battery use.

Working assumptions: phone portrait is the primary layout, tablets and landscape adapt gracefully, existing Mac characters are an important starting point, and accounts or cloud services are unnecessary for the first release. These are proposed defaults, not confirmed device requirements.

## Technology recommendation

- Native Kotlin with Jetpack Compose and Material components styled for Drakebound.
- ViewModels expose screen state; repositories handle storage; a separately testable rules layer handles calculations and play actions.
- Room over SQLite for character state, activity, and indexed compendium records. Persist related play changes in a single transaction.
- App-private files for original images; bounded thumbnail caches for display. DataStore for small preferences.
- A dedicated JSON import/export layer preserves the Mac archive format independently of Android's internal storage schema.
- Keep the initial module structure simple. Add module boundaries only where build time or ownership requires them.

This is a project recommendation, not a claim that a framework alone guarantees performance. Measure a release build on the intended hardware before accepting performance results.

## Phone navigation and layout

Character picker opens the last selected character after first use. A compact character header provides the character switcher and search. Use five bottom destinations:

| Destination | Main contents | Fast actions |
| --- | --- | --- |
| Play | HP, temporary HP, AC, initiative, conditions, concentration, attacks, frequently used counters | Damage/heal, attack, death saves, rest |
| Sheet | Abilities, saves, skills, features, training, identity | Roll check/save, use feature, edit section |
| Spells | Prepared spells, slots, casting sources, searchable spellbook | Cast, upcast, prepare, restore resources |
| Gear | Equipment, containers, attunement, weight, currency | Equip, use item, change quantity, spend coins |
| Journal | Session notes and pinned notes | Read, add, edit notes |

The owner selected five bottom tabs plus a hamburger drawer. The drawer contains direct named companion shortcuts (no intermediate companion landing page), Compendium, Activity, Edit character, Level up, Import/export, Settings, and Help. Its header provides character switching; companions can also be pinned on Play.

- Replace desktop sidebars and inspectors with lists and full-screen detail pages. Use bottom sheets for short, focused actions such as damage or slot selection.
- Play shows essential stats and pinned actions first; longer descriptions expand on demand. Portrait artwork stays compact so controls remain visible.
- Keep casting controls together: casting source, slot or free-use choice, concentration implications, and final action. Browsing a spell never spends a resource.
- Separate quick play changes from full editors. Detailed editors use explicit Save/Cancel; play actions save immediately and expose a scoped Undo where safe.
- Respect Android Back, keyboard insets, rotation, and system bars. Restore list positions and filters when returning from details.
- On wide windows use a navigation rail and list/detail panes, selected by available window width. Avoid stretching phone cards across a tablet.
- Use the owner-selected Field journal direction: warm paper content, a dark header and navigation bar, serif character names, and selective copper accents. Keep sections open, use small secondary text and aligned controls, and offer an optional dark appearance. Never communicate condition or resource state through color alone.
- Subsequent design review replaced repeated content cards with open sections, fine rules, aligned vitals and inline roll formulas. Focused overlays retain contrasting surfaces. Navigation now uses a moving underline and a backpack icon for Gear; see `docs/ANDROID_DESIGN.md` for the reference review.
- Use at least 48 dp touch targets, text scaling, TalkBack labels, reduced motion support, and readable contrast. Avoid hover-only information and gesture-only commands.

## Important interaction flows

1. **Damage/heal:** tap HP, enter amount, choose damage or healing, commit, see updated HP and a reversible history entry. Temporary HP behavior must match the documented rules.
2. **Cast:** choose a spell, review casting source and resource options, commit once, update slots/free uses and concentration atomically, show any roll result.
3. **Rest:** choose short/long rest, review exactly what resets, confirm, apply the selected changes together. Do not silently clear unrelated state.
4. **Find a rule:** search from the header or compendium, filter category/source, open details, optionally copy the supported entry to the character.
5. **Resume:** after switching apps or process recreation, reopen the selected character with committed play state intact. Restore editor drafts separately from saved character state.
6. **Transfer:** choose a JSON file, validate it, preview the import and warnings, add characters, then offer export through Android's file/share controls.

## Delivery scope

### Milestone 1 — layout and compatibility specification

Produce phone wireframes for Play, Sheet, Spells, Gear, and Journal, plus the drawer, HP, cast, rest, and import flows. Review a narrow phone, larger phone, large text, and a wide-window variation. Inventory the archive fields and write down how existing Mac calculations behave, including known limitations.

Exit: navigation and first-release scope are reviewable, supported/unsupported import fields are explicit, and one representative play session can be followed through the wireframes. Static wireframes do not require Android Studio.

### Milestone 2 — usable offline prototype

Implement isolated storage, JSON character import/export, character selection, sheet display, HP/temporary HP, checks/saves, attacks/dice, conditions, death saves, counters, concentration, basic spellcasting/slots, rests, and core equipment tracking. Include plain quick notes and basic companion HP/actions so imported characters remain useful during play.

Exit: import a representative character, play a session offline, restart the app, and export back to Mac without loss of supported character fields. This is an internal prototype, not yet a public release.

### Milestone 3 — first public Android release

Add bundled offline references and search, prepared-spell and inventory workflows, supported character editors, portraits, full companion workflows, and reliable note viewing/editing. Finish accessibility, import review, recovery, migration, and device testing.

Existing rich journal data must remain intact. If Android cannot safely edit a Mac rich-text field, show a readable representation and preserve the original field; do not silently flatten it on export.

Exit: supported features pass the functional and performance gates below, and any remaining limitations are visible before import/editing.

### Milestone 4 — complete creation and advancement

Add guided creation, level-up, multiclass choices, feature/effect editors, starting equipment and spell selection, and custom compendium editors. Use sequential steps and a final changes review instead of the Mac side-by-side guide.

Deferred beyond the first public release: full Fight Club XML parity, PDF export, rich journal authoring parity, extensive visual customization, automatic sync, and every desktop editing capability. Preserve original imported XML as opaque archive data where present. No iOS work is included.

## Data compatibility and protection

- Audit `Models.swift`, `CharacterExport.swift`, `StorePersistence.swift`, and validation rules before implementing archive mapping. Mac character exports contain images and custom mechanics; full backups also include shared content, while activity is separate.
- Define versioned Android storage migrations and a Mac-compatible transfer schema. Preserve IDs, defaults, optional fields, relationships, embedded images, and original XML. Distinguish missing values from explicit zero/false values.
- Preserve unrecognized fields through typed/raw mapping where safe; if an unknown archive version cannot be handled losslessly, block editing/import with a clear explanation. Never claim compatibility based only on successfully parsing JSON.
- Match additive import behavior: new character IDs and consistent remapping of internal references. Preview duplicates; do not overwrite existing characters implicitly.
- Stage and validate imports before committing. A failed import leaves existing data intact. Validate image sizes and archive limits without loading unbounded content into memory.
- Treat a committed database transaction as the saved result. Surface persistence errors and retain retryable input; avoid a success message before storage succeeds.
- JSON transfer is manual copying, not synchronization. Explain that editing both copies creates divergent characters; do not implement implicit merging.
- Use the system file picker/share mechanisms instead of broad storage access. Decide Android system-backup inclusion explicitly before release, including the privacy and uninstall implications.
- Follow repository `AGENTS.md` before future development, tests, previews, or installations: verified full backup including portraits in the owner-approved location; physically isolated fixture storage; live-save hashes before and after runs. Never commit private archives.

## Performance plan and acceptance targets

Provisional budgets, to be calibrated on the owner's phone and a representative modest Android device. Measure release builds with synthetic data, not private archives. Emulators supplement physical-device measurements.

| Scenario | Proposed acceptance target |
| --- | --- |
| Cold launch to usable last character | At most 2 seconds on the agreed reference device with the normal dataset |
| HP/counter action | Visible feedback within 100 ms; durable completion within 250 ms at the 95th percentile |
| Indexed compendium search | First results within 200 ms after a short debounce, at the 95th percentile |
| Long lists | Frame timing tracks the device refresh budget; fewer than 1% janky frames in the agreed scroll scenario |
| Large import | Visible progress and cancellation before commit; no main-thread file parsing or database writes |
| Idle use | No continuous animation, polling, or background processing merely to keep the sheet open |

Benchmark fixtures: a basic martial character; a multiclass caster with custom rolls, counters and effects; companions and image-heavy notes; multiple characters; and a synthetic library of roughly 25,000 records reflecting the current documented compendium scale. Establish normal and stress image/archive sizes before promising a memory cap.

Implementation tactics: load visible data and thumbnails lazily, index search, page large lists, parse imports off the main thread, scope UI updates to changed state, and defer compendium initialization until needed. Evaluate baseline profiles using startup/navigation benchmarks. Track peak memory, APK size, and energy use alongside latency; set those budgets after measuring the first prototype.

## Verification gates

- Compare Android rules results with explicit expected values and existing Mac behavior for ability modifiers, proficiency, AC, equipment attacks, spell costs/upcasting, concentration, counters, rests, and death saves. Known desktop limitations remain explicit.
- Test synthetic archive round trips in both directions, missing optional fields, unknown fields, internal ID remapping, custom mechanics, image bytes, original XML, and rich journal payloads.
- Exercise low storage, invalid imports, interrupted imports, transaction failures, process death, rotation, backgrounding, and database upgrades. Confirm no partial play action or corrupt character remains.
- Test rapid repeated taps so a deliberate action cannot accidentally spend twice while a commit is pending. Undo must respect intervening actions.
- Complete a full session in airplane mode; verify that saved HP, slots, conditions, notes, and inventory survive restart.
- Review narrow screens, keyboard-open editors, large fonts, TalkBack, reduced motion, tablets, and landscape. Include gesture and button navigation.
- Run performance scenarios in release builds on physical hardware, then document results and any missed budgets before public release.

## Decisions still open

No answer is required to continue refining this document. Before implementation, confirm the primary phone/tablet and Android version, whether full character creation is required for the initial public release, how often companions are used, and whether Mac transfer is the main onboarding route. These affect the navigation, minimum supported Android version, and milestone order.

Interactive wireframes were reviewed and a native Android draft was authorized. The first code draft focuses on navigation, animated random dice, a dice-formula calculator and contextual amount calculators, using isolated fictional characters. It is a preliminary interaction build, not completion of Milestone 2: archive compatibility, full rules parity, and production storage remain outstanding. See `android/README.md` for its exact scope and build instructions.

## Reference material

Repository basis: `docs/USER_GUIDE.md`, `docs/ARCHITECTURE.md`, `Sources/Models.swift`, and `Sources/CharacterExport.swift`.

- [Android offline-first architecture](https://developer.android.com/topic/architecture/data-layer/offline-first)
- [Room persistence](https://developer.android.com/training/data-storage/room)
- [Adaptive Compose layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/get-started-with-adaptive-apps)
- [Compose accessibility defaults](https://developer.android.com/develop/ui/compose/accessibility/api-defaults)
- [Compose performance guidance](https://developer.android.com/develop/ui/compose/performance)

These sources inform the technology and accessibility recommendations; milestone scope and performance budgets are proposals specific to Drakebound.
