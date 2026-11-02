# GitHub resource folder information

The repository contains the Flutter university-project edition of **Thiqah / Trust**. It supports customer, provider and administrator accounts on a single device.

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Application startup, theme, localization and authentication routing. |
| `lib/src/app.dart` | Main navigation, customer/provider home and account screens. |
| `lib/src/auth.dart` | Account model, authentication controller and token-storage interface. |
| `lib/src/local_auth.dart` | Device-only account registration, password verification, sessions and administrator permissions. |
| `lib/src/auth_screens.dart` | Login, registration and password-change forms. |
| `lib/src/admin_screen.dart` | Account search, account details, suspension and reactivation. |
| `lib/src/store.dart` | Shared local marketplace, ownership checks, request state transitions, saving and data migration. |
| `lib/src/request_screens.dart` | Request creation, offers, completion, disputes and reviews. |
| `lib/src/secondary_screens.dart` | Chat, notifications, documents, profile and simulated wallet. |
| `lib/src/number_input.dart` | Arabic, Persian and Western numeric input normalization. |
| `lib/src/widgets.dart` | Reusable UI elements. |
| `lib/src/theme.dart` | Light and dark themes and page transition configuration. |
| `lib/src/motion.dart` | Three-second launch animation, page/tab transitions and reduced-motion support. |
| `lib/src/help_screen.dart` | Role-specific service guides and expandable FAQs. |
| `lib/src/request_progress.dart` | Request milestones, next-step guidance and paused/closed states. |
| `lib/src/provider_screen.dart` | Public provider statistics, categories and customer reviews. |
| `assets/fonts/` | Bundled Tajawal fonts and their SIL Open Font License. |
| `assets/demo_admin.json` | Generated local administrator seed. Not published to GitHub; created with `tool/create_demo_admin.dart`. |
| `tool/` | Local administrator setup utility. |
| `test/` | Authentication, ownership, persistence, workflow, widget and Arabic-input tests. |
| `android/` | Android application configuration and native host. |
| `ios/` | iOS application configuration and native host; requires macOS/Xcode to build. |
| `windows/`, `linux/`, `macos/` | Flutter desktop platform scaffolding; not the documented delivery target. |
| `web/` | Generated platform scaffolding; this application uses `dart:io` and is not a web deployment. |
| `docs/` | Deployment guide, this folder map and the project analysis/design report. |
| `pubspec.yaml` | Project metadata, SDK constraint, dependencies, fonts and assets. |
| `pubspec.lock` | Resolved dependency versions for repeatable application setup. |
| `analysis_options.yaml` | Dart static analysis configuration. |

## Local-only files

Build output, dependency caches, machine-specific settings, signing keys, environment files, administrator seed and local screenshots are excluded from Git. The app's runtime accounts, messages and documents are stored in the device's app-data area, not in the repository.

## Relationship to the earlier web project

The parent workspace also contains a separate Next.js project named `Trust`. That project is not required to run this Flutter application and is outside this repository's delivery scope.
