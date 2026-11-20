# TODO

Engineering infrastructure the repo lacks today. There are no test targets, no linter config and no CI.

## 1. Tests

- [x] Add a unit test target (`ntfyTests`) and share it in the `ntfy` scheme so `xcodebuild test` works.
- [x] Use `Store(inMemory: true)` for Core Data tests. The initializer already supports it.
- [x] First targets, since they are pure logic:
  - [x] `Message.from(userInfo:)` parsing (payload shapes for `message` and `poll_request`)
  - [x] `NotificationContent.modify` priority to `interruptionLevel` mapping, including critical alerts enabled and authorized versus not
  - [x] `firebaseTopic(baseUrl:topic:)` and `topicUrl` in `Helpers.swift`
  - [x] `Store` save, dedupe and `findSubscriptionMatch(forPollRequestTopic:preferredBaseUrl:)`
- [ ] Decide how to cover `ApiService` (stub `URLSession` via `URLProtocol`).
- [x] Document the single-test command in `CLAUDE.md` once it exists, e.g. `xcodebuild test -scheme ntfy -only-testing:ntfyTests/SomeTests/testFoo`.
- [x] Check that the NSE-shared files compile under the test target. `Store.swift` and `AttachmentFileStore.swift` are in both app targets.

## 2. Linting and formatting

- [x] Add SwiftLint (`.swiftlint.yml`), starting with a lenient config and a baseline so existing code doesn't block adoption.
- [ ] Decide on swift-format or SwiftFormat for formatting (pick one).
- [ ] Optionally add an Xcode build phase or a pre-commit hook.
- [x] Add lint and format commands to `CLAUDE.md`.

## 3. CI/CD

- [x] GitHub Actions workflow on PR and push to `main`, on a macOS runner:
  - [x] Cache SwiftPM (Firebase resolution is slow)
  - [x] Supply a dummy `GoogleService-Info.plist` (gitignored) so the build succeeds
  - [x] Build the app and NSE (the `ntfy` scheme embeds `ntfyNSE`), ad-hoc signed for the simulator
  - [x] Run tests on a simulator destination
  - [x] Run lint
- [ ] Pin the Xcode version on the runner. CI uses the `macos-26` default (Xcode 26.x); local dev is Xcode 27.
- [ ] CD (later): TestFlight upload via fastlane or `xcodebuild -exportArchive`. This needs signing certificates, an App Store Connect API key and the APNs and critical-alerts provisioning profile as secrets.

## 4. Housekeeping

- [ ] Remove the committed `ntfy.xcodeproj/xcuserdata/pheckel.xcuserdatad/` (it is already gitignored but still tracked).
- [ ] Refresh `docs/GETTING_STARTED.md` (Xcode 13.2 and Monterey are dated).
- [ ] Keep `CLAUDE.md` in sync as the items above land.
