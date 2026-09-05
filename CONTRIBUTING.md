# Contributing to MunichWays

## Quality principles

The app should remain dependable on first installation, after an update, with
slow or unavailable networking, and on smaller or older phones. Stability,
performance, accessibility, and straightforward operation take priority over
feature scope.

Changes should be small, causal, and reversible. Extending a critical flow with
a second state machine is usually riskier than extending its existing source of
truth. New behavior must preserve established behavior unless the product
requirement explicitly replaces it.

## Branch and review workflow

1. Start from an up-to-date `master` and create a feature or bugfix branch.
2. Confirm `git status` before editing and preserve unrelated local changes.
3. Reproduce the issue or document the expected behavior.
4. Implement the smallest safe change.
5. Run the checks described below.
6. Review the full diff for unrelated files, generated artifacts, secrets, and
   unintended version changes.
7. Commit and push only when the responsible developer requests or approves it.
8. Open a pull request for review; do not develop directly on `master`.

## Debugging principles

- Capture evidence before guessing: timestamps, state transitions, durations,
  results, errors, CPU use, and memory use where relevant.
- Log boundaries of asynchronous work rather than high-frequency loops.
- Separate asset loading, parsing, cache access, network access, rendering, and
  UI state so a permanent loading indicator can be localized precisely.
- Distinguish Debug, Profile, and Release behavior. A successful debug start is
  not sufficient evidence for release startup behavior.
- Check whether framework helpers hide background isolates, retries, network
  access, caching, or expensive data copies.
- After fixing the initial failure, test that cancellation, retry, and recovery
  still work. A system that detects an error but cannot recover is still broken.
- If a proposed improvement interferes with a proven critical workflow and a
  safe integration is not evident, revert the improvement narrowly.

## Required automated checks

### Single-owner Flutter workflow

Flutter commands for this workspace run sequentially. Do not run `flutter run`,
build, analysis, and tests in parallel. In particular, an active VS Code phone
run owns the Flutter toolchain until disconnecting USB ends that run.

Use `Terminal` > `Run Task...` > `Entwicklung: Status prüfen` before changing
from device testing to automated checks. For the full local gate, disconnect
the phone and run `Qualität: Vollständige Prüfung`.

Run formatting before analysis and tests so CI results refer to the final code:

```text
dart format --output=none --set-exit-if-changed <changed Dart files>
git diff --check
flutter analyze --no-pub
flutter test --no-pub
```

During development, focused tests may be run first. Before pushing, run the
complete suite. A regression fix should include a test that fails for the
regression when this is practical without duplicating implementation details.

If a running Flutter command holds the tool lock, stop it before the final test
run. If a required check remains blocked, document that fact and do not treat it
as a pass.

## Physical-device test workflow

### Immediate test without debugger

1. Connect exactly one Android phone by USB.
2. Start VS Code `Run Without Debugging` and wait for installation and startup.
3. Test the changed behavior immediately on the phone and record the result.
4. Do not run automated Flutter checks while this session is active.

### Road test with the installed build

1. Before launching the app, run `Straßentest: Vorbereiten`. This enlarges the
   Android circular log buffer to 16 MB and clears old logs.
2. Start `Run Without Debugging`, wait for the app, and test it immediately.
3. Unplug USB. This ends the VS Code run while the installed app remains on the
   phone and can continue running.
4. Perform the road test. Do not restart the phone or reinstall the app.
5. Reconnect USB after the ride without first restarting the app.
6. Run `Straßentest: Logs einsammeln`. Main, system, crash, and Flutter logs are
   written below `.diagnostics/`, together with a memory snapshot if the app is
   still running.
7. Report the exact local time and observed behavior so the log can be matched
   to the event.

Use Profile mode for performance, startup, CPU, memory, and release-like
problems. Use Debug mode with the phone attached when breakpoints, hot reload,
or DevTools are required. The Android log buffer approach also supports a Debug
road test, but a future bounded in-app diagnostic log will be more reliable for
long rides or very noisy devices.

## Accessibility regression checklist

For changes to the map, route planning, or navigation, verify the primary flow
once with Android TalkBack enabled:

- Choose a destination, use `In der Nähe`, plan a route, start navigation,
  interrupt it by moving the map, resume it, and end it. TalkBack must announce
  the purpose of every action instead of only the icon or an unlabeled button.
- Check location, zoom, compass, information, settings, route editing, saving,
  and overflow-menu controls. Interactive targets must remain at least 48 x 48
  logical pixels even when the visible icon is smaller.
- Repeat the start window and one representative dialog at 200% system text.
  Primary actions must remain visible, readable, and tappable without layout
  overflows.
- Check important text and controls in light and dark mode. Automated widget
  tests should include Flutter's label, Android tap-target, and text-contrast
  guidelines where practical.
- Do not rely on color alone for the Radl-Komfort-Index: the route summary and
  legend provide named categories, while stressful red and black map lines use
  dashed styling in addition to color.
- Ignore automatic findings only for demonstrably decorative map content or
  map tiles. Every actually interactive map overlay needs a meaningful label.

## One-trip routing choice user story

As a rider in a hurry, I want to choose a more direct route for only the current
trip without changing my normal routing preference.

The complete expected behavior is:

- The route start window offers a compact `Direkte Route` icon between ending
  and editing the route, without increasing the panel height. Its dialog warns
  that the route can be more stressful, has no turn-by-turn announcements, and
  therefore requires watching the map. The option is hidden when shortest
  routing is already configured.
