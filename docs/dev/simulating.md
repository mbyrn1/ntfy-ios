# Simulating and testing without (or before) real pushes

Companion to [architecture.md](architecture.md). Same source tags.

## What you can test, and what it costs

| Goal | Cost | How |
|---|---|---|
| App/NSE handling of each push type | free | `simctl push` fake payloads (below) |
| Token-rotation / re-subscribe logic (#1305) | free | unit tests with FCM behind a protocol + a fake |
| Polling and fetch-by-ID against a real server | free | simulator app + your own ntfy server |
| Real end-to-end delivery FCM → APNs → phone | **paid Apple team** | Phil adds you to his team, or your own $99/yr account + your own Firebase |
| Simulator receiving *real* APNs pushes (Xcode 14+, Apple Silicon) | **paid Apple team** | still needs a push-enabled signing profile ([Q4](open-questions.md#q4--real-pushes-in-the-simulator)) |

Firebase is free at any volume, including FCM ([Q11](open-questions.md#q11--fcm-cost)). The Firebase Local Emulator Suite does **not** emulate FCM
([Q5](open-questions.md#q5--firebase-emulator-and-fcm)), so it doesn't help here.

## Fake pushes with `simctl push`

`xcrun simctl push` hands a payload straight to the simulator, skipping FCM and APNs. It tests what the app
does with a push, not whether pushes arrive.

The app parses ntfy fields from the **top level** of the payload (FCM puts its `data` map there). Required:
`id`, `time` (string, unix seconds), `event`, `topic` [ios:Persistence/Notification.swift:416]. The NSE only saves
a message if you're **subscribed** to that topic on that base URL, so subscribe in the app first. If `base_url` is
absent, the app assumes its home server `https://ntfy.sh` [ios:NotificationService.swift:37].

Keep these in `payloads/` in your working copy, not in the ntfy-ios repo.

**message** (alert, goes to the NSE):
```json
{
  "Simulator Target Bundle": "io.heckel.ntfy",
  "aps": { "alert": { "title": "Test", "body": "hello from simctl" }, "mutable-content": 1 },
  "id": "sim0001", "time": "1795000000", "event": "message", "topic": "mytopic",
  "title": "Test", "message": "hello from simctl", "priority": "4", "tags": "warning,skull"
}
```

**poll_request** (alert; the NSE then fetches from `base_url` by `poll_id`):
```json
{
  "Simulator Target Bundle": "io.heckel.ntfy",
  "aps": { "alert": { "body": "New message" }, "mutable-content": 1 },
  "id": "sim0002", "time": "1795000000", "event": "poll_request",
  "topic": "<sha256 of https://your-server/mytopic>", "message": "New message",
  "poll_id": "<real message id on your server>", "base_url": "http://<your-server>:<port>"
}
```

**message_delete** (silent: no NSE, goes to `didReceiveRemoteNotification`):
```json
{
  "Simulator Target Bundle": "io.heckel.ntfy",
  "aps": { "content-available": 1 },
  "id": "sim0003", "time": "1795000000", "event": "message_delete", "topic": "mytopic", "sequence_id": "<id>"
}
```

Send:
```bash
xcrun simctl list devices booted            # get the device, or just use "booted"
xcrun simctl push booted io.heckel.ntfy payloads/message.apns
```
Or drag the `.apns` file onto the simulator window.

**Check first:** whether simulated *alert* pushes run the NSE in your Xcode version ([Q6](open-questions.md#q6--do-fake-pushes-run-the-nse)). Attach to
`ntfyNSE` (see [debugging.md](debugging.md)), send `message.apns`, and see if the breakpoint hits. That decides how
much NSE work you can do without a device.

Get a topic hash for `poll_request` tests:
```bash
printf '%s' "http://<your-server>:<port>/mytopic" | shasum -a 256 | cut -d' ' -f1
```
It must match the app's normalized base URL exactly: scheme, host and port, no trailing slash [ios:Helpers.swift:16].

## Your own ntfy server

Docker on any Linux box or the Mac ( whether CI can run a server is [Q8](open-questions.md#q8--integration-tests-in-ci)):

```bash
docker run -d --name ntfy-dev -p 8095:80 \
  -v ~/ntfy-dev/etc:/etc/ntfy -v ~/ntfy-dev/cache:/var/cache/ntfy \
  binwiederhier/ntfy serve
```

`~/ntfy-dev/etc/server.yml`, starting point:
```yaml
base-url: "http://<your-server>:8095"
log-level: debug
# Option A (no Firebase): polling only. App fetches on open/refresh; use simctl poll_request to fake pushes.
# Option B (your own Firebase, needs a paid Apple team): send to FCM yourself
# firebase-key-file: /etc/ntfy/firebase-service-account.json
# Do NOT set upstream-base-url here. That relays to ntfy.sh for Phil's official app.
```

Publish: `curl -d "hi" http://<your-server>:8095/mytopic`

## Your own Firebase project (option B)

Only worth it with a paid Apple team. It gives you a sandbox where you control the server, FCM and app, which is
ideal for reproducing #1305.

1. **Apple** (paid): create an APNs auth key (`.p8`), and register your own App IDs
   (e.g. `io.example.ntfy`, `io.example.ntfy.ntfyNSE`) with Push Notifications, plus your own App Group.
   `io.heckel.ntfy` belongs to Phil's team.
2. **Firebase** (free): new project → add iOS app with your bundle ID → upload the `.p8` under Cloud Messaging
   → download `GoogleService-Info.plist` → Project settings → Service accounts → generate a private key for the
   server (`firebase-key-file`).
3. **Local app overrides**, never committed: team, bundle IDs, App Group, the plist, and
   `APP_BASE_URL` = `http://<your-server>:8095`. `APP_BASE_URL` makes your server the app's home server, so
   messages arrive with full content under plain topic names, like ntfy.sh [ios:Helpers.swift:22],
   [ios:Utils/Config.swift]. Put the overrides in a git-ignored `.xcconfig` (or keep a stash) so they never end
   up in a PR.
4. Build to your iPhone, subscribe, `curl -d hi …/mytopic`.

Your phone only gets messages over the home network unless the server is reachable from outside.

## Unit-testing the subscription logic (free)

The re-subscribe logic in `AppDelegate` calls `Messaging.messaging()` directly, which makes it untestable.
Smallest seam:

```swift
protocol TopicSubscriber {
    func subscribe(toTopic topic: String, completion: @escaping (Error?) -> Void)
    func unsubscribe(fromTopic topic: String, completion: @escaping (Error?) -> Void)
}
extension Messaging: TopicSubscriber { /* forwards to the real methods */ }
```

Then test with a fake that records calls and can fail on demand:
- token received → subscribes `~poll` + every saved subscription with the right names (plain vs hash)
- a subscribe fails → retried later (today: it isn't)
- subscription deleted → unsubscribed

This is the part of the test/CI work that pays off directly for #1305 / PR #53. Agree the seam with
Phil before refactoring `AppDelegate`, since PR #53 touches the same code.
