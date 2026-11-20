# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

iOS client for [ntfy](https://ntfy.sh): SwiftUI app plus a Notification Service Extension, Core Data persistence, and Firebase Cloud Messaging (FCM) delivered over APNs. Deployment target is iOS 15.0 for the app target (the project-level default is 14.0). Unit tests live in `ntfyTests/` (Swift Testing), linting is SwiftLint plus `scripts/lint.sh`, and CI is `.github/workflows/ci.yml`.

## Build and run

Open `ntfy.xcodeproj` in Xcode, or use the CLI (schemes: `ntfy`, `ntfyNSE`):

```
xcodebuild -project ntfy.xcodeproj -scheme ntfy -destination 'generic/platform=iOS' build
```

- SwiftPM dependencies (Firebase, SQLite.swift) resolve on first build and are slow.
- `ntfy/Assets/GoogleService-Info.plist` is gitignored but referenced by the project, so a clean checkout **fails to build** until it exists. Use a real file from your Firebase project for push. Otherwise run `scripts/dummy-firebase-plist.sh`, which writes a placeholder that builds and launches (Firebase rejects a malformed `API_KEY` at launch, which would crash the hosted tests).
- Building rewrites `xcschemes/ntfyNSE.xcscheme` (adds `askForAppToLaunch`). Don't commit that incidental change.
- Push registration does not work in the simulator. Test push flows on a physical device. Both entitlements files use `aps-environment = development`.
- Full push setup (APNs key, Firebase project, ntfy server built from a dev branch) is in `docs/GETTING_STARTED.md`. It is dated.

## Tests and lint

```
scripts/lint.sh   # SwiftLint + plist/JSON/XML/shell/workflow checks (brew install swiftlint shellcheck actionlint)

SIGNING="CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER="
xcodebuild test -project ntfy.xcodeproj -scheme ntfy -destination 'platform=iOS Simulator,name=iPhone 16' $SIGNING
# Single test: add -only-testing:ntfyTests/StoreTests/pollRequestPrefersRequestedBaseUrl()
```

- `ntfyTests` is **hosted** in the app (`TEST_HOST`, `@testable import ntfy`). `Config` force-reads `AppBaseURL` from `Bundle.main`, so a logic-only bundle would crash. App launch runs `FirebaseApp.configure()`, hence the dummy plist.
- Use ad-hoc signing (`$SIGNING` above), not `CODE_SIGNING_ALLOWED=NO`. Without entitlements the app group container is nil and `Store.shared` crashes.
- `Store.context` is a main-queue context. Tests that touch a `Store` are `@MainActor`. Use `Store(inMemory: true)` for isolation. Tests that need `Store.shared` (e.g. critical alerts in `NotificationContent`) must restore what they change.
- SwiftLint is lenient: existing code yields warnings only, so CI fails only on new error-level violations. Avoid reformatting upstream files; it makes `upstream` merges painful.

## Architecture

The key thing to understand is that **two processes share one data store**: the main app (`ntfy/`) and the Notification Service Extension (`ntfyNSE/`).

- Both targets compile much of the same code (`Store`, `ApiService`, `Message`, `NotificationContent`, and others). Check target membership in the Xcode project when adding a file that the NSE also needs.
- Core Data lives in the app group container (`group.io.heckel.ntfy`, `Store.appGroup`) as `ntfy.sqlite`. UserDefaults also uses that suite. The app group must stay identical in both entitlements files.
- `Store.shared` observes `NSPersistentStoreRemoteChange` so writes from the NSE refresh the app's views (`hardRefresh()`). `transactionAuthor` distinguishes `ntfy` from `ntfy.appex`.

### Notification flow

1. The ntfy server publishes to FCM topics. Topic names come from `firebaseTopic(baseUrl:topic:)` in `Helpers.swift`, and the app re-subscribes to all of them whenever an FCM token arrives (`AppDelegate.messaging(_:didReceiveRegistrationToken:)`).
2. The NSE (`NotificationService.didReceive`) parses `Message.from(userInfo:)` and branches on `event`:
   - `message`: saves to Core Data via `Store.save(notificationFromMessage:)`, then `content.modify(...)` and `attachImageIfNeeded`.
   - `poll_request`: used for self-hosted servers, which cannot send through Firebase directly. The NSE finds the matching subscription and polls the original server with `ApiService.poll`.
3. `AppDelegate.didReceiveRemoteNotification` handles the silent `~poll` topic by polling all subscriptions and creating local notifications. The local notifications must carry the same `userInfo` as remote ones so tap handling in `userNotificationCenter(didReceive:)` works for both.
4. Tapping a notification sets `AppDelegate.selectedBaseUrl` to navigate. It then runs a notification action (`ActionExecutor`) or opens the `click` URL.

`NotificationContent.swift` maps ntfy priority to `interruptionLevel`. Priority 5 becomes `.critical` only when critical alerts are enabled and authorized. Otherwise it falls back to `.timeSensitive`.

### Critical alerts

This is the in-progress area of work (see recent branch history). Two separate flags exist:
- `Store.prefKeyCriticalAlertsEnabled` is the user's in-app toggle.
- `criticalAlertsAuthorized` is the OS permission, written to shared defaults by `AppDelegate.refreshNotificationSettings` so the NSE can read it.

The `com.apple.developer.usernotifications.critical-alerts` entitlement is present in both entitlements files and requires Apple approval for the provisioning profile.

### Layout notes

- `Views/` is SwiftUI, with a UIKit controller for attachments (`NotificationAttachmentController`).
- Persistence classes (`Subscription`, `Notification`, `User`) are Core Data models. The schema is in `Persistence/ntfy.xcdatamodeld`. `shouldMigrateStoreAutomatically` and inferred mapping are on, so schema changes need a new model version.
- iOS cannot hold a background connection, so delivery relies entirely on FCM and APNs. See `docs/TECHNICAL_LIMITATIONS.md` for the rationale, and `docs/FEATURE_PARITY.md` for gaps compared with Android.

## Debugging the extension

The NSE does not log to Xcode's main console. In Xcode use Debug > Attach to Process by PID or Name, select `ntfyNSE`, and set a breakpoint.
