# Drakebound user guide

A native, offline SwiftUI character companion inspired by Fight Club 5th Edition. Requires macOS 14 or later on Apple silicon. Independently built; not affiliated with Lion’s Den or Wizards of the Coast.

[Back to the project overview](../README.md) · [Build and contribution guidance](../CONTRIBUTING.md)

This guide describes the current working tree. Features may be newer than the latest published download; consult that release’s notes.

## Open the app

Use the installed copy in `/Applications/Drakebound.app`. Development builds are kept in `build/products.noindex/Drakebound.app` to avoid duplicate Launchpad entries. No browser, server, subscription, or developer tools are needed to use the built app.

## Included

- Equipping a recognized weapon creates a linked attack automatically. Existing equipped weapons are checked on loading/saving. Finesse uses the better initial Strength/Dexterity modifier; ranged weapons use Dexterity. Proficiency follows the recorded weapon training.
- Unequipping stows the linked attack. Editing an attack preserves custom choices; removing it disables automatic creation for that item. Item editor → Weapon attack supports opt-out and custom weapon stats. Unknown weapons need explicit stats rather than guessed damage.


- Equipment, Spells, Journal and Creatures use matching search and action toolbars that adapt to window width. Equipment’s **…** menu contains New container, Browse compendium and Weapon & armor proficiency. Banner controls keep Edit and Expand visible; Level up and Frame banner are in its **…** menu.

- Feature editor → Applied effects supports recognized rules, custom flat/per-level modifiers, and reference-only entries. Tough from Compendium automatically grants +2 maximum HP per total character level. Imported Fight Club feats require explicit opt-in to avoid duplicating effects already included in saved stats. Other feat descriptions do not automatically apply arbitrary rules.
- Hover maximum HP to inspect its sources. Choose Reference only if a feat bonus is already included in base HP; keep base HP separate when using recognized effects.


- Equipment → Add item opens a searchable compendium popover with type/source filters and a Custom item option.
- Click the currency balance to manage standard coins and custom currencies with Add, Spend, or Set. Amounts accept a dot or comma and at most two decimal places. Balances are independent and included in JSON backups; currencies are not automatically converted.
- Creature menu → Image layout offers Banner, Left portrait, or Right portrait. Crop framing preserves the original image.


- Creator spell selection includes the caster table; equipment selection filters by type and source.
- Spell preparation menus affect the whole spellbook (including hidden rows). Prepare all records your choice without enforcing class limits.
- Features can be grouped under another feature in their editor. Links organize the list; they do not share counters or apply extra effects. Removing a parent leaves its children available.
- Equipment and Training show weapon/armor proficiency sources and manual controls. Class/feature grants remain separate from manual grants.
- Duplicate catalog choices are consolidated for browsing; custom compendium entries and saved character spells are retained.


- Slate theme, resizable character sidebar with a compact portrait mode and character search, and browser-style Sheet, Actions, Equipment, Spells, Journal, and Creatures tabs.
- Consistent tab accents: teal Sheet, coral Actions, gold Equipment, blue Spells, muted rose Journal, and green Creatures. Inactive icons are subdued; the selected tab has a matching underline and stronger icon.
- Semantic colors, animated health bars and counters, and a larger dice display; macOS Reduce Motion is respected.
- Multiple editable characters, with a sample level 5 wizard.
- Compact character-creation and level-up guides with live and full previews, explicit compendium choices, and a final review.
- ASI milestones open an ability/feat chooser; allocations disappear when the milestone is removed. Other feats record their explicit ability increase rather than interpreting arbitrary prose.
- Weapon and armor training retain their sources. Known linked weapons use that training for attack proficiency; custom weapons retain their manual setting.
- Spells & Gear includes feature references, per-class spell allowances, starting equipment alternatives, and packs expanded into inventory containers. Kits do not auto-equip items; choose one class/background alternative.
- Spell allowances use imported class tables where available and supported edition-specific rules. Unknown values ask you to check the reference. Mark domain/other always-prepared spells exempt in their editor.
- Complete recognized cantrips without an XML level are available in the creator; ambiguous missing-level entries remain available for manual review.
- Ability checks, saving throws, skill proficiency and expertise, calculated proficiency and spell DC.
- Animated dice rolls, dice notation, attack and damage rolls, and session roll history. Honors macOS Reduce Motion.
- HP, temporary HP, hit dice, death saves, inspiration, and selectable conditions with effects.
- Spell preparation, configurable spell slots, casting and upcasting.
- Inventory, item quantities, gold, carried weight, and automatically applied equipment effects.
- Base armor AC with Dexterity and a configurable cap; shield and magic armor bonuses.
- Attunement requirements, toggled feat/temporary bonuses, targeted attack bonuses, and extra roll dice.
- Custom resource and feature-use counters with independent short-, long-, and full-rest reset choices, or manual refill.
- Features grouped by race/ancestry, class, feat, background, or other, with editable sources and compact cards.
- Journal notes have title-click expansion, rich text, images, and explicit Save/Cancel. Pin notes to the top and drag their handles to reorder within pinned/unpinned groups.
- Drag equipment handles to reorder within a container or Carried. Note and equipment menus also offer Move up/down; filtered-out entries keep their positions.
- Character image banners with position/zoom controls, plus images for notes and creature entries.
- Custom companion, familiar, summon, encounter, and reference creature records with stats, HP, and rollable attacks.
- JSON backup export and additive import (imported characters receive new IDs).
- A sidebar compendium for spells, equipment, creatures, feats, races, classes, and backgrounds, with search, details, and adding copies to a character.
- Fight Club compendium and character XML import, tested against a `pc version="5"` export, with a character import review note and preservation of the original character XML.
- Named custom rolls on spells, items, and features, with visible formulas, ranges, and character-stat tokens.

