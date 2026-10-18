# Included SRD references

This directory contains CC BY 4.0 game content, separately from the application code. Read [ATTRIBUTION.txt](ATTRIBUTION.txt) and the [full license](CC-BY-4.0.txt).

The app includes 1,675 searchable references: 339 spells, 12 core classes with their SRD subclasses, 9 species, 4 backgrounds, 17 feats, 963 equipment/magic-item references including expanded variants, and 331 creature references. Only the SRD subset is included. Other books, third-party homebrew, user imports, character archives, portraits, and journal entries are excluded.

Spell/class/origin/feat descriptions are adapted from the SRD 5.2.1 Markdown transcription vendored in omni-5e. Open5e's SRD 5.2 dataset supplies structured metadata and equipment/creature records. This is a mixed 5.2/5.2.1 reference conversion, not a claim that every structured field incorporates all 5.2.1 errata. The official, unmodified **SRD-5.2.1.pdf** is included for checking details. Descriptions do not imply complete rules automation.

## Reproduce the conversion

`provenance.json` records immutable upstream revisions, counts and SHA-256 hashes. Download those revisions from the listed repositories and run, from the Drakebound root:

```sh
python3 scripts/convert-srd.py \
  --open5e /path/to/open5e-api/data/v2/wizards-of-the-coast/srd-2024 \
  --markdown /path/to/omni-5e/data/raw/5.2.1 \
  --output /tmp/drakebound-srd
```

Compare the generated `srd-compendium.json` with this directory before updating resources. Review source changes against the official PDF; then update provenance/checksums and run `BundledSRDTests` and the isolated welcome checks. The converter reads only the supplied public source directories and writes only the requested output directory. The app never downloads rules at runtime.

Reference IDs are deterministic and include category and upstream key. Names include `[2024]` so bundled weapons cannot silently remap an existing, differently named inventory item. Original bundled records remain read-only references in the compendium; Edit copy makes a reusable custom entry.
