# Changelog

## v1.0.1 — 2026-11-08
- Release builds are signed with a dedicated release keystore
- New application id: `io.github.singhujjawalai.nottoday`
- Nudge notification names only the items returning that day
- Notification schedule refreshes on launch and when items change,
  without cancel/re-schedule churn
- Items that come due while the app is backgrounded resurface on resume
- One corrupt stored record no longer wipes the whole list
- Postpone history is trimmed to 60 days
- Undo is no longer swallowed by a following SnackBar
- No more "nothing on the list" flash while storage loads
- "Test notification now" is debug-only
- Tests expanded to 36 cases

## v1.0.0 — 2026-10-02
- Initial release
- Custom app icon (pause + forward arrow)
- Park, postpone, release workflow
- Weekly review screen
- Morning reminder notifications
- OLED-optimized dark theme
- Release APK available
