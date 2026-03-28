# 📱 Daily Routine Tracker — Complete Build Guide

A step-by-step guide to get your app running on your Android phone.
**No prior coding experience needed!**

---

## 🗂️ What's in This Project

```
daily_routine_app/
├── pubspec.yaml                 ← App dependencies (packages used)
├── lib/
│   ├── main.dart                ← App entry point + theme
│   ├── models/
│   │   ├── habit.dart           ← Habit data model
│   │   └── habit_record.dart    ← Daily record model
│   ├── database/
│   │   └── database_helper.dart ← All SQLite operations (local storage)
│   └── screens/
│       ├── home_screen.dart     ← Home screen with stats
│       ├── checklist_screen.dart ← Daily habit checklist
│       ├── monthly_view_screen.dart ← Monthly grid view
│       └── report_screen.dart   ← Excel export screen
└── android/
    └── app/src/main/
        ├── AndroidManifest.xml  ← Android permissions config
        └── res/xml/file_paths.xml ← File sharing config
```

---

## 🚀 STEP 1 — Install Flutter on Your Computer

Flutter is the tool that converts your code into an Android app.

### Option A: Windows PC

1. Go to: **https://flutter.dev/docs/get-started/install/windows**
2. Click **"Download Flutter SDK"** (it's a zip file, ~1.5 GB)
3. Extract the zip to `C:\flutter` (exact path matters!)
4. Open **System Properties** → **Environment Variables**
5. Under "User Variables" → find **Path** → click **Edit**
6. Click **New** → type `C:\flutter\bin` → click **OK**
7. Restart your computer
8. Open **Command Prompt** (search "cmd") and type:
   ```
   flutter doctor
   ```
9. You should see checkmarks. The important one is **Android toolchain**.

### Option B: Mac

1. Open **Terminal** (press Cmd+Space, type "Terminal")
2. Install Homebrew first (if not installed):
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. Install Flutter:
   ```
   brew install flutter
   ```
4. Verify:
   ```
   flutter doctor
   ```

---

## 🔧 STEP 2 — Install Android Studio

This gives you the Android SDK (tools to build Android apps).

1. Download from: **https://developer.android.com/studio**
2. Install it (keep clicking "Next")
3. On first launch, it will download Android SDK automatically — let it complete
4. Open **Android Studio** → **More Actions** → **SDK Manager**
5. Make sure **Android 13.0** (or latest) is checked and installed

---

## 📁 STEP 3 — Set Up Your Project

1. Copy the `daily_routine_app` folder to your Desktop (or anywhere easy to find)
2. Open **Terminal** (Mac) or **Command Prompt** (Windows)
3. Navigate to your project:
   ```
   cd Desktop/daily_routine_app
   ```
4. Download all the required packages:
   ```
   flutter pub get
   ```
   ✅ You should see: "Got dependencies!"

---

## 📲 STEP 4 — Build the APK File

An APK is the file you install on your Android phone.

Run this command:
```
flutter build apk --release
```

Wait 2–5 minutes. When done, you'll see:
```
✓ Built build/app/outputs/flutter-apk/app-release.apk
```

The APK file is at:
`daily_routine_app/build/app/outputs/flutter-apk/app-release.apk`

---

## 📥 STEP 5 — Install on Your Android Phone

### Method A: USB Cable (Easiest)

1. On your Android phone: **Settings** → **About Phone** → tap **Build Number** 7 times
2. Go to **Settings** → **Developer Options** → enable **USB Debugging**
3. Connect your phone to your computer via USB
4. On your phone, when prompted: tap **"Allow USB Debugging"**
5. Run this command to install directly:
   ```
   flutter install
   ```

### Method B: File Transfer

1. Copy `app-release.apk` to your phone (via WhatsApp, Google Drive, or USB)
2. On your phone, open the APK file
3. If prompted, allow **"Install from unknown sources"** for your file manager
4. Tap **Install**

---

## 🎯 STEP 6 — Using Your App

### Home Screen
- Shows today's progress, your streak, and completion rate
- Tap **"Start Monitoring"** to open today's checklist

### Daily Checklist
- Tap any habit to mark it as done ✅
- Data saves **automatically** to your phone — no internet needed!
- Even if you close the app, your data is saved

### Monthly View
- See all your habits across the entire month in a grid
- ✅ = done, ❌ = missed, gray = no data
- Use ← → arrows to switch months

### Export Report
- Choose a date range (or use Quick Select buttons)
- Tap **"Download Excel Report"**
- An Excel file will be created and shared via WhatsApp/Drive/Email

---

## 🌟 Features Summary

| Feature | Status | Notes |
|---------|--------|-------|
| 15 default habits | ✅ | Your exact list |
| Auto-save on tap | ✅ | Works offline |
| Streak tracking | ✅ | Current + best streak |
| Monthly grid view | ✅ | Scrollable, color-coded |
| Excel export | ✅ | With date filter |
| Progress bar | ✅ | Real-time updates |
| Score % per day | ✅ | In export + preview |

---

## 🔧 Customizing Your Habits

To change habit names or add new ones, open:
`lib/database/database_helper.dart`

Find the `defaultHabits` list (around line 50):
```dart
final defaultHabits = [
  {'name': 'Wake up at 6:00 AM', 'emoji': '⏰', 'order_index': 0},
  // Add more here like:
  {'name': 'Meditate', 'emoji': '🧘', 'order_index': 15},
];
```

**Note:** Changing habits after the app is installed won't update existing data.
Uninstall and reinstall the app to apply habit changes.

---

## 🆘 Troubleshooting

### "flutter: command not found"
→ Flutter is not in your PATH. Re-do Step 1 carefully.

### "No devices found" when running flutter install
→ Make sure USB Debugging is ON and you tapped "Allow" on your phone.

### App crashes on startup
→ Uninstall any previous version first, then install fresh.

### Excel file doesn't open
→ Install **Microsoft Excel** or **Google Sheets** on your phone.
   WhatsApp can also receive and open the shared file.

### "pub get" fails
→ Check your internet connection. If it still fails:
```
flutter clean
flutter pub get
```

---

## 🔮 Future Ideas (Phase 4+)

- **Daily reminder notifications** at a set time
- **Add/remove habits** from the app itself (without code)
- **Dark mode** support
- **Weekly summary card** with emoji
- **Cloud backup** via Google Drive

---

## 📞 Need Help?

If you get stuck on any step, share the exact error message you see in the terminal — it'll be easy to fix with the right information!

---

*Built with Flutter 3.x | SQLite local storage | Excel export | Offline-first*