- Selecting it immediately recalculates with BRouter's `shortest` profile. The
  action then becomes `Standard`, which recalculates using the latest routing
  preference from Settings.
- The temporary choice is the single effective routing preference for every
  manual retry and automatic off-route recalculation during that trip. Editing
  the current route or its intermediate stops does not discard it.
- BRouter routes do not invent spoken maneuvers, but their geometry remains
  available for off-route detection and automatic recalculation.
- The choice is never written to Settings. Ending the route, selecting a new
  destination, or selecting another saved route clears it; the next route uses
  the configured preference again.
- While a calculation is running, both start choices are unavailable. After a
  failed direct-route calculation, `Standard` remains available so the rider
  can recover using the configured routing mode.

## Navigation guidance user story

As a rider, I want navigation guidance to recover from uncertain GPS and route
matching without unnecessary recalculations, so that deliberate safety
fallbacks remain useful and a stale fallback cannot block later directions.

The complete expected behavior is:

- Navigation start has its own 25 metre gate. While the rider is inside that
  start area, the app asks them to follow the map and neither announces an
  initial turn nor starts stalled-guidance recovery. The gate measures direct
  displacement from the start fix in any direction; riding away from the route
  therefore opens it and hands control to regular off-route detection.
- Once the start gate opens, the current maneuver is announced when voice
  guidance is enabled. Enabling voice guidance later repeats the currently
  relevant maneuver when one is available; otherwise it confirms that voice
  guidance was enabled.
- Normal route matching shows and announces approach, turn, intermediate-stop,
  and final-destination guidance once at the appropriate progress thresholds.
- A brief departure from the route marks guidance recovery as pending. Re-entry
  on any valid part of the route re-anchors maneuver progress and resumes normal
  guidance without requiring a network recalculation.
- A genuinely off-route rider is handled by the existing movement-aware flow:
  delayed visual status, delayed spoken warning, and automatic recalculation
  after 30 seconds when enabled. Stationary riders and isolated inaccurate fixes
  must not trigger this flow.
- Nearby route levels, ramps, loops, or parallel segments can make the current
  route position ambiguous. The app shows `Position unclear - watch map`,
  suppresses unsafe spoken turns, and continues conservative progress on the
  earlier continuity candidate.
- A route re-entry can also leave guidance without a current maneuver even
  though the RadlNavi route supports voice guidance. The navigation header uses
  `Follow route on map` for this missing-instruction state.
- Only a continuous ambiguous-position or missing-instruction state is
  recoverable by the stalled-guidance watchdog. It requires both 30 seconds and
  at least 25 metres of accuracy-aware confirmed movement while the rider is
  still moving. A direct transition between those two recoverable reasons is
  one continuous stall and must not restart the watchdog.
- When that watchdog opens, guidance first re-anchors locally at the current
  position. If this produces a concrete maneuver, no route request is made. A
  missing instruction alone never causes a network request because it can be
  legitimate on the final straight. Only if the position remains explicitly
  ambiguous does the app use the existing automatic route recalculation flow
  when that setting is enabled.
- A known overlapping outbound/return section deliberately shows `Watch the
  map` as `Outbound/return overlap - watch map` while route progress continues.
  It never starts stalled-guidance recovery or a recalculation merely because
  the overlap lasts longer than 30 seconds.
- An unsupported guidance route, interrupted map tracking, and the
  navigation-start fallback are separate map-only states. They never start
  stalled-guidance recovery based on their displayed text.
- A failed recalculation reports the failure and leaves manual recalculation
  available. Automatic recalculation retains the maximum of three consecutive
  attempts. Manual recalculation resumes suspended automation; confirmed
  on-route travel resets the attempt count.
- Voice guidance and automatic recalculation remain independent settings.
  Disabling automatic recalculation still permits local guidance re-anchoring,
  but it prevents the stalled-guidance watchdog from making a network route
  request.
- Ending navigation, selecting a new destination, receiving a replacement
  route, or starting navigation again resets pending stalled-guidance recovery
  along with the other navigation timers and speech state.

## Regression checklist

Select all scenarios relevant to the changed flow. Critical startup or map
changes should cover most of the first group.

### Startup and data

- first installation and first launch
- first launch after an update
- warm restart and cold restart
- empty, valid, stale, and corrupt cache
- slow, unavailable, and restored network
- bundled fallback before optional web data
- light and dark mode
- backgrounding and resuming the app
- smaller or older Android hardware where available
- loading states always terminate or offer a useful retry

### Navigation and routing

- navigation start while stationary
- normal forward travel on the route
- short and sustained route departure
- off-route warning and spoken warning
- automatic recalculation and failed recalculation
- return to the original or recalculated route
- guidance resumes after recovery
- inaccurate fixes and implausible GPS jumps
- intermediate destinations and overlapping out-and-back segments
- voice guidance and automatic recalculation independently enabled or disabled
- ending navigation cancels pending timers and speech

### User experience and performance

- no new startup delay, frame stalls, excessive CPU use, or memory growth
- no bright-map flash or theme regression in dark mode
- controls remain usable on small screens and with accessibility text sizes
- background work does not block local content or primary interaction
- errors are concise, actionable, and do not remain after recovery

## Completion notes

Summarize the observed cause, the chosen fix, affected critical paths, checks
performed, device/manual verification, and any residual uncertainty. State
clearly whether the work is uncommitted, committed, or pushed.
