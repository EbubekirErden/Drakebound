# Android design direction — 23 October 2026

The owner selected the Field journal direction after exploring Ink & copper: warm paper content, dark header/navigation, and copper accents. The native draft uses an open sheet layout with compact controls.

## References reviewed

- [Fight Club 5th Edition's official Android listing](https://play.google.com/store/apps/details?id=com.lionsden.fc5&hl=en), including its published combat, abilities and spellbook screenshots. These show compact sections divided by fine rules, tabular statistics, and rows with inline values. This review covers the published screenshots, not a hands-on test of the installed app.
- Drakebound desktop's `Sources/CombatViews.swift` and `Sources/CombatActionRow.swift`: HP, AC, initiative and speed share a compact vital area; actions expose attack and damage controls on each row.

Borrow information hierarchy and interaction density, while keeping Drakebound's own visual identity and artwork.

## Applied changes

- Character home becomes a roster with serif names, compact cut-corner monograms, and separators, replacing large rounded character cards.
- Play puts HP, AC, initiative and speed directly on the page. A thin animated health track and quiet adjustment controls sit below.
- Concentration uses a narrow status rule. Actions use aligned hit bonuses and damage formulas, with a divider between rows.
- Spell resources use an inline table for every available level, with remaining/maximum counts, small marks and direct minus/plus controls on Play and Spells. Additional pools persist without replacing earlier draft data. Spells group by level.
- The six ability scores share one horizontal row. Skills appear in a compact list with modifiers and proficiency marks.
- Gear keeps a small diamond equip toggle in the same horizontal row as its item name. Names expand sample descriptions below the row; spell references behave the same way.
- Journal entries use a small session number, title, two-line excerpt, and tap-to-expand. Secondary text is 11–12sp; skill rows retain 44dp touch targets and equipment/slot controls use 48dp targets.
- Quick roll results anchor to the original attack/ability control, stay within window bounds and retain their original position, formula and mode on reroll. One large animated total replaces rows of individual dice; face limits follow the formula, with kept/dropped results summarized alongside.
- Calculators, rest/recovery, conditions, potion review and journal editing use bottom sheets. Amount entry has operation chips, a large expression display, flat keys, quick +1/+5/+10/+20 steps borrowed from the Mac controls and one apply action. Dice entry includes common dice and an inline custom side count. Long-rest review shows before/after values, following the Mac rest preview.
- Magic Missile has a one-tap “Cast · 1st” control that saves one slot cost, then opens anchored damage. Reroll only rolls damage again. Companion shortcuts use a circular monogram and HP rather than another card. Center alerts are reserved for explanatory notices/errors.
- Sheet, Gear, Journal and reference content use open sections. Filled surfaces are reserved for focused dialogs, the drawer, errors, and deliberate controls.
- The navigation bar is slimmer, with an animated copper underline and a coherent outline icon set: crossed swords, character sheet, spellbook, backpack and journal. Gear no longer uses a shopping cart.
- Motion reflects state changes: navigation moves the active marker, HP changes animate the track, and existing dice tumble and settle. System and app reduced-motion preferences remain respected.

The prototype's existing feature limitations remain: data is fictional, sheet statistics are fixed, references are brief samples, and Mac import/full advancement are not implemented. All changes stay in the Android draft sandbox; live Mac character data is unchanged.
