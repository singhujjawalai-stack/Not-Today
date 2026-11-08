<h1 align="center"><img src="https://img.shields.io/badge/Not-Today-2E7BC4?style=for-the-badge&logo=flutter&logoColor=white" alt="Not Today"/></h1>
<p align="center">
  <img src="https://img.shields.io/github/license/singhujjawalai-stack/Not-Today?label=MIT&color=2E7BC4"/>
  <img src="https://img.shields.io/github/repo-size/singhujjawalai-stack/Not-Today?color=4A90DA"/>
  <img src="https://img.shields.io/badge/Flutter-027DFD?logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/APK-releases-2E7BC4"/>
</p>
<p align="center">Park tasks without guilt. Postpone to tomorrow. Calm sky-blue design.</p>
---
## Features
- Park tasks with "Not today"
- Postpone to tomorrow
- Weekly review screen
- Morning reminder notifications
- OLED dark mode
## Download
[Not-Today-v1.0.1-release.apk](releases/Not-Today-v1.0.1-release.apk)
## Build
```bash
flutter pub get
flutter run
```
## Release signing
Release builds read `android/key.properties`. Copy the example, create a keystore, and point the file at it:

```bash
cp android/key.properties.example android/key.properties
keytool -genkey -v -keystore android/nottoday-release.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias nottoday
```

Without `key.properties`, release builds fall back to debug signing and cannot be published to the Play Store. Never commit the keystore or its passwords.
## License
MIT — see [LICENSE](LICENSE)
