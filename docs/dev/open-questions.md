# Open questions

Claims in these docs that aren't verified against code, docs or a real test yet. Each one says how to settle it.
When it's answered, fill in **Answer**, set status to ✅ (confirmed) or ❌ (wrong), and fix the doc that cites it.

**Status:** ❓ open · ✅ confirmed · ❌ wrong
**Owner:** `local` = we test it on the Mac/phone · `phil` = ask Phil · `research` = docs/web

| ID | Question | Status | Owner |
|---|---|---|---|
| Q1 | Does iOS throttle or drop silent (background) pushes? | ❓ | local + research |
| Q2 | Can FCM drop a device's topic membership on its own? | ❓ | research |
| Q3 | Does `didReceiveRegistrationToken` fire on every launch, or only on token change? (PR #53's premise) | ❓ | local |
| Q4 | Can the simulator get real APNs pushes without a paid Apple team? | ❓ | local |
| Q5 | Is FCM missing from the Firebase Local Emulator Suite? | ❓ | research |
| Q6 | Do `simctl push` alert payloads run the NSE? | ❓ | local |
| Q7 | Can Phil add you to his Apple team at no extra cost? | ❓ | phil |
| Q8 | Can integration tests run an ntfy server on GitHub's macOS runners (no Docker)? | ❓ | local |
| Q9 | CI vs. the missing `GoogleService-Info.plist`: placeholder, or skip Firebase under test? | ✅ | local |
| Q10 | Why was the Markdown PR (#47) closed unmerged? | ❓ | phil |
| Q11 | Is FCM free at any volume? | ❓ | research |
| Q12 | Exactly what can a free (personal) Apple team sign: push? App Groups? | ❓ | local |
| Q13 | Does PR #53's reconcile run when the app is only woken in the background? | ❓ | local |
| Q14 | Who besides Phil is working on what (critical alerts, display names, UI modernize)? | ❓ | phil |
| Q15 | What is the real deployment target: iOS 14/15 (project file), 16+ (roadmap) or 17 (PR #36)? | ❓ | local + phil |
| Q16 | Did the community rewrite (`dehlen/ntfy-ios`, now gone) go anywhere? | ❓ | phil |
| Q17 | Will Phil take PRs for items his roadmap lists as out of scope (#57 sounds, #51 deep links, #58 icons)? | ❓ | phil |

---

### Q1 — iOS and silent pushes
**Claim:** iOS throttles or drops `content-available` pushes freely, so `message_delete` and `~poll` keepalives
are best-effort. Cited in [architecture.md §4](architecture.md#4-silent-pushes-no-banner-no-nse).
**Why it matters:** decides whether delete/clear can ever be reliable via push, or must come from polling.
**Validate:** Apple's "Pushing background updates" docs (they recommend ≤2–3/hour). Locally: send a silent push
and watch `didReceiveRemoteNotification` with the app in foreground, background, and force-quit.
**Answer:** —

### Q2 — FCM losing topic membership
**Claim:** FCM might drop a token's topic subscriptions on its side. Candidate cause 3 for #1305.
**Validate:** FCM docs on topic subscription lifetime and stale tokens (I recall ~270 days of inactivity), and
issue/PR #53 discussion.
**Answer:** —

### Q3 — when the token callback fires
**Claim (PR #53):** `messaging(_:didReceiveRegistrationToken:)` doesn't fire reliably, so topics never get
re-subscribed.
**Why it matters:** if it fires every launch, today's code already re-subscribes on launch, and the bug is more
likely in failed subscribes that are never retried (Q13, debugging.md).
**Validate:** breakpoint/log in the callback; cold launch, warm launch, background wake, after reinstall. Note
which ones fire.
**Answer:** —

### Q4 — real pushes in the simulator
**Claim:** works on Xcode 14+ / Apple Silicon, but needs a push-enabled signing profile → paid team.
**Validate:** try it with the free personal team. If Xcode refuses the Push Notifications capability, confirmed.
**Answer:** —

### Q5 — Firebase emulator and FCM
**Claim:** the Local Emulator Suite covers Firestore/Auth/Functions, not messaging.
**Validate:** firebase.google.com/docs/emulator-suite. List of emulated products.
**Answer:** —

### Q6 — do fake pushes run the NSE?
**Why it matters:** if yes, most NSE work (#1945 display side, poll_request handling, attachments) needs no device.
**Validate:** [simulating.md](simulating.md#fake-pushes-with-simctl-push). Attach to `ntfyNSE`, push
`message.apns`, see if a breakpoint in `didReceive` hits.
**Answer:** —

### Q7 — joining Phil's Apple team
**Claim:** adding a member to an organization developer account generally costs nothing extra.
**Validate:** ask Phil whether his account is organization or individual. Individual accounts can't add members.
**Answer:** —

### Q8 — integration tests in CI
**Claim:** GitHub's macOS runners have no Docker.
**Validate:** check runner image docs. Then try `go install heckel.io/ntfy/v2@latest` or a release binary in a
workflow and start `ntfy serve` on the runner.
**Answer:** —

### Q9 — Firebase config in CI
`AppDelegate` calls `FirebaseApp.configure()` at launch; with no plist the app crashes.
**Options:** generate a dummy plist in the workflow; or skip `configure()` when running under tests.
**Validate:** Phil's preference, then try the dummy plist locally first.
**Answer (2026-11-20):** placeholder works. `scripts/dummy-firebase-plist.sh` on branch `ci/lint-and-tests` writes a
dummy plist; CI on macos-26 builds, launches the test host and passes 31 tests. Firebase only checks the API key is
39 characters starting with "A". Don't start it with `AIza`: GitHub secret scanning flags that as a leaked Google
key. Still worth confirming Phil is happy with the approach when the PR goes up.

### Q10 — Markdown PR #47
Closed with no comments. Design disagreement, abandoned, or superseded? Affects any new Markdown work (#1072).
**Answer:** —

### Q11 — FCM cost
**Claim:** FCM has no usage charges on either Firebase plan; limits are rate limits (ntfy logs
`Firebase quota exceeded`).
**Validate:** firebase.google.com/pricing.
**Answer:** —

### Q12 — free Apple account limits
**Claim:** free personal teams can't use Push Notifications; App Groups may also be blocked. Apps installed with
a free team expire after 7 days.
**Validate:** switch both targets to your personal team in Xcode and read the capability errors.
**Answer:** —

### Q13 — reconcile on background wake
PR #53 reconciles on launch and `didBecomeActive`. If the app is only ever woken in the background (by the NSE or
silent pushes), does reconcile run? Also: is a failed subscribe retried?
**Validate:** while reviewing/testing PR #53.
**Answer:** —

### Q14 — who's doing what
Open PRs from several contributors overlap our task list. Avoid duplicate work.
**Validate:** ask Phil in Discord before starting display names, Markdown, critical alerts, or a UI refresh.
**Answer:** —

### Q15 — deployment target
Roadmap #1680 says "iOS 16+, remove `if #available(iOS 15, *)` guards". PR #36 "Bump to iOS 17" merged in April 2026.
But `project.pbxproj` on `main` still has `IPHONEOS_DEPLOYMENT_TARGET = 14.0` (2 configs) and `15.0` (6 configs).
**Validate:** check target-level vs project-level settings in Xcode and what #36 actually changed; ask Phil which
minimum he wants. A clean-up PR (one target value plus removing dead availability checks) is small and on his list.
**Answer:** —

### Q16 — community rewrite
Roadmap lists `github.com/dehlen/ntfy-ios` (started January 2026) as a data source. As of 2026-11-21 it returns 404:
deleted or private. Matters before designing a reskin or larger refactor.
**Answer:** —

### Q17 — out-of-scope PRs
Roadmap "Out of Scope": Apple Watch (#1546), custom sounds (#546), `ntfy://` deep links (#450), share extension,
self-signed certs (#1439), notification icons (#507), MDM profiles (#477), editing notifications.
Open PRs that implement some of these: #57 (sounds), #51 (deep links), #58 (icons + Live Activities).
**Validate:** ask during PR triage. Either Phil changes scope or they get a polite close.
**Answer:** —
