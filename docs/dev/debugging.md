# Debugging ntfy iOS

Companion to [architecture.md](architecture.md). Same source tags. Verified against the code 2026-11-20.

## Two processes, two debuggers

The app (`ntfy`) and the Notification Service Extension (`ntfyNSE`) are **separate processes**. Breakpoints in
NSE code do nothing while Xcode is attached to the app.

- **Debug the app:** run the `ntfy` scheme as normal.
- **Debug the NSE:** run the `ntfyNSE` scheme and choose `ntfy` when Xcode asks which app to run. Or, with the
  app running: **Debug → Attach to Process by PID or Name… → `ntfyNSE`**, then send a push. The NSE only exists
  for a few seconds after an alert push arrives, so attach first and then trigger.
- Silent pushes (`message_delete`, keepalives) never touch the NSE — debug them in the app's
  `didReceiveRemoteNotification` [ios:AppDelegate.swift:97].

## Logs: the app only prints

`Log.d/i/w/e` call Swift `print()` [ios:Utils/Log.swift]. So:

- You **only** see logs in Xcode's console while attached to that process.
- **Console.app shows nothing** from ntfy, and there's no way to get logs off a user's phone. Users reporting
  "notifications stopped" can't send anything useful.
- The NSE's logs are only visible while attached to `ntfyNSE`.

To see device logs without Xcode: there aren't any. Attach Xcode.

## Server-side visibility

On your own ntfy server (`server.yml`):

```yaml
log-level: trace          # trace logs the full FCM message it sends [srv:server_firebase.go:57]
# or narrower, while debugging:
log-level-overrides:
  - "tag=firebase -> trace"
```

Useful lines to grep for: `Publishing to Firebase`, `Unable to publish to Firebase`,
`Firebase quota exceeded` (the visitor gets temporarily banned from FCM [srv:server_firebase.go:60-66]), and
`Publishing poll request to` / `Unable to publish poll request` for the upstream relay [srv:server.go:1355-1385].
A 429 from upstream means ntfy.sh is rate-limiting your relay. Set `upstream-access-token`.

## Bug leads

### #1305 — notifications silently stop (Phil's #1)
- Whether that callback fires every launch is [Q3](open-questions.md#q3--when-the-token-callback-fires).
- Today: topics are only (re)subscribed in `messaging(_:didReceiveRegistrationToken:)`
  [ios:AppDelegate.swift:241]. Each `subscribe(toTopic:)` error is **logged and dropped** — no retry
  [ios:AppDelegate.swift:249-270].
- The server's `~poll` keepalive fallback is disabled [srv:server.go:2270], so nothing self-heals.
- PR [#53](https://github.com/binwiederhier/ntfy-ios/pull/53) adds a reconcile on launch/activation plus a
  tracked topic set. When testing it, check: is a failed subscribe retried? Does reconcile run when the app is
  only woken in the background? ([Q10](open-questions.md#q10--reconcile-on-background-wake))
- Repro ideas: subscribe, then delete and reinstall the app (new token); toggle airplane mode during launch;
  restore from backup. Watch for `Firebase subscribe failed` in the console.
- Hard to prove fixed on one device. A debug screen showing the current FCM token and last successful subscribe
  time per topic would help.

### #1945 — `message_delete` shows as a blank row
- Server sends `message_delete`/`message_clear` as **silent** pushes [srv:server_firebase.go:147].
- The app's silent-push handler returns early for any topic except `~poll` [ios:AppDelegate.swift:100-104] →
  event ignored.
- The NSE's `default:` branch also just passes content through [ios:NotificationService.swift:39].
- Then polling (`SubscriptionManager.poll` / `ApiService`) fetches the event and stores it like a message →
  blank row. Fix in the poll/save path: skip non-`message` events, and apply delete/clear to the target
  (`sequence_id`). Good first unit-test target.

### iOS 26 no sound (#1562)
Real device only, iOS 26, with Xcode 26. Note PR #57 also changes sound handling — check overlap first.

## Checklist when a push "doesn't arrive"

1. Server log: was it sent to FCM / relayed upstream? Any 429 or quota ban?
2. Right FCM topic? Plain name for the home server, `sha256(baseURL/topic)` for others [ios:Helpers.swift:22].
3. Payload over 4 KB? APNs drops it silently [srv:server_firebase.go:282].
4. Alert or silent? Silent pushes are throttled by iOS and skip the NSE.
5. App side: attach to `ntfyNSE` and look for `Message cannot be parsed`, `Subscription … unknown`, or the
   time running out (`delivering best attempt content`) [ios:NotificationService.swift].
6. Token state: was `Firebase subscribe succeeded` logged after the last token change?
