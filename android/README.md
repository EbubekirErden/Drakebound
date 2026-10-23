# Drakebound Android draft

A native Kotlin / Jetpack Compose prototype of the compact **Field journal** design: warm paper, dark header/navigation, and copper accents. Open this `android/` folder as a project in Android Studio, allow Gradle to sync, select a phone emulator or USB-debugging device, then run the `app` configuration. The launcher name is **Drakebound Draft**.

The revised interface uses open sheet sections, six ability scores across one row, a skill list, inline attack/damage formulas, and a compact tab bar. Equipment uses a small diamond toggle in the same row as its item name. Gear/spell names expand descriptions in place, and journal previews use two lines with tap-to-expand. See [design references and decisions](../docs/ANDROID_DESIGN.md).

## What works

- Two fictional characters, a character picker, five bottom tabs (Play, Sheet, Spells, Gear, Journal), and a hamburger drawer with direct companion access.
- Random dice with signed formulas, a formula calculator, min/max/average previews, advantage/disadvantage, and kept/dropped summaries. One large animated total handles every pool size, including d1000, without adding rows of dice. It retains the settling spring, optional haptics, and reduced-motion support.
- Bottom-sheet calculators for damage, healing, temporary HP, gold, potion quantities and companion HP. Operation chips select one action; the large expression display, flat keypad, quick +1/+5/+10/+20 buttons and one apply action keep entry compact. “Type” opens the system keyboard. Integer +, −, ×, ÷ and typed parentheses are supported, with multiplication precedence. Fractional division is rejected explicitly. Dice entry also offers an inline custom die with 2–1000 sides.
- Temporary HP absorbs damage first; healing caps at maximum HP. Amounts preview results and apply only after a button press.
- Inline 1st–3rd-level slot tables on both Play and Spells, spells grouped by level, one-tap Magic Missile casting, a before/after long-rest review, Arcane Recovery, condition tracking, potion consumption/healing, character rename, and one editable journal note. The additional slot fields default safely when loading an earlier draft save.
- Attack, damage, initiative and ability/skill rolls open beside their original control; reroll preserves that anchor, formula and mode. Calculators, rest/recovery, conditions, potion review and journal editing use bottom sheets. Casting saves one slot cost before revealing damage; reroll does not spend another slot. Center alerts are reserved for explanatory notices/errors.
- Sample mutations save in the Android application's private sandbox. Failed writes show an error instead of reporting success. Dice and activity histories last for the current app process.
- Field journal is the default; an optional dark appearance is available. No network permission or background service.

## Scope and data safety

This is an interaction prototype, not a complete character manager. The sample sheet contains fixed statistics and descriptions are brief sample references. It does not implement full class/rules automation, condition effects on rolls, hit dice, death saves, upcasting or complete reaction casting, full creation/level-up, production database migrations, Mac import/export, or the bundled SRD library. Incomplete controls explain that status rather than modifying real characters. Appearance preferences are session-only in this draft.

The app ID is `com.drakebound.android.draft`. Its draft-only preferences are named `android-prototype-only-v1`. Android system backup is disabled. It never reads the Mac `Fellowship5e` directory, and the samples contain no private user data. Uninstalling the draft removes its sample saves.

Dice animation reveals a single generated result; the animated total does not change the outcome. Formula editing and bounds calculation never roll dice. Roll history records the actual result before animation so dismissing an animation does not lose it. Rerolling a result rolls dice only; it does not repeat potion consumption or spell-slot costs.

## Build and verify

The project uses Gradle 9.4.1, AGP 9.2.1, Compose compiler 2.3.10 and Compose BOM 2026.09.00. Its daemon toolchain is pinned to JDK 21 for consistent Android Studio and CLI builds. It requires Android SDK 37 and build tools 36.0.0. Minimum Android version is API 26 for this prototype; the release support range is not finalized. The test APK uses Espresso 3.8.0-alpha01 specifically for Android 17 input compatibility; that dependency is not shipped in the app.

From the repository root, after completing the live-data backup requirements in `AGENTS.md`:

```sh
bash scripts/build-android.sh
```

The helper builds the debug APK and runs focused unit tests. The APK is `android/app/build/outputs/apk/debug/app-debug.apk`.

```sh
bash scripts/build-android.sh :app:assembleDebugAndroidTest
bash scripts/test-android-ui.sh
```

The first command downloads and builds the instrumentation dependencies. Start a phone emulator in Android Studio before running the UI helper. The helper defaults to `emulator-5554`; set `DRAKEBOUND_ANDROID_TEST_SERIAL` to another running local emulator if needed. It builds a separate `com.drakebound.android.draft.verification` application, so fixture preferences and files live in a physically separate, disposable app data directory. Tests assert this identity before interacting. The helper refuses to overwrite an existing verification install, saves synthetic screenshots in `output/android-ui/`, uninstalls only the verification packages afterward, and rebuilds the regular deliverable APK. The normal draft's app data is retained. It expects the verified Mac hash baseline at `/tmp/drakebound-ui-live-hashes.json` produced by the backup step in this workspace; it does not create or replace the owner's backup itself.

Test fixtures and generated output are excluded from Git. Follow `AGENTS.md` before builds, tests, previews and installations. Do not copy real character archives into the Android project.

Verified on 23 October 2026: debug APK build, five rules/calculator unit tests, eight emulator interaction tests, and Android lint (zero errors). Native screenshots are available in `output/android-ui/screenshots/`. The Mac character, compendium, and activity hashes were unchanged after verification. Physical-device performance and full accessibility coverage remain to be checked before a release.
