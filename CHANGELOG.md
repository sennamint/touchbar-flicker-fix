# Changelog

All notable changes to TouchBar Flicker Fix will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project intends to follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-17

### Added

- Stable-brightness mode for suppressing low-brightness Touch Bar flicker.
- Guided calibration with coarse and interval-narrowing phases.
- A 40% calibration safety margin and a minimum stable target.
- Configurable inactivity timeout with immediate off and wake transitions.
- Menu bar controls for changing the operating mode and idle timeout.
- An About panel, persistent settings and terminal `on`/`off` commands.

### Changed

- Renamed the app from TouchBarOff to TouchBar Flicker Fix.
- Reorganised the production source and documented the experimental tools.
- Expanded installation, compatibility and troubleshooting documentation.

### Compatibility

- Tested on a 13-inch M1 MacBook Pro (`MacBookPro17,1`).
- Other Touch Bar models and future macOS releases remain unverified.

## Upstream foundation

The project began as a derivative of Guillermo Pages' `touchbar-off`, licensed
under the MIT License.
