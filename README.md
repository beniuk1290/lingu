# LingoPilot 🦜

A production-grade Flutter application (Android + iOS) that automates vocabulary
learning sessions on [instaling.pl](https://instaling.pl) — a Polish spaced-repetition
vocabulary trainer for students.

LingoPilot opens the InstaLing website in an embedded WebView and answers the words
for you **at human speed, letter by letter**, while keeping a persistent personal
dictionary of every word it has ever seen.

---

## ✨ Features

### Learning automation
- **Human-like answering** — letters are typed one by one with randomized delays,
  thinking pauses between words and occasional typos that get corrected (backspace),
  exactly like a person. Never instant, never pasted.
- **Skip / "I don't know" handling** — falls back to `Nie znam` / `Pomiń` when needed.
- **Session stats** — words answered, successes, skips, accuracy % and session time.
- **Session log** — a live, colour-coded feed of everything the bot is doing.
- **Auto-start** — jumps straight into the session after login (`#continue_session_page`).

### Dictionary that never gets lost
- Every seen word (Polish ⇄ English/German) is stored locally with Hive — it survives
  restarts, updates and reinstalls-of-data.
- Search, filter by mastery level, manual add/edit/delete, batch import/export.

### Two accounts
- Two InstaLing accounts, switch between them in one tap.
- **Account-scoped login** — the login screen is bound to a specific account, so
  signing into the second account never overwrites the first one's session.
- **Cookie snapshot / restore** — every switch first wipes the WebView cookie jar
  completely and then restores exactly the selected account's session
  (sessions can never mix; if a session expired you just log in again).

### Languages & reminders
- Full app interface in **Polish, English and German** (Material 3, light & dark).
- **Daily local notification** reminding you to run your session (time is configurable).

### Background session (Android)
- Toggle in **Ustawienia → Sesja w tle**. A dedicated *Start w tle* button on the
  lesson screen runs the whole session in a **foreground service with a headless
  WebView** — you can leave (or lock) the app while the bot keeps working.
- On finish you get a **notification with session statistics** (answers, new words,
  saved to the account + dictionary). A 25-minute watchdog stops the service safely.
- Requires the notification permission (asked when enabling the toggle). Best
  results: exclude LingoPilot from battery optimization (Xiaomi/Huawei especially).
- Not available on iOS — the OS suspends apps in the background there.

### Onboarding
- First-run 7-step wizard (language → accounts → typing style → reminders →
  privacy → test → start).

### Settings
- **Podstawowe** tab — everything a beginner needs, in plain language.
- **Zaawansowane** tab — typing speed, human imperfections, skip policy, WebView
  privacy toggles, session behaviour, data management (export/import/clear).

---

## 🤖 Where the automation lives

| File | Role |
|------|------|
| `assets/js/instaling_bot.js` | The bot engine, injected into the WebView. Finds the question, types into `#answer`, clicks `#check` / `#nextword`, detects session end. Emits events to Dart via `window.flutter_inappwebview.callHandler('lpBotEvent', …)` and exposes a control API `window.__lpBot`. |
| `lib/services/bot_config.dart` | Translates the user's settings into the JS configuration. |
| `lib/screens/lesson_screen.dart` | Hosts the WebView, wires up the bot bridge, collects stats & dictionary entries, renders the log. |

The engine targets InstaLing's stable, public DOM (`#question .word_data .translation`,
`#answer`, `#check`, `#nextword`, `#word`, `#dont_know_new`, `#skip`,
`#start_session_page`, `#continue_session_page`, `#loading`, `#session_result`) and
degrades gracefully: if a selector disappears it keeps clicking what it can and logs
a warning instead of failing silently.

### ⚠️ Scope & fair use

LingoPilot is a **study aid**, not a cheat tool:

- It only performs **actions a human could perform in the browser** — typing and
  clicking at human speed. It does **not** bypass CAPTCHAs, anti-bot or any other
  security mechanism of instaling.pl.
- Privacy toggles (incognito, custom user agent, third-party cookies) are standard
  browser settings, nothing more.
- You are responsible for complying with your school's and InstaLing's terms of use.

---

## 🛠 Tech stack

- **Flutter 3.47.x** (Material 3, adaptive, light/dark)
- `provider` — state management
- `flutter_inappwebview` 6.x — WebView + JS bridge
- `hive` / `hive_flutter` — local persistence (dictionary, settings, accounts)
- `flutter_local_notifications` 17 + `timezone` — daily reminders
- `wakelock_plus` — keep the screen awake during a session
- `share_plus`, `file_picker`, `path_provider` — dictionary & settings import/export
- `flutter_localizations` + ARB files (pl / en / de), generated `AppLocalizations`

### Project layout

