# Protect user character data

- Before development, tests, previews, installations, or data repair, create a timestamped backup of `~/Library/Application Support/Fellowship5e/characters.json`, `compendium.json`, and `activity.json`. Include portraits in the character archive. Validate JSON and verify SHA-256 hashes of the copies.
- Keep one current, verified full backup in `~/Documents/Drakebound Backups/`, as requested by the owner. Create and verify its replacement before removing the previous backup. Do not accumulate additional copies in `output/backups/`, build folders, or temporary preview folders. Backups contain private user data; never commit them to Git. Preserve additional history only when explicitly requested.
- Never substitute fixture characters into a Store using the live save location. Previews and test fixtures must use a physically separate temporary data directory for characters, compendium, activity, and autosaves. Assert the isolated file path before changing fixtures.
- Hash the live save before and after any preview/test run and confirm it is unchanged. If it changes unexpectedly, stop and investigate before further app work.
- Never overwrite a live save from a preview, test, old snapshot, or running app instance. For user-authorized repairs, back up first, preserve unrelated characters, and validate the resulting archive.