The app includes an offline SRD library covering all seven compendium categories, with 339 spells and the 12 core classes plus their SRD subclasses. The ten original starter summaries remain compatible with earlier archives. Import additional Fight Club XML if needed. References and templates do not apply arbitrary rules automatically. **Help → Included rules & attribution** explains the sources and license; **Help → SRD 5.2.1 reference PDF** opens the included official document.

## Current limits

Fight Club character XML import supports the tested export shape; this is not full two-way compatibility. XML export of edited characters, automatic enforcement of every class/feat choice and prerequisite, a complete feat/rules database, and cloud sync are not implemented. Condition automation covers tracked self effects; target-specific combat decisions remain manual. Original character XML is embedded in JSON backups so unsupported source fields remain available.

## Character creation and leveling

**New character** (or ⌘N) opens a seven-step guide. Choose identity and rules edition, a starting class and origin, abilities, training, features, spells/equipment, then review. Standard array assignment swaps scores instead of duplicating them; point buy tracks a 27-point budget; rolled scores use four d6s dropping the lowest. Origin adjustments are explicit. **Prioritize class abilities** offers a starting assignment (or a 27-point allocation), which you can then change. Higher-level starts use fixed HP after the first level. Import a compendium for race/background/class/feat choices; built-in class basics and custom entries work offline without one.

**Level up** in the character banner’s **…** menu opens a draft for one new level. Advance an existing class or multiclass, choose an ASI or another feat only at the advancing class’s milestone, preserve starting training, choose fixed/rolled/manual HP, select the exact class-level features and spells, and review before applying. Imported class levels come from hit-dice pools. Constitution modifier changes adjust HP for earlier levels. Current HP may increase by the gained maximum without performing a rest; slots, counters, temporary HP, conditions, and spent hit dice retain their state. Class levels and an advancement log are saved, with a Journal summary and a pre-level-up JSON backup beside the character file.

The right-hand live preview can be hidden; **Preview sheet** opens a wider view with separate Sheet, Features & training, and Changes sections, including attack formulas, spell casting classes, equipment, and training sources. Every reference has an eye-button preview. Closing or discarding a guide leaves saved characters untouched. Required fields and point-buy/HP/slot errors block completion. The starting class’s skill-choice count is required. Compendium subclass headings populate a picker at their class-level requirement, and core class features start selected. Ancestry and background traits are granted automatically. Custom origins use structured editors requiring rules and feature descriptions. ASI eligibility follows the selected class’s XML level or the built-in class milestones; multiclass total level alone never grants an ASI. Ordinary level-ups preserve existing saving throws and skills. Complete feat prerequisites, prepared-spell limits, alternative-feature choice limits, and equipment packages still need review against reference text. Configure effects and rest counters explicitly in Features; edit equipment to configure armor and attacks.

The spell browser groups spells into scrollable level sections with a level jump menu, an optional exact-level filter, and a class-list filter. New guide spells record their casting class; spell editors expose both class lists and the character’s casting class/ability. Imported class-scoped spells recover their source class without replacing the spell or its rolls. The XML parent determines that source, even when the spell name mentions another class; use **Cast as class** to correct a mismatched source.

The spell browser also offers **Needs level review** for XML entries without a level, including cantrips omitted from the normal library. These require an explicit Cantrip/level confirmation before adding; reference features are never silently treated as cantrips.

