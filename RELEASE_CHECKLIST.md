# Release checklist

## Repository setup

- [ ] Choose the permanent GitHub repository or fork.
- [ ] Point `origin` at that repository without losing the upstream reference.
- [ ] Confirm the repository name and replace any remaining temporary wording.
- [ ] Enable GitHub Issues for compatibility reports.

## Version and metadata

- [x] Use `1.0.0` for the first public release.
- [ ] Align `CFBundleShortVersionString`, `CFBundleVersion` and the Git tag.
- [x] Confirm the copyright and contributor attribution.
- [ ] Move the relevant `CHANGELOG.md` entries from `Unreleased` to the version
      and release date.

## Clean build

- [ ] Start from a fresh checkout.
- [ ] Run `./install.sh` without an existing installation.
- [ ] Confirm that the menu bar and app icons render correctly.
- [ ] Confirm that the app starts again after logout or restart.
- [ ] Run `./uninstall.sh` and confirm that the Touch Bar turns on again.
- [ ] Confirm that no local build output or Finder metadata is committed.

## Behavioural test

- [x] Stable mode remains flicker-free during normal use.
- [x] Calibration completes, cancels safely and restarts the idle timeout.
- [x] A representative inactivity timeout turns the Touch Bar off as expected.
- [x] Keyboard or pointer activity restores it without a long fade.
- [x] Fully-off mode remains off after Touch Bar status changes.
- [x] Sleep and wake restore the selected mode.
- [x] Terminal `off` and `on` commands work.
- [ ] About and Quit behave correctly.

## Compatibility and safety

- [ ] Record the exact macOS version used for the release test.
- [ ] Test on additional Touch Bar models if they are available.
- [ ] Reconfirm that a failure of a private API produces a visible error.
- [ ] Review the README limitations and health warning.

## GitHub release

- [ ] Review the complete diff against the upstream starting point.
- [ ] Merge the release branch into the chosen default branch.
- [ ] Create an annotated version tag.
- [ ] Publish release notes based on `CHANGELOG.md`.
- [ ] For a source-only release, state clearly that users build locally.
- [ ] Do not publish a binary until signing, notarisation and update strategy
      have been decided and tested.
