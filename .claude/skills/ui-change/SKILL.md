---
name: ui-change
description: The mockup-first workflow for any visible change to the vpn2 Flutter client — update client/design/ui-spec.html, run its geometry validator, show the user, and only then write code. Use this whenever work touches a screen, a control, a layout, an empty state, an error message or user-facing copy in client/, even when the user just says "add a button", "fix this screen" or "поменяй экран" without mentioning the mockup. Also use it when reviewing whether an existing screen matches the spec.
---

# Changing the client UI

The rule this repository runs on: **the mockup changes first, the code second.**
Not ceremony — the mockup is drawn 1:1 in Flutter logical points and carries a
validator, so a layout mistake surfaces in seconds instead of after a build, and
the user gets to redirect the design before any code exists. Skipping straight
to code reliably produces work that gets thrown away.

## The loop

1. **Edit `client/design/ui-spec.html`.** Find the section for the screen you
   are changing and add or modify a canvas there.
2. **Run the validator — it must report zero violations.** See below.
3. **Show the user.** Take a screenshot of the affected canvases and describe
   the decisions you made, especially the ones they might disagree with. Wait
   for an explicit go-ahead. "делай" is the go-ahead; silence is not.
4. **Write the code**, taking every number from `client/lib/core/theme.dart` and
   `client/lib/core/ui.dart` — the same numbers the mockup uses.
5. **Verify**: `flutter analyze` (must be clean) and `flutter test`. Add or
   update the test that pins the behaviour you just introduced.

If the change is invisible to the user — a refactor, a state fix, a rename —
none of this applies. This is about what people see.

## Running the validator

Open the spec in the browser pane and evaluate `check.js` against it:

```
mcp__Claude_Browser__preview_start   { url: "file:///<abs path>/client/design/ui-spec.html" }
mcp__Claude_Browser__javascript_tool { action: "javascript_exec",
  text: "(async () => { const src = await (await fetch('check.js')).text(); return eval(src); })()" }
```

It returns `{"violations":0,"list":[]}` when the mockup is sound. After editing
the file, re-open it with `force: true` (or `location.reload()`) — the pane
caches.

To screenshot a specific canvas, scroll it into view first; the rails scroll
horizontally, so set `rail.scrollLeft` to reach boards that are off-screen.

## What the validator actually checks

Frame overflow, row heights (56 one-line / 72 two-line / 64 rule rows), button
heights (48, and equal within a stack), inputs (56), segmented controls (40 and
full width), app bars (56 with symmetric icon insets), ring (180), FAB (56),
switch (52×32), horizontal overflow, and class-name collisions between canvas
markup and page chrome.

Two traps worth knowing before they cost you a debugging round:

- **A `.s` class anywhere inside a `.row` means "this row has a subtitle"**, so
  the checker demands 72pt. An icon written as `class="icon s muted"` inside a
  one-line row trips this. Use `xs` there instead.
- **Every canvas needs a `.cap .id`** — the validator uses it to name the
  offender in its report, and without it violations read as `(no id)`.

## Conventions the mockup encodes

- Phone frame 402×874, macOS window 700×630, content capped at 560 — all in
  logical points, displayed at 62%.
- Shared primitives already exist and should be reused rather than re-invented:
  `pickOption` (the single bottom-sheet picker for every list), `SelectField`,
  `SectionHeader`, `showToast`, `showErrorDialog`. If a new screen needs a
  chooser, it is `pickOption`.
- Sheets cap at 80% of the screen so a strip of scrim remains tappable; search
  appears in a list from six items (`kSearchThreshold`).
- New component with its own geometry → add a row to the metrics table in the
  spec, and the constant to `theme.dart` or `ui.dart`. The README in
  `client/design/` states the rule: those numbers and these numbers are the
  same numbers.
- State that the user can act on is written in words, not carried by colour
  alone. Colour is the second signal, never the only one.

## Writing the code afterwards

- Do not run `dart format` over the project; it rewrites lines your change
  never touched and buries the diff.
- Comments explain business logic or a hard-won technical decision. Never
  narrate what the code already says.
- Tests here are contracts, not coverage: name them after the behaviour
  (`test/status_strip_test.dart` → "every chip names its state, not just its
  subject"). If you find yourself weakening a test to make a change pass, the
  change is probably wrong.
- Widget tests that touch real file I/O need `tester.runAsync` rather than
  `pumpAndSettle` — see `client/test/routing_simple_test.dart` for the pattern
  that works.
