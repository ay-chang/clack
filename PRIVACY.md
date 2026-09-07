# Privacy

Clack is a keystroke *counter*, not a keystroke *logger*. This document
describes exactly what it does, and where in the source you can verify it.

## What is recorded

One integer per calendar day. That is the entire data model:

```json
{ "version": 1, "days": { "2026-09-06": 18432, "2026-09-07": 5120 } }
```

Stored at `~/Library/Application Support/Clack/history.json`. Nothing else is
written anywhere, except three preference booleans in `UserDefaults`
(launch at login, show count in menu bar, count held-key repeats).

## What is not recorded

- **Which key you pressed.** The key code is never read. The event object is
  consulted for exactly one field — `keyboardEventAutorepeat`, a flag saying
  whether the press came from holding a key down. See
  [`EventTap.swift`](Sources/Clack/EventTap.swift).
- **What you typed.** No text, no buffers, no clipboard.
- **Which app you were in.** No process, window, or bundle identifier.
- **When, beyond the day.** Timestamps are truncated to a calendar date.

## Network

Clack makes no network connections. There is no telemetry, no crash
reporting, no analytics, no update check. You can confirm this:

```bash
grep -rniE "URLSession|NSURLConnection|CFSocket|Network\.framework|http" Sources/
```

The only URLs in the source are the two the app can *open in your browser* when
you click a button: the Accessibility pane in System Settings, and this
repository.

## Why it needs Accessibility permission

macOS treats observing keyboard events as privileged, so counting presses
requires the app to be listed in **System Settings › Privacy & Security ›
Accessibility**. There is no narrower permission for "count but don't read".

The tap is created with `CGEventTapOptions.listenOnly`, which means the system
ignores anything the callback returns. Clack is structurally incapable of
modifying, blocking, or injecting a keystroke.

## Password fields

When any app enables macOS *secure input* — which every password field does —
the window server stops delivering key events to all event taps, Clack
included. Keystrokes typed into a password field are never seen and never
counted. The app shows "Paused — secure input active" when this is in effect.

## Verifying the binary

Accessibility permission is bound to a code signature, so releases are signed
with a Developer ID and notarized. If you would rather not trust the signed
build, `make` produces the same app from source in about a minute — see the
README.
