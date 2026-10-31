# Application deployment method

## Delivery model

Source code is delivered through GitHub. The application is delivered as an **Android debug APK for academic demonstration**, installed on an Android phone or emulator. GitHub Pages is not an application host for this project. No backend service, database server, payment gateway or internet connection is needed for runtime workflows.

## Prerequisites

- Flutter and its Dart SDK. The project README records Flutter 3.47.4 / Dart 3.13.3 as the previously tested toolchain; `pubspec.yaml` requires Dart `^3.13.3`.
- Android SDK and Android Studio, with an Android emulator or a phone configured for USB debugging.
- Git to clone the repository.

## Clone and prepare

Clone the public repository, then run:

```powershell
git clone https://github.com/AbdulmajeedM1/Thiqah.git
cd Thiqah
flutter doctor
flutter pub get
dart run tool/create_demo_admin.dart
```

The administrator setup command creates `assets/demo_admin.json` and prints the password. Keep the password privately; do not commit it or the generated seed. The generator intentionally refuses to replace an existing seed. For an existing local checkout with a seed, skip that command.

## Verify and run

```powershell
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

## Build and install the demonstration APK

```powershell
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

The APK is produced at `build/app/outputs/flutter-apk/app-debug.apk`. Run the `adb` command with a single intended device connected, or select it explicitly with `adb -s <serial> install -r ...`. Alternatively, copy the APK to an Android phone, open it and permit installation from that source when Android prompts.

The `-r` option requests replacement of an installed app while preserving data. The signing identity must match the installed app. Debug builds from different machines can have different debug signing keys; an update may therefore be rejected. Do not uninstall an existing installation without first considering its local data.

## Demonstration steps

1. Register a customer and publish a request with authorization.
2. Sign out, then register/sign in as a provider on the same device.
3. Open the published request and submit an offer.
4. Switch to the customer, choose the offer and perform simulated payment.
5. Switch to the chosen provider, exchange messages and submit completion proof.
6. Switch to the customer, confirm completion and review the service.
7. Sign in as the administrator using the locally generated password to demonstrate account management.

Accounts and requests are not synchronized between devices. Payments, balances and withdrawals are simulations. An opened dispute remains unresolved in this academic version.

## GitHub submission checklist

- Repository URL: https://github.com/AbdulmajeedM1/Thiqah
- README: the repository root `README.md`.
- Resource folder information: `docs/RESOURCE_FOLDERS.md`.
- Application deployment method: this document.
- Design report: `docs/Thiqah_Project_Analysis_Design.pdf`.

An APK may be attached to a GitHub Release for convenient installation after review. A Play Store release requires a separate release-signing and publishing workflow; the debug APK is not a store release.

## Validation record

The existing README records earlier successful analysis and 33 passing tests. Preparing these submission documents does not constitute a new application test run or a successful GitHub upload.
