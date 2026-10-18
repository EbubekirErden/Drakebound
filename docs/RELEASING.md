# Release checklist

[Project overview](../README.md) · [Changelog](../CHANGELOG.md)

A release consists of a reviewed source commit, a matching version tag, release notes, and a downloadable app archive. GitHub's automatic source archives do not contain a compiled application.

## Prepare a version

- Coordinate with other active work before building or changing versions. Review `git status` and the diff; include only intentional, completed changes.
- Follow [AGENTS.md](../AGENTS.md) to back up and verify private data before tests, builds, or installation. Keep backups and fixtures out of the release.
- Choose the release version. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in `scripts/build.sh`. Do not infer the next version solely from the latest local tag.
- Move completed Unreleased notes into the chosen version in `CHANGELOG.md`. Leave unfinished work under Unreleased. Check README/user-guide claims against the actual release.
- Decide licensing before describing the project as open source. There is currently no declared repository license.

## Verify and package

Run the checks relevant to the release and build once from the final source state. See [CONTRIBUTING.md](../CONTRIBUTING.md) for commands and data precautions. Confirm the intended version and architecture, then smoke-test that build with isolated data. Record checks actually run and any limitations.

The current build script creates an Apple silicon app for macOS 14 or later and uses ad-hoc signing. It does not perform Developer ID signing or notarization. Describe the signing status accurately; a public distribution signing/notarization workflow is separate work.

Package only the reviewed app. For example, from the repository root, replace `VERSION` with the chosen version:

```sh
mkdir -p output/releases
/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
  build/Drakebound.app output/releases/Drakebound-vVERSION-macOS-arm64.zip
shasum -a 256 output/releases/Drakebound-vVERSION-macOS-arm64.zip
```

Confirm that the ZIP contains `Drakebound.app` and no character data, fixtures, caches, or output/backups. Keep it outside tracked source; `output/` is ignored. Retain the checksum for the release notes or an attached checksum file.

## Create a draft on GitHub

1. Commit and push the intended source. Create/push a matching version tag, or select the exact intended commit when creating the tag on GitHub. An existing tag must already point to the reviewed commit.
2. Open [New release](https://github.com/EbubekirErden/Drakebound/releases/new), select the matching tag, and title it `Drakebound VERSION`.
3. Add release notes using the outline below and attach the packaged app ZIP and its checksum.
4. Save a draft. Review the version, target commit, assets, installation steps, and signing status. Mark experimental releases as prereleases.
5. Publish when the owner is ready. Check the published download and installation instructions.

Official instructions: [Managing releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).

## Release notes outline

```markdown
## Changes
- Describe the user-visible changes included in this version.

## Download and install
- Requires an Apple silicon Mac with macOS 14 or later.
- Download the attached app ZIP, extract it, and move Drakebound.app to Applications.
- Export a JSON backup before upgrading.
- State whether this specific build is ad-hoc signed or Developer ID signed/notarized.

## Known limitations
- List issues relevant to this release and any checks that remain incomplete.

## Verification
- List checks performed against this source commit and packaged app.
- SHA-256: <checksum of the attached app ZIP>
```