```
lib/
├── main.dart                 # bootstrap: storage, notifications, timezone
├── app.dart                  # MaterialApp, theming, localization, routing
├── l10n_ext.dart             # BuildContext → AppLocalizations helper
├── l10n/                     # app_pl.arb (template), app_en.arb, app_de.arb
├── theme/app_theme.dart
├── models/                   # AppSettings, DictEntry, Account
├── providers/                # SettingsProvider, DictionaryProvider, AccountsProvider
├── services/                 # storage, notifications, bot_config
└── screens/                  # onboarding, home, lesson, dictionary,
                              # settings, accounts, login_webview
assets/js/instaling_bot.js    # the automation engine
test/                         # model, theme and widget tests
```

---

## 🚀 Build & run

> Toolchain used on this machine (installed manually under `C:\dev`):
> Flutter SDK 3.47.7, JDK 17, Android cmdline-tools + platform-tools,
> Android SDK platform 36 & build-tools 36, NDK, MinGit.

### One-shot script (recommended)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_release.ps1          # release APK
powershell -ExecutionPolicy Bypass -File scripts\build_release.ps1 -Debug   # debug APK
```

Output is copied to `dist\app-release.apk` (also under `build\app\outputs\flutter-apk\`).

### Manual command

```powershell
$env:JAVA_HOME      = "C:\dev\jdk_extract\jdk-17.0.20.1+1"
$env:ANDROID_HOME   = "C:\dev\android"
$env:ANDROID_SDK_ROOT = "C:\dev\android"
$env:PUB_CACHE      = "C:\dev\pub-cache"
$env:PATH           = "C:\dev\flutter\bin;C:\dev\mingit\cmd;C:\dev\jdk_extract\jdk-17.0.20.1+1\bin;C:\dev\android\cmdline-tools\latest\bin;" + $env:PATH

flutter pub get
dart analyze          # note: use `dart analyze` (flutter analyze trips on the non-ASCII folder name)
flutter test
flutter build apk --release
```

Result: `build\app\outputs\flutter-apk\app-release.apk`

### ⚠️ Build pitfalls on this machine (all solved, do not re-break)

1. **Project path contains `ś`** ("Projekt domyślny"):
   - Gradle: `android.overridePathCheck=true` in `android/gradle.properties`.
   - Gradle daemon must run UTF-8: `-Dfile.encoding=UTF-8` in `android/gradle.properties`
     (otherwise AGP writes `android_gradle_build.json` in Cp1250 and the `:jni` native
     build fails with "Expected output file ... but there was none").
   - `gen_snapshot` (release AOT) cannot read the non-ASCII path at all →
     **release builds must run from the junction `C:\dev\lp`** (auto-created by
     `scripts\build_release.ps1`).
2. **Patched plugins in `C:\dev\pub-cache`** (re-apply if `flutter pub` downloads them again):
   - `flutter_inappwebview_android`: `getDefaultProguardFile('proguard-android.txt')`
     → `'proguard-android-optimize.txt'` (AGP 9 removed the old file).
   - `compileSdk 34/35 → 36` in: `file_picker`, `flutter_inappwebview_android`,
     `flutter_local_notifications`, `share_plus`, `jni`, `jni_flutter`,
     `flutter_timezone` (they must match the app's compileSdk 36).
3. `flutter_local_notifications` needs **core library desugaring** — enabled in
   `android/app/build.gradle.kts` (`desugar_jdk_libs:2.1.4`).
4. `flutter analyze` crashes on the non-ASCII folder name → use **`dart analyze`**.

### iOS

iOS builds require macOS (Xcode + CocoaPods). From this Windows machine they are
produced automatically by **GitHub Actions**:

- Repo: https://github.com/beniuk1290/linguapilot (private)
- Workflow: `.github/workflows/ios.yml` — on every push to `main` a macOS runner runs
  `pub get` → `gen-l10n` → `dart analyze` → `flutter test` →
  `flutter build ios --release --no-codesign` and uploads
  **`LingoPilot-ios-unsigned.ipa`** as an artifact (~4 min per run).
- Download: repo → *Actions* → latest green run → *Artifacts* (login required for a
  private repo).

**Installing the unsigned IPA without a Mac** (free Apple ID):

1. Download `LingoPilot-ios-unsigned.ipa` from the Actions artifact.
2. Use **Sideloadly** (Windows) or **AltServer/AltStore** — they sign the IPA with
   your Apple ID and install it on the iPhone.
3. The free signature expires after **7 days** — re-sideload weekly (AltStore can
   refresh automatically while AltServer runs).

Other options: full signing/TestFlight requires a paid Apple Developer account
(99 USD/yr); running in the **Simulator** requires a Mac with Xcode.

Free GitHub quota for private repos: 2,000 min/month, macOS counts ×10 →
~200 min ≈ up to ~40 iOS builds per month. Public repo = free.

---

## 📦 First launch checklist

1. Accept notification permission (Android 13+).
2. Complete the onboarding wizard (or skip it — everything is in **Ustawienia**).
3. Add your InstaLing credentials in **Konta**.
4. Go to **Lekcja**, pick an account, tap ▶ — the site logs in, the wizard starts
   and the bot takes over word by word.
5. Check **Słownik** afterwards — every word was saved there.

Enjoy learning! 🎓
