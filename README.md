<p align="center">
  <img src="assets/icon/app_icon.png" width="112" alt="Not Today app icon"/>
</p>

<h1 align="center">Not Today</h1>

<p align="center">
  <strong>Park what can't happen today — without the guilt.</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2E7BC4" alt="MIT License"/></a>
  <img src="https://img.shields.io/badge/platform-Android-2E7BC4" alt="Platform: Android"/>
  <img src="https://img.shields.io/badge/Flutter-3.13-027DFD?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/version-1.1.0-4A90DA" alt="Version 1.1.0"/>
</p>

---

Not Today is a small, local-first Android app for the things that are real but can't
happen today. Park them, set them aside for tomorrow, or let them go — and keep a
quiet record of what actually moved.

No account. No sync. No streak to protect.

## Features

- **Park in one line.** Add a thought, a chore, or a conversation in a single
  field. Nothing needs a due date, a project, or a priority.
- **"Not today" that means tomorrow.** Postponed items leave the list and
  return on their own when the day turns — even if the app is in the
  background. Found time today? Bring one back from the resting shelf.
- **Three gentle exits.** Tap a parked item to reveal *Not today*, *I did it*,
  and *Let it go*. Releasing something is treated as progress, not failure.
  *Edit* and *Remove* sit quietly below them for housekeeping.
- **Undo everywhere.** Every exit — postpone, done, let go, remove — has a
  short grace period, so nothing is ever gone by accident.
- **Weekly review.** A quiet summary of what you parked, finished, and let go —
  plus the item you've carried the longest and the one you keep postponing.
- **Backups.** Save the whole list as one small JSON file and restore it any
  time; restoring merges, it never wipes.
- **Optional morning nudge.** One daily notification, only when it's useful.
  It names just the items returning that day, and says nothing on quiet days.
- **OLED-first design.** True-black dark theme, clean light theme, and a single
  sky-blue accent. Follows the system setting.
- **Private by default.** All data stays on the device. The release build has no
  network access, no analytics, and no tracking.

## Screens

| Screen | Purpose |
| --- | --- |
| **Home** | The parked list, a single-line count, and the resting shelf for items set aside with "Not today". |
| **This week** | Parked / did / let-go stats, the longest-carried item, and a mirror for anything postponed three or more times in a week. |
| **Settings** | The morning nudge toggle and time, plus backup save and restore. |

## Download

Per-ABI builds live in [`releases/`](releases) — pick the one matching your
device (most phones are arm64-v8a):

- **arm64-v8a** — [Not-Today-v1.1.0-arm64-v8a-release.apk](releases/Not-Today-v1.1.0-arm64-v8a-release.apk)
- **armeabi-v7a** (older 32-bit devices) — [Not-Today-v1.1.0-armeabi-v7a-release.apk](releases/Not-Today-v1.1.0-armeabi-v7a-release.apk)
- **x86_64** (emulators) — [Not-Today-v1.1.0-x86_64-release.apk](releases/Not-Today-v1.1.0-x86_64-release.apk)

Requires Android 7.0 (API 24) or newer. Install with `adb install <file>` or by
opening the APK on your device.

## Building from source

### Requirements

- Flutter 3.13 or newer (Dart 3.13)
- Android SDK 36 and Java 17
- A device or emulator running Android 7.0+

### Run

```bash
flutter pub get
flutter run
```

### Release builds

Build one APK per ABI:

```bash
flutter build apk --release --split-per-abi
```

Output in `build/app/outputs/flutter-apk/`:

| ABI | Artifact |
| --- | --- |
| `arm64-v8a` | `app-arm64-v8a-release.apk` — most modern phones |
| `armeabi-v7a` | `app-armeabi-v7a-release.apk` — older 32-bit devices |
| `x86_64` | `app-x86_64-release.apk` — emulators |

Install the matching APK with `adb install` or `adb install-multiple` when
installing several splits together.

### Release signing

Release builds read their signing configuration from `android/key.properties`.
Copy the example and create a keystore:

```bash
cp android/key.properties.example android/key.properties
keytool -genkey -v -keystore android/nottoday-release.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias nottoday
```

Fill in the passwords and keystore path in `key.properties`. Neither that file
nor the keystore should ever be committed — both are gitignored.

Without `key.properties`, release builds fall back to debug signing and cannot
be published.

## Tech stack

| Area | Choice |
| --- | --- |
| UI | Flutter, Material 3 |
| Storage | `shared_preferences` with local JSON |
| Notifications | `flutter_local_notifications` + `timezone` |
| Formatting | `intl` |
| Files | `file_picker` (Storage Access Framework) |
| IDs | `uuid` |

## Project layout

```text
lib/
├── main.dart                 App entry point and themes
├── models/                   Item model and postpone/release logic
├── screens/                  Home and weekly review
├── services/                 Local storage and reminder scheduling
└── widgets/                  Sheets, cards, and empty state
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

[MIT](LICENSE) © 2026 Ujjawal Singh
