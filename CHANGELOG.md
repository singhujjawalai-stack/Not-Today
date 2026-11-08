# Changelog

All notable changes to Not Today are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.1] — 2026-11-08

### Added

- Release builds are signed with a dedicated release key, ready for distribution
  and in-place updates.

### Changed

- Morning nudges name only the items returning that day instead of the entire
  parked list.
- The nudge schedule refreshes when the app opens or the list changes, without
  unnecessary cancel-and-reschedule churn.
- Items that come due while the app is in the background reappear as soon as you
  return to it.
- Postpone history is capped at 60 days to keep stored data lean.
- The debug-only "Test notification now" action is no longer included in release
  builds.

### Fixed

- A single unreadable stored record no longer wipes the entire list.
- Undo after "I did it" or "Let it go" is no longer dismissed by a following
  snackbar.
- The empty state no longer flashes "Nothing waiting" while the list is loading.

## [1.0.0] — 2026-10-02

### Added

- Initial release.
- Park tasks in one line; postpone with "Not today"; release with "I did it" or
  "Let it go".
- Instant Undo for releases.
- Weekly review with parked/did/let-go stats, the longest-carried item, and a
  gentle prompt for repeatedly postponed items.
- Optional daily morning nudge.
- Light theme and OLED-optimized dark theme.
- Custom app icon and launcher assets.
