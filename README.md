# GrindMode

GrindMode is a **gamified productivity and focus tracking app** built with Flutter.
It helps students stay focused while studying by turning productivity into a competitive and rewarding experience.

## Features

* ⏱ Focus timer for deep study sessions
* 📈 Study reports and productivity tracking
* 🏆 XP system and leaderboards
* 👥 Groups for competing with friends
* 🔥 Daily streak tracking
* 🏅 Unlockable badges
* 🎨 Multiple themes and backgrounds
* 🔐 Firebase authentication (Google login)
* 🤖 AI features and sarcastic motivational roasts

## Screenshots

### Focus Screen
![Focus Screen](screenshots/focus.jpeg)

### Reports
![Reports](screenshots/report.jpeg)

### Roast Feature
![Roast](screenshots/roast.jpeg)

### Groups
![Groups](screenshots/groups.jpeg)

### Leaderboard
![Leaderboard](screenshots/leaderboard.jpeg)

### Profile
![Profile](screenshots/profile.jpeg)

## Built With

* **Flutter**
* **Firebase Authentication**
* **Cloud Firestore**
* **Firebase Storage**

## Screens

The app includes multiple screens such as:

* Focus timer
* Groups
* Leaderboards
* Reports
* Profile
* Tasks

## Running the App

### Prerequisites

| Tool | Minimum version | How to check |
|------|----------------|-------------|
| Flutter SDK | 3.0.0 | `flutter --version` |
| Dart SDK | 3.0.0 | included with Flutter |
| Android Studio **or** Xcode (macOS only) | latest stable | for emulator/simulator |
| Chrome | any | for web runs |

> **Firebase is already configured** – `google-services.json` (Android) and `lib/firebase_options.dart` are committed to the repo, so no extra Firebase setup is needed.

---

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Choose a target and run

#### Android emulator (recommended on Windows/Linux/macOS)

```bash
# list available emulators
flutter emulators

# launch one (e.g. Pixel_6_API_33)
flutter emulators --launch Pixel_6_API_33

# run the app on it
flutter run
```

#### iOS simulator (macOS only)

```bash
open -a Simulator          # starts the default simulator
flutter run
```

#### Chrome (web – no emulator required, quickest option)

```bash
flutter run -d chrome
```

> If multiple devices are connected/running, `flutter run` will prompt you to pick one.  
> Pass `-d <device-id>` to skip the prompt (get device IDs with `flutter devices`).

---

### 3. Hot-reload while the app is running

After `flutter run` starts:

| Key | Action |
|-----|--------|
| `r` | Hot reload (keeps app state) |
| `R` | Hot restart (resets state) |
| `q` | Quit |

---

## Verifying the Recent Changes

### ✅ Login screen – input validation
1. Open the app and tap **Log In**.
2. Try submitting with an **empty email** → you should see *"Email is required"*.
3. Try an **invalid email** (e.g. `foo@bar`) → *"That's not even a real email bro"*.
4. Try an **empty password** → *"Password is required"*.
5. Enter valid credentials → login proceeds normally.

### ✅ Groups screen – faster loading
1. Log in and open the **Groups** tab.
2. Group members now load in parallel instead of one-by-one.  
   On a group with many members the list should appear noticeably faster.

### ✅ Report screen – Claude Opus 4 AI roast + daily caching
1. Log in and open the **Reports** tab.
2. The **roast / motivation card** at the top calls **`anthropic/claude-opus-4`** via OpenRouter.
3. The result is cached for the day (keyed per user + date in `SharedPreferences`).  
   - **First visit of the day**: the card shows a loading spinner, then the AI response.  
   - **Subsequent visits the same day**: the cached text appears instantly (no spinner).
4. To force a fresh call (e.g. during development), clear the app's storage or uninstall/reinstall, then reopen Reports.

---

## Running the Tests

```bash
flutter test
```

All widget tests live in `test/widget_test.dart`.

---

## Author

Created by **navneethdevj** (originally forked from **SayuSky**).
