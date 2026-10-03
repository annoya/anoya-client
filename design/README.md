# Client UI spec

`ui-spec.html` — every screen of the app, drawn 1:1 in Flutter logical points
(phone 402×874, macOS window 700×630, content capped at 560). It opens in a
browser as a plain file; the theme switch in the header changes the mockup's
theme, not the system's.

The numbers in the mockup and in the code are the same numbers: the "Metrics"
section matches `lib/core/theme.dart` and `lib/core/ui.dart`. Change one, update
the other.

`check.js` — the geometry validator: it checks the heights of rows, buttons and
app bars, anything sticking out of the phone frame, and class-name collisions.
Run it in the browser console on the open page; it returns the list of
violations, which must be empty before mockup changes are handed in.
