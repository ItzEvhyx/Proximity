# Proximity alarm persistence and full-screen delivery

## Goal

An active Proximity trip must continue to monitor distance after the UI has
left the foreground. When the user enters the configured alert zone, Android
must surface an alarm-class experience rather than a normal in-app message.
The alarm uses the snooze challenge selected in **Settings → Dismiss method**:

- `slide` renders **Slide to snooze**;
- `shake` renders **Shake to snooze**;
- `solve` renders **Solve to snooze**.

Completing the selected challenge snoozes for five minutes. It does not stop
the trip: location tracking remains active and can alert again if the user is
still in the alert zone.

## Behaviour implemented

1. `ProximityForegroundService` persists the active destination, outermost
   alert-zone radius, alarm state, and snooze expiry with
   `flutter_foreground_task` storage.
2. Its independent background isolate reads the device location every 15
   seconds. On entering the alert zone it writes a pending alarm payload before
   reopening the app, so a cold UI isolate can recover the exact event.
3. `HomeScreen` consumes pending foreground-task or native alarm payloads and
   opens `AlarmDismissalScreen`. Duplicate events are ignored while an alarm is
   visible.
4. `MainActivity` posts a high-importance Android notification with
   `CATEGORY_ALARM`, public lock-screen visibility, vibration/alarm audio, and
   a full-screen intent. It also wakes the screen and keeps the activity on
   while the alarm is active.
5. Completing the chosen snooze challenge stops audio/vibration, clears the
   native alarm notification, clears wake flags, and persists a five-minute
   snooze. Stopping or clearing a trip removes all persisted tracking/alarm
   data and stops the foreground service.

## Android contract and limits

The manifest declares `POST_NOTIFICATIONS`, `WAKE_LOCK`, and
`USE_FULL_SCREEN_INTENT`. The full-screen intent must be used only for an
active, user-configured proximity alarm. Android 14+ can revoke that access;
without it Android may show a high-priority heads-up notification instead.
When tracking is enabled, Proximity checks this access and opens Android's
per-app full-screen-intent settings only when it has been denied.

On a normal personal Android device, Proximity can show over the lock screen,
wake the display, prevent Back navigation inside its alarm screen, and keep a
persistent alarm notification. It cannot prevent Home, Recents, Settings,
power controls, or bypass a secure lock screen. True no-exit behaviour needs a
dedicated, device-owner-managed Android device using Lock Task mode; it is not
enabled by this consumer app.

## Lifecycle matrix

| State when the zone is reached | Result |
| --- | --- |
| App open | Native alarm notification is posted and the selected snooze screen opens immediately. |
| App backgrounded | The foreground service persists the event, wakes/reopens the app, then restores the snooze screen. |
| App removed from Recents | The `stopWithTask=false` foreground service persists and raises the pending event; the restored UI consumes it. |
| Screen locked | Android's alarm full-screen intent can launch the activity over the lock screen when permission/policy permits. |
| User snoozes | Alarm stops for five minutes; tracking continues. |
| User stops tracking | Service, pending alarm data, and notifications are cleared. |
| Force-stopped by the user/system | Android does not permit an ordinary app to restart itself until the user opens it again. |

## Validation checklist

- Grant notifications and full-screen-intent access, enable a destination, then
  test with screen on, locked, backgrounded, and removed from Recents.
- Test each configured snooze method and verify it is the only challenge shown
  on the alarm screen.
- Confirm a snooze does not stop tracking and that a second alarm may be raised
  after five minutes when still within the configured outer alert zone.
- Test Android 13–15 separately, including denied notification/full-screen
  intent permissions and battery optimization enabled/disabled.
- Re-test after a real release signing build; force-stop is an intentional
  platform boundary, not a recoverable background state.