The slot page can apply a single-class XML table (excluding its cantrip count), use the full-caster table at an explicit caster level, or accept manual totals. Ordinary Spellcasting and Pact Magic are not separate casting pools in this version. Single-class Pact Magic can use the explicit short-rest slot toggle; mixed Pact Magic should use a separate manual counter. The guide never infers spell availability from multiclass slot level. Numeric creation/advancement behavior follows the [2024 Free Rules character creation and advancement reference](https://www.dndbeyond.com/sources/dnd/br-2024/creating-a-character); imported 2014 options and custom choices remain available.

## Mac menus, inventory containers, and roll labels

One compact ability table combines **Score**, **Check**, and **Save** rows under the six ability columns. Scores are static; check and save modifiers roll directly, with hold/right-click mode choices. The small save dot toggles manual proficiency. Skill checks stay in their own list. Hover over ability scores, check/save/skill modifiers, AC, initiative, attack and damage fields, or spell save DC/attack to inspect the calculation and active sources. Calculation text takes precedence over the shared roll-button hint. Extra dice are listed separately from the fixed total.

The main attack list shows ready attacks. Unequipped, empty-quantity, and missing-item attacks remain in a collapsed **Stowed weapons** section; equipping their linked item returns them to the main list. No attack data is removed.

Equipment supports named containers with collapsible contents, item counts, and contents' weight. Add or rename a container, then use an item’s **Move to** menu or **Container** editor field. Removing a container moves its contents to **Carried** and preserves each item. Imported Fight Club containers and earlier `Container:` notes are migrated once. Groups are flat storage locations; capacity limits, nested bags, and magical weight rules remain manual. Reusable compendium item copies start in Carried and never retain a character-specific container link.

Native **Character**, **Navigate**, and **Dice** menus expose shortcuts:

| Shortcut | Action |
| --- | --- |
| ⌘1–⌘7 | Sheet, Actions, Equipment, Spells, Journal, Creatures, Compendium |
| ⌘F | Find in actions, equipment, spells, or compendium; opens spell search from other sheet tabs |
| ⌘E | Edit selected character |
| ⇧⌘N / ⌥⌘N | Add equipment / spell |
| ⇧⌘L | Level up |
| ⇧⌘R | Open Rest & recovery for review |
| ⌘D | Open the dice calculator |
| ⌘R | Roll d20 using the selected dice mode |

Navigation and character commands are guarded while a creator draft or native editor sheet is open. Rest commands open the rest sheet; they do not take a rest immediately. The menus supplement ⌘N for a new character and ⇧⌘I / ⇧⌘E for import / export.

The guide’s **Caster table** now separates each class’s imported cantrip allowance from combined-caster spell slots. There is no universal combined-caster formula for cantrips known. Extra cantrips from origins and feats remain separate; applying a slot table never adds or removes spells.

## Play actions, concentration, and sources

Health & recovery sits between the combat statistics and the ability table. Temporary HP is at the right; Inspiration sits beside Hit dice in the existing row below the health bar.

**Actions** has its own top tab (⌘2), with **Frequent / Recent / All** filters, an **All types / Attacks / Spells / Items / Features** menu, a separate **All timings / Action / Bonus action / Reaction / Other** filter, and search (⌘F). It uses the same character banner, crop framing, character controls, and scrolling behavior as the other character tabs. All shows one card per ready attack, prepared spell/cantrip, item with custom rolls, or tracked/rollable feature. Weapons have separate attack and damage buttons. The small **Crit** button on an attack card rolls critical damage: all configured damage dice are doubled and flat modifiers are added once. It is a manual choice and does not infer whether an attack hit. Spell custom rolls do not receive this attack-only shortcut. **Costs** opens a compact preview of the default cast/use cost, remaining slots or linked counters, and the selected independent roll’s cost. Opening the preview spends nothing. Spell cards show a current cantrip tier or roll options for slot levels the character has; higher imported variants remain in spell details. The roll-only button previews its formula and never consumes a spell slot (a configured roll resource cost still applies). Cast remains a separate, uniform button: click to cast with the default mode, hold for about two-thirds of a second or right-click to choose a slot level, ritual, free use, or cantrip strength. Opening casting options spends nothing; selecting an option casts immediately. Card titles open details. Action cards share a fixed 120-point height with aligned header, control, and footer rows; the search field and filter buttons share a 26-point height. Older per-roll favorites and history contribute to their parent card without rewriting saved records. Use an action to add it to Recent and its frequency count, or star it to keep it in Frequent. These lists are per character and saved locally. The dedicated page shows the complete matching list. Stowed weapon attacks stay out of this list.

Spell editors have a **Requires concentration** toggle; imported duration text containing “Concentration” or beginning “C,” supplies the initial value. Casting starts concentration and replaces the previous concentration spell. The active spell row and spell details have a blue outline and a static **Concentrating** label. Only the separate **End** control stops concentration. Inactive spells show **Concentration**, meaning the spell requires it; that label is not active tracking. The sheet’s health panel also offers a compact end control. Ordinary spells leave concentration active. Long/full rests, zero HP, and applying an incapacitating condition end concentration. Damage creates a compact pending Constitution save in Health & recovery. Each entered hit queues a separate save, including damage absorbed by temporary HP. Enter damage after resistance, wards, and other reductions. DC is max(10, damage / 2 rounded down), capped at 30 for 2024 and uncapped for 2014. Roll uses CON-save training, active save modifiers/dice, exhaustion, and selected ADV/DIS. Save details offer an explicit concentration-only advantage toggle (for features such as War Caster), a DC override, and final-total entry for physical dice. Imported feature text does not enable advantage automatically. Closing details leaves the save pending. Success removes that save; failure ends concentration and clears the queue. Recasting concentration (even the same spell), ending it, incapacitation, zero HP, and long/full rest clear pending saves. Pending saves and the advantage setting persist in backups and across restarts. No duration timer is applied.

Feature counters now appear in **Resources** using the same underlying value as the feature card. Counter reset rules remain independent and user-selected. Spell, feature, and custom-roll editors can link a cost to any character resource or feature counter. A cast spends its linked cost alongside any slot/free use; its automatic roll also spends its own linked cost. **Use feature** spends the linked cost plus one own tracked use, when enabled. Manual custom rolls spend only that roll’s configured cost. Combined costs against the same resource are checked together. Failed validation or insufficient resources spend nothing and do not enter action history. Removing a linked counter leaves an explicit missing-resource error until the link is edited. Reusable compendium templates clear character-specific resource links.

The global **Sources** filter sits above the compendium categories and updates every category’s count. Category search, level/type, and school controls share one row below the categories. Compendium **Sources** offers All sources, **2024 + custom**, UA, Homebrew, Custom, and Unmarked views. The 2024 view optionally includes UA and homebrew. Source badges use explicit name/source markers, including Source lines in imported text; entries without edition markers remain Unmarked. These filters preserve every stored reference and custom addition. They do not convert older rules or infer an edition from arbitrary description text. Choose All sources to see the complete library again.

## Modifiers and counters

Click an equipment name for a compact detail view with previous/next navigation, quantities, equipped/attuned toggles, modifiers, and rolls; choose **Edit** to change the item. Inventory rows remain in place behind the view. Type and equipped-only filters sit beside search. Imported type codes display as names (`$` valuables, `G` gear, `W` wondrous item, `M` melee weapon, `R` ranged weapon, `S` shield, and armor/magic-item subtypes). Material is an additional custom category. Add explicit effects, then equip the item. Effects require a positive quantity and, when configured, attunement. For armor, enable **Use as base armor**, set its AC, and choose whether Dexterity applies and its cap (20 means effectively uncapped for supported scores). Equipped armor replaces the manual base AC; if multiple base armors are equipped, the highest calculated value is used. Configure a shield as a +2 Armor class effect, not as base armor.

Use **Feats & bonuses** for feats, buffs, and other sources. Targets include ability scores, AC, maximum HP, speed, initiative, saves, skills, spell DC, attacks, and damage. Choose a specific attack in the target menu for a magic weapon, or all weapon/spell attacks where appropriate. Multiple effects may be added for one source. Extra dice such as `1d4` are added to applicable rolls. Bonuses to ability scores feed into dependent modifiers; maximum HP bonuses adjust the maximum but do not immediately heal or damage current HP. The passive perception display uses flat bonuses, not extra rolled dice.

These are user-configured additive effects, not automatic interpretation of equipment or feat descriptions. Configure each source once to avoid double counting. Training grants record their source on a character or feature. Two proficiency grants apply the proficiency bonus once; expertise doubles it once, while explicit flat and dice modifiers remain additive. The app does not enforce arbitrary bonus non-stacking rules, attunement limits, class-specific exceptions, or conditional prerequisites. For conditional effects, use the Active toggle. Set existing attack entries to **Spell attack** where appropriate to receive spell-only bonuses.

Use **Resources → Counter** for ammunition, feat uses, item charges, or class resources. Click its name to enter maximum/remaining values and select each reset event independently: **Short rest**, **Long rest**, and **Full rest**. No selection means manual. New counters start as manual. Earlier short-rest settings retain short/long/full recovery and earlier long-rest settings retain long/full recovery until edited. A feature editor also offers **Track uses** with the same reset controls.

**Rest** opens a recovery sheet with three choices and a preview of exactly which counters will refill. Short rest only refills assigned counters; spend hit dice separately. Long rest restores HP, slots, spell free uses, and the rules-edition amount of hit dice, clears temporary HP/death saves, and reduces exhaustion by one. **Full rest** is a house-rule complete recovery: all hit dice and exhaustion recover, with counters still governed by their independent Full rest selection. Spell free-use charges currently restore on long/full rests.

**Hit dice** opens class-pool cards and a quantity selector. Each die adds Constitution, with a minimum of zero healing per die; the app spends the chosen quantity atomically and caps healing at maximum HP. **Damage**, **Heal**, and **Temp HP** open focused quantity popups with quick increments and explicit Apply. Temporary HP is replaced, not stacked.

Sheet and creature attacks use matching hit/damage fields; attack names open individual descriptions and properties. Creature descriptions and non-attack actions recovered from character XML appear as separate traits. Unequipped weapons retain their attack descriptions under **Stowed weapons** and cannot roll until equipped. Imported weapons are linked to their inventory item; existing uniquely named weapons are linked during migration. Sheet places resources in one horizontally scrolling row of fixed-size progress tiles and saves/skills in a compact grid, with features and feat/temporary bonuses at the bottom. Equipment, Spells, Journal, and Creatures have dedicated top tabs. The shared compendium opens from the sidebar or the spellbook link. The bottom dice bar is always available. Dice results use a floating panel above information sheets and editors while the app is active. The panel presents the same result recorded in history; it is a visual animation rather than a physical dice simulation.

## Conditions and advantage

Use **Conditions → Manage** to select defined conditions and choose 2014 or 2024 rules. The app infers 2024 for imported class names containing “2024”; override this per character. Effects include attack/check/save advantage or disadvantage, movement restrictions, automatic failed Strength/Dexterity saves, action/casting restrictions, and exhaustion penalties. Long rest removes one exhaustion level. Conditions with target context have explicit switches for a visible fear source and a target unable to see an invisible character. Incoming attacks, damage resistance, senses, critical hits, concentration saving throws, and target-specific restrictions remain table decisions; reminders appear beside each condition. See the [2014 conditions](https://www.dndbeyond.com/sources/dnd/basic-rules-2014/appendix-a-conditions) and [2024 rules glossary](https://www.dndbeyond.com/sources/dnd/br-2024/rules-glossary).

Hold a character D20 roll field for about half a second, or right-click it, to select Normal, Advantage, or Disadvantage for one roll. This also works for D20 custom-roll cards and the bottom Roll button. A quick click rolls immediately using the default mode. Advantage/disadvantage animations show both D20s, label the kept die, and dim the discarded die. Dice wrap into a grid: eight dice are shown as two rows of four, with up to 24 individual faces visible. Larger rolls keep every result in history. The expression and total share a compact footer. The bottom **D20 mode** menu supplies default manual advantage or disadvantage, combined with automatic condition effects for typed character rolls. Any advantage and disadvantage cancel. Custom rolls default to generic dice: select an attack, check, save, or initiative category in their editor to apply conditions, and choose an ability for ability-specific save effects. Typed formulas must begin with `1d20`. Damage and healing rolls should remain generic.

## Casting and custom rolls

The spellbook includes **All / Prepared / Unprepared** and level filters. Unprepared spells have dimmed, disabled casting controls in rows and details; their descriptions and custom roll previews remain readable. The spell row’s **Cast** button performs casting immediately using the lowest available slot; it does not open the information view. Use its adjacent menu to choose an upcast slot, ritual, or configured free use. Click the spell name for details, editing, and manual custom rolls. Detail views have previous/next buttons and left/right keyboard navigation within the list you opened. Preparation status is visible and toggles directly. Click the shaded area outside the detail card, press Escape, or use Done to close it. With no slots available, the app explains the reason rather than silently disabling Cast. **Manage slots** edits totals and expended slots explicitly; a long rest restores them.

Edit a spell to configure ritual eligibility, default slot use, per-long-rest free uses, the casting ability, and custom rolls. Free uses of 0 with default slot use off means unlimited casting without slots. Cantrips never consume a slot, and their casting event explicitly says so. Casting logs an event, and optionally runs the configured automatic roll. Invalid automatic formulas never consume a slot or free use. Applying damage, healing, or other spell effects is manual.

Custom rolls can be added to spells, equipment, and features. Examples: `2d6+3`, `1d8+{spell}`, `1d20+{dex}+{prof}`. Supported tokens are `{str}`, `{dex}`, `{con}`, `{int}`, `{wis}`, `{cha}`, `{prof}`, `{spell}`, `{attack}`, `{dc}`, `{level}`, and `{slot}`. Each token is replaced by its current numeric value. This is additive dice notation; multiplication and arbitrary code are not evaluated. Fight Club `%0` is converted to the relevant spellcasting modifier. Item/feature rolls use the character’s default casting ability.

Imported repeated spell rolls are retained as separate choices. Unambiguous complete slot-level arrays and four-tier cantrip arrays receive labels, but no roll is automatically selected: some XML rolls describe secondary effects rather than damage. Choose an automatic roll in the spell editor or roll the appropriate choice manually. There is no arbitrary formula rewriting. For cantrips with explicit character-level tiers, Cast uses the current character-level tier, with an override selector in details and tier choices in the row menu; no slot is spent. Ray of Frost’s four XML formulas correspond to character levels 1, 5, 11, and 17. This is cantrip scaling, distinct from spending a higher-level spell slot. Spell-level upcasts continue to use slot choices and explicit formulas.

## Shared compendium

Open **Compendium** in the sidebar to browse the included SRD library immediately. You can also import a compendium XML (up to 100 MB). It supports spells, equipment, creatures, feats, races, classes, and backgrounds. Search matches names and summary metadata in the selected category. Subcategory filters include spell level and school, equipment type, and creature type. Equipment type codes are translated into readable labels. Results load in pages of 100. Original nested fields and XML attributes, including class autolevel levels and traits/actions, are retained in a separate local `compendium.json`; JSON backup exports include the compendium too. Bundled SRD records load from app resources and are not duplicated into this file; custom copies and modifications remain saved with user data.

Every category has a **New** action with a structured editor. Character item, spell, feature, and creature editors offer **Also save a reusable copy to Compendium**. The copy retains rolls, effects, training grants, images, and counters; worn/equipped state, spent charges, current creature damage, and character-specific spell casting sources are reset for reuse. Custom references can be edited; imported references can be edited as a new custom copy. Custom ancestry/background/class editors require titled feature descriptions and the relevant structured data.

The supplied FC5 Compendium was checked against all 25,597 records. Thirty-four exact duplicate records collapse to 25,563 distinct references; versions sharing a name are preserved when their fields differ. Its one bare ampersand is escaped only in memory during parsing, leaving the original file untouched. XML entity/DOCTYPE declarations remain rejected. Of 3,090 entries in its spell category, 1,723 have an explicit supported level and become usable spells. Entries without a level remain readable references and can be copied to features instead of being treated as cantrips.

Open an entry to read its details and add a copy to the selected character: equipment, creatures, or reference features with the relevant category. Ancestry references show size, creature type, and other physical metadata once in a bottom table rather than repeating them as feature accordions. Creature references use aligned identity and combat cells, a six-column ability table with modifiers, and compact labeled rows for senses, saves, and other statistics. Class references are shown as expandable levels containing separate feature cards. Adding class features uses an explicit “through level” selector and creates individual feature entries; race and background traits are also copied separately. These entries do not rebuild or level the character. Creature HP, AC, walking-speed first value, ability scores, individual attack descriptions, other traits, and supported pipe-formatted attacks map into editable values; the full original stat-block fields remain in the description. Review these values and equipment modifiers after adding. Custom/starter spells remain available separately from imported references. Reimport merges exact records without duplicating them.

Imported character features are grouped by their actual XML parent: race, class, background, or direct feat. Existing imported characters recover this grouping from their preserved XML without replacing feature IDs, descriptions, rolls, or counters. Categories and source labels are editable in each feature editor.

## Fight Club character XML compatibility

Use **Import** in the sidebar and choose a character `.xml`. The importer distinguishes character exports from spell compendiums. It imports current character data, multiple classes, direct racial/class/feat modifiers, proficiency flags, HP, slot totals and remaining slots, spell preparation and roll arrays, equipment and containers, explicit armor/shield AC, counters, current features, per-class hit dice, embedded creatures, and linked portraits. The first slot-array entry is the cantrip count and is excluded from expendable slots. `slotsCurrent` contains remaining slots and is converted to used slots.

Character import backs up the existing save before adding the new character; it does not replace your party. Importing the identical original XML again does not create another copy. Open **Journal → Fight Club import review** for inferred defaults and unsupported fields. The original XML is retained in the character’s JSON data.

Specific limits: a missing class level defaults to 1; missing hit-die types use class defaults; numeric modifier mappings are supported for ability scores, skill bonuses, and initiative, while unrecognized codes are reported. Save-proficiency flags are combined as encoded, so multiclass starting-class proficiencies need checking. Expertise expressed as a numeric modifier remains a flat imported bonus and should be reviewed after leveling. Future `autolevel` templates are preserved in the original XML but not activated. Item slot/attunement states and conditional descriptions need review. Spells explicitly named “Free Once” receive one free use per long rest, with a review warning. Descriptive magic-item, spell, and feature text is retained, not automatically interpreted as executable rules.

## Journal, creatures, and images

Spells are filtered by their explicit casting-time prefix; longer casting times remain under Other. Attacks default to Action. Attack, item, and feature editors expose **Action timing** for custom choices; unconfigured items/features remain under Other rather than inferring rules from prose. Timing filters combine with type, frequency, and search filters.

Creatures have an **Active in play** setting in their editor. Existing records and new companions start active. The bordered **Dismiss** (summons) or **Deactivate** button moves an active card into a compact Inactive list, preserving HP, attacks, traits, image, and notes. **Summon** or **Activate** brings it back. Activity does not reset on rest or change automatically when concentration ends; companions stay active until you change them. Reusable compendium templates omit the character-specific active state.

Decorative cropped banner images ignore pointer input, so offscreen image bounds cannot cover nearby controls such as Dismiss.

The app bundle includes its custom icon and explicitly assigns that image to the running Dock icon at launch. Quit an older running copy and open the updated app to pick up this change.

Journal notes have separate title and description fields, expandable cards, optional images, search, and duplicate/delete actions. Click either the title/preview or its disclosure arrow to expand or collapse a note. Earlier free-text journals are migrated into a single **Earlier notes** entry without changing their text. New notes are saved as you type. The description has a compact visual toolbar for Body / Heading 1 / Heading 2, bold (⌘B), italic (⌘I), strikethrough, bullets, numbering, checklists, links, clear formatting, and undo/redo. Select text for inline styles or a link; paragraph tools apply to the current or selected paragraphs. Enter continues a list; Enter on an empty list item exits it. Toggle checklist completion with the checkmark control. Links accept HTTP, HTTPS, or mailto addresses. Formatting is embedded as optional RTF in each note and in JSON backups, alongside a plain-text description used by search and collapsed previews. Older notes remain plain until edited; mismatched or unreadable rich text falls back to the plain description. Note images remain separate from the text editor.

Creatures are per-character records; imported compendium creatures can be copied into this list. Add a companion, familiar, summon, encounter, or reference entry; enter stats and attack bonuses/damage explicitly. Creature ability checks and attacks use the dice roller. Creature HP is independent of character HP. Creature entries embedded in a character XML are imported, including their explicit attacks and images. Creature spellcasting automation, encounter initiative ordering, and automatic familiar/summon rules are not implemented.

Attack, creature, spell, feature, and equipment editors use compact bordered groups, aligned fields, and separate description inputs. Attack descriptions and item properties are independently editable. Spell, equipment, and compendium detail panels start at a consistent 660 × 580 points, independent of description length. Content scrolls inside. Drag the bottom-right handle to resize, or click it to restore the standard size. Panels fit smaller windows; the main window can resize down to 900 × 620 points.

Use **Edit character → Portrait** to attach an image to a character. Journal entries and creature editors also have **Add image** controls. Select local PNG, JPEG, HEIC, or another macOS-readable image (25 MB input limit). Images are converted to PNG and resized to at most 1200 pixels on the longest edge, with a 5 MB saved-image limit. They are embedded in local saves and JSON backups, so the original file can be moved later. Animated images use their first frame. Click an attached image in its editor to preview it. These controls do not generate images or fetch remote URLs.

Characters and creature/summon cards use image banners with independent position/zoom framing. The character header uses a compact 160–200-point banner with an expand control for the full artwork. Click the transparent dragon mark to expand or compact the sidebar. Character search filters names and classes in expanded mode. The sidebar width, compact mode, and banner size are remembered on this Mac. Banner controls sit at the top right; the opaque sheet scrolls over its slower-moving background and reveals it again when scrolling up. Choose **… → Frame banner…** to preview horizontal/vertical positioning and zoom, then **Apply banner**. Framing is stored separately and preserves the full saved image.

Drakebound keeps the original Fellowship save folder for compatibility with existing characters and backups. Data is saved atomically at `~/Library/Application Support/Fellowship5e/characters.json`. Use **Export backup** regularly; the roll log lasts for the current session. JSON imports add characters rather than overwrite existing ones.

## Build and verify

Requires Xcode / the macOS Swift toolchain. No third-party dependencies.

```sh
bash scripts/build.sh
bash scripts/test.sh
```

The local build is ad-hoc signed, not Developer ID signed or notarized for distribution. The build script targets Apple silicon.

Reference: [Fight Club 5th Edition product listing](https://apps.apple.com/us/app/fight-club-5th-edition/id901057473).

For the character importer and casting regression tests:

```sh
bash scripts/test.sh "/path/to/Shennie Dia.xml" "/path/to/FC5 Compendium.xml"
```

Encoding cross-check: [independent character importer encoding notes](https://github.com/Str4vinci/foundryvtt-char2pdf/blob/main/fightclub.py). Current character data is read directly; future class templates are not traversed for active modifiers.


## Optional help and compact death saves

Small question-mark buttons in Health, Actions, Resources, and creature headers open tips on demand. Close or click outside to dismiss the popover; **Hide this tip** removes that topic’s button across launches. **Help → Tips & shortcuts** always provides every topic, a global Show tip buttons preference, and Restore hidden tips. Tips never open automatically or insert explanation text between input fields. Preferences are local app settings, separate from character backups.

The compact death-save tile sits beside Temp HP, with three green success pips and three red failure pips. Click it to edit either track, roll with optional advantage/disadvantage, mark stable, or reset. Rolls are available only at 0 HP before three successes/failures. Natural 1 adds two failures; natural 20 restores 1 HP and clears both tracks. Three successes mark stable; three failures stop further rolls. Regaining HP clears both tracks. The roll adds configured all-save bonuses and applicable conditions/exhaustion; it adds no ability modifier or proficiency by default. Adjust the tracks manually for damage taken at 0 HP or other table rulings. See the [2024 death saving throw rules](https://www.dndbeyond.com/sources/dnd/br-2024/playing-the-game).


## Activity log and undo

The small activity-list button beside roll history in the bottom bar opens the selected character’s play history. **Character → Activity Log** opens the same popover. Health, temporary HP, death saves, Inspiration, spell slots/free uses, linked counters, feature uses, hit dice, conditions, concentration, equipment quantity/equipped/attuned state, and creature HP/activity are tracked. A cast’s slots, charges, and concentration changes form one entry with a before/after breakdown.

**Undo last change** restores the newest remaining play event atomically. **⌘Z** does the same outside text editing; text editors keep their own undo/redo. Undo does not re-roll dice or remove old roll results. Undone events remain marked in the activity log. Structural edits such as a level-up, adding/removing equipment or spells, or changing counter maxima form a boundary that prevents partial undo of character setup. Notes, source XML, descriptions, and images are never restored from activity history.

History survives restarts in a separate local `activity.json`, with up to 50 entries per character and 200 overall. Character JSON backups remain compatible and do not include this local activity file. The app icon is now a faceted teal-and-gold d20 on a dark rounded tile, without a number or lettering.


## Creature actions and compendium selection

Active creatures also appear in **Actions**, labeled with their name and action timing. The Creatures category isolates these cards; timing filters include actions, bonus actions, reactions, and legendary actions. Dismissed creatures disappear from Actions without losing their records. Set timing in the creature editor; passive traits remain off Actions unless they have timing or a resource cost/counter. Attack cards provide separate attack and damage rolls. Choose **Save / damage only** for abilities that should not roll to hit. Creature rolls use their own bonuses, independently of the character’s conditions and equipment. Creature action counters participate in activity undo.

In Compendium, **Select multiple** enables a selection basket across categories and filters. Click entries to select them, or use Select shown (up to 200 entries per batch), then **Add selected…**. Both batch and single-entry **Add to character…** open an explicit destination picker with no character preselected. Transfers create independent copies; exact duplicate spells and reference features are skipped. Entries missing a spell level are reported for review rather than assumed to be cantrips. Adding class reference features does not change class levels or automatically apply their rules. Existing compendium entries and custom content remain intact.


## Printable character PDF

Choose **File → Export Character PDF…** (⇧⌘P), or **Export → Character PDF…** in the sidebar. **Export → Backup JSON…** preserves the editable archive. The default is a compact two-page sheet in A4 or US Letter: character essentials on page one and spells on page two. Open PDF launches the saved document in the Mac’s default viewer for previewing, sharing, or printing. No external service or internet connection is used.

The character page combines ability scores, saves, skills, combat, health, ready attacks, counters, a short feature index, and carried inventory in three columns. Applied bonuses are included in the statistics instead of repeated as a configuration dump. Setup/reference headings are omitted from the feature index. Equipment state and quantity remain visible. The spell page balances two columns with prepared/concentration/ritual markers, abbreviated casting times, ranges, default casting statistics, and remaining slots.

Full spell, feature, equipment, creature, and journal references are opt-in appendices. The compact pages have fixed space: unusually large lists display an explicit overflow count; appendices provide the complete reference text. Images and journal rich formatting are omitted. This is a static play snapshot; use JSON backups to preserve editable character data. Situational advantage and bonus dice remain table decisions.

PDF regression checks (native AppKit/PDFKit, no third-party dependency):

```sh
bash scripts/test-pdf.sh
```


## Option pickers and dice calculator

Attack damage type and common spell school/time/range/duration/component values use option pickers. Custom… opens a small editor; existing imported values remain selectable and are never rewritten just by opening the picker. Names, descriptions, and notes remain free text.

Click a formula to open the reusable dice calculator in attacks, creature attacks, equipment/spell/feature custom rolls, extra bonus dice, and the bottom roller (⌘D). Enter a count then choose a die; use +/− to combine terms, or select character values in compatible custom-roll fields. Standard dice, custom 2–1000-sided dice, numeric buttons, sign change, delete, Clear, and an Advanced formula disclosure are available. Use formula applies the draft; Cancel or clicking outside preserves the original. Only the bottom calculator has a Roll button, which explicitly rolls without changing character resources.

The preview computes the resolved formula, minimum, maximum, and average without rolling or consuming resources. Character tokens remain dynamic when saved in custom rolls or the bottom roller. Attack/base-damage and bonus-dice fields offer numeric dice only; the existing attack ability toggle continues to add the selected modifier separately. Supported syntax remains additive dice notation (+/−); arbitrary multiplication, division, and parentheses are not offered.


## Git history and release tags

The initial Git baseline is version **0.26.0**. Its logical commits capture the application, regression tests, generated-file exclusions, and release documentation; they are snapshots of the existing work rather than reconstructed historical releases. See [CHANGELOG.md](../CHANGELOG.md).

Use `feat:` for features, `fix:` for corrections, `test:` for verification changes, and `milestone:` for release checkpoints. Release tags such as `v0.26.0` point to the complete baseline. Generated `build/` and `output/` files are ignored; character saves remain in Application Support.


## Origin ability increases in the creator

Alignment uses the standard nine-alignment picker plus Unaligned and Custom. Ancestry browse rows and their preview buttons share a fixed 56-point height.

The Abilities step identifies the source of origin increases. Under 2024 rules these come from the background: choose +2/+1 on different abilities, or +1/+1/+1 on three abilities. When the imported background clearly lists its three abilities, other ability pickers are disabled. Older backgrounds allow any abilities under the compatibility rules. An ambiguous modern import can be checked in the reference/help popover and entered explicitly. Older ancestry increases are not added in 2024 mode.

Under 2014 rules, unambiguous complete fixed ancestry bonuses are filled from the XML ability field. A flexible ability-increase trait takes precedence over a conflicting legacy summary. Unknown or nonstandard origins use an explicit Custom / table rule option. Normal patterns validate their distribution, allowed abilities, and the ability-score cap of 20; Custom intentionally permits table overrides. Changing the relevant origin or edition resets its allocation. These rules affect creation drafts, never existing characters or level-up origin scores. Longer explanations live in a dismissible question-mark popover.

Reference: [Official 2024 character creation rules](https://www.dndbeyond.com/sources/dnd/br-2024/creating-a-character).

## Appearance and journal tags

Appearance can be set to Light, Dark, or System from the Drakebound app menu. Dark remains the default. This preference changes colors only.

Journal notes can have optional tags, entered as comma-separated names in the note editor. Click a tag or use the tag filter to browse related notes; note search also matches tags. Tags are saved with the note and included in JSON backups. Existing notes do not need tags.

Quick note is available beside New note in Journal, from the pencil icon in the bottom dock, and with ⇧⌘J. Enter text and optional comma-separated tags, then choose Add note or press ⌘Return. The first nonempty line becomes the title; the full text remains in the note. Saved entries use the normal journal editor, storage, and JSON backups. Closing the popover keeps the draft for its character while the app is open; restarting the app clears unfinished drafts.

## First launch

With no saved characters, Welcome offers Create a character, Import a character, and an optional Explore a demo preview. Creation uses the existing step-by-step guide and saves only after review. Imports accept Drakebound JSON backups or Fight Club character XML. You can browse or import compendium references before creating a character, and return with Welcome in the sidebar. The demo is added only after choosing Open demo character and is clearly named as a demo. Existing characters open directly into the workspace. Removing the last character returns to Welcome and the empty roster persists after restarting. If the saved archive cannot be read, the original file is protected from writes; restore a verified backup in its folder and use Try again.

### Compact play controls

Combat (⌘2) brings together ready attacks, spells, abilities, conditions, slots, and resources. Use ⌘K to search character content and references. Customize optional tabs from the Tabs menu; numeric shortcuts keep their fixed destinations. On Sheet, feature names reveal details and resource counts open adjustment controls. Character JSON and PDF exports are in the character banner menu; Back up in the sidebar includes all characters, the saved spell library, and user references.

Combat’s support column starts with conditions, then six saving throw roll controls and spell slots. Saving throws support the usual roll modes and condition modifiers.

Click a Sheet feature name to read its description and use controls in a popover; Done closes it without rearranging the list. Combat groups ready spells into Cantrips and ascending spell levels, keeping favorites first within each level. The Spells tab keeps preparation, concentration, and casting options in compact rows; click the name for full details and use the row menu to remove a spell.

In Compendium, scroll the category row horizontally to reach Conditions after Backgrounds. Conditions displays searchable condition and exhaustion references directly in Compendium.

Global search includes condition and exhaustion rules even without a selected character. In Compendium → Conditions, click a card to read its rules. Preview shows the selected rules in the resizable right sidebar on wide windows; narrower windows use the usual detail overlay. Reading rules does not apply a condition to a character.
