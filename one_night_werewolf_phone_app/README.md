# one_night_werewolf

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Open and run iOS simulator

```bash
open -a Simulator
flutter run -d ios # Obtain the iOS simulator ID
flutter run -d <ios_simulator_id>
```

## Open and run Android simulator

```bash
flutter emulators
flutter emulators --launch <android_device_id> 
flutter run -d android # Obtain the android simulator ID
adb uninstall com.example.one_night_werewolf
flutter run -d <android_simulator_id>
```

## Debug Android build

```bash
flutter clean
flutter build apk --release
```

## Debugging Tips

1. Android build will fail if you dont have Android SDK installed. Install Android SDK and make sure that `one_night_werewolf/android/local.properties` has `sdk.dir` defined
