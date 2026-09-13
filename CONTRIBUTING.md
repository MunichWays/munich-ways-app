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

- Route selection lives in the planner, with two full-width cards: selection and
  title, comfort value and information action, distribution bar, distance and
  duration. The direct card uses smaller regular text and a flatter bar. Standard
  places its title and index close together. No duplicate comfort card is shown.
- The direct variant's comfort information links to the unchanged direct-route
  explanation. This dialog only closes; it never selects or calculates a route.
  The start window no longer has a separate direct-route icon.
- RadlNavi calculates the direct route using its separate discovered API and
  the same maneuver parser, navigation and voice guidance as the standard route.
  The persisted shortest preference also uses this service. Other configured
  BRouter profiles remain available.
- Display the requested route first. Discovery, the alternative route and both
  comfort analyses must not delay its availability. The planner compares distance,
  duration and comfort for the configured and direct routes before navigation.
  Each variant has its own rating distribution bar, including when coverage is
  insufficient for an index. Standard routing retains a 20-second timeout;
  isolated direct routing has 45 seconds and optional comfort analysis 60 seconds
  to tolerate startup delays without blocking the standard route.
  Before navigation, switching a ready alternative does not recalculate it.
  During navigation, both radio controls remain available: switching calculates
  from current GPS and remaining stops, retaining the active route until success.
  A failure or cancelled switch preserves the route and its pending comfort data.
- A pending or failed alternative must preserve the currently usable route.
  Selecting the current variant again cancels a pending switch. Retrying an
  unavailable alternative must recover without resetting the current route.
- Each plan generation owns its variant routes and pending analyses. Refreshing,
  editing or ending a plan invalidates older results. Late comfort updates may
  update an inactive cached variant, but never replace the active geometry or
  emit a navigation route event.
- Comfort requests retain individual legs, repeated nodes, edge distances and
  snapped endpoints, and use the producing API URL and routing variant.
  Insufficient coverage is a valid result; comfort errors permit independent retry.
  Below 70 percent coverage show `Radl-Komfort -`, with the coverage percentage
  separately in small text. The information sheet shows coverage in small regular
  text, followed by `Radl-Komfort x/100` (or `-` when no index is available).
- The temporary choice applies to manual retry and automatic rerouting, including
  remaining intermediate stops. Refresh calculates the active variant first and
  then refreshes the alternative using the same new start and stops.
- Outside RadlNavi coverage, on unavailable discovery and on routing errors,
  preserve BRouter fallback. Direct uses its shortest profile and is identified
  as BRouter without voice guidance. Never substitute standard as direct.
- The choice is never written to Settings. Ending the route, selecting a new
  destination or selecting another saved route clears it.

## Route panel and planner layout

- The bottom route panel uses compact spacing and respects the system bottom
  inset. Dragging the grey grip down leaves only Start before navigation, or the
  bottom action row during navigation. Dragging up restores details.
- Folding is presentation state only. Comfort updates and navigation rerouting
  retain it, as does starting navigation. A new destination resets it; loading
  before navigation is always visible. Speech and tracking continue while folded.
- Expanding the home destination sheet does not focus search automatically.
  The keyboard appears only after tapping the actual text input.
- The planner keeps its header and Calculate button outside the scrollable content.
  Long plans scroll to the bottom on opening and after adding a stop, while Calculate
  remains visible at every scroll position.
- During navigation, recalculating an unedited plan uses current waypoint progress
  rather than restoring stops from the planner's opening snapshot.

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
- Off-route, ambiguous-position and missing-instruction states share one
  unresolved-guidance watchdog, independent of the displayed wording or any
  temporary rerouting label. It requires 30 seconds of movement-associated
  reliable GPS updates and at least 25 metres of confirmed movement. Switching
  between these reasons does not reset the budget. Stops and GPS outages pause
  it; a concrete instruction or verified healthy map-only progress ends it.
- Off-route detection and the watchdog use one accuracy-aware movement source.
  A gap longer than 20 seconds, inaccurate GPS or a displacement over 200 metres
  establishes a fresh anchor without counting the gap/jump as ridden distance.
  Subsequent plausible movement must be recognized again. Replayed GPS fixes
  never count twice. Moving state expires after 8 seconds without confirmed
  movement; automatic requests also require a GPS fix no older than 15 seconds.
- When that watchdog opens, guidance first re-anchors locally at the current
  position. If guidance becomes usable, announce the relevant maneuver and do
  not request a route. If re-anchoring fails or guidance remains unusable, use
  automatic recalculation when enabled, including missing-instruction states.
  Show recalculation on screen without an additional spoken announcement.
  Preserve the existing short route-left warnings; resumed regular guidance
  makes recovery audible without an extra success/status message.
  Prefer an occasional extra request over indefinitely silent broken guidance.
- A correctly matched final straight after the last maneuver needs no invented
  turn and is not a stall. Silence alone never triggers a recalculation. The
  separate missing-GPS warning still detects loss of usable location updates;
  the watchdog covers unusable guidance even while GPS continues arriving.
- A known overlapping outbound/return section deliberately shows `Watch the
  map` as `Outbound/return overlap - watch map` while route progress continues.
  It never starts stalled-guidance recovery or a recalculation merely because
  the overlap lasts longer than 30 seconds.
- An unsupported guidance route, interrupted map tracking, and the
  navigation-start fallback are separate map-only states. They never start
  stalled-guidance recovery based on their displayed text.
- A failed recalculation reports the failure and leaves manual recalculation
  available. It schedules a retry no earlier than 30 seconds later, requiring
  fresh GPS and movement. A committed off-route timer that expires during a
  stop/outage resumes when confirmed movement returns. Only one automatic
  request may be in flight. Ending navigation or a new manual plan invalidates
  old results; GPS lookup errors/timeouts must finish rather than lock loading.
  Automatic recalculation retains the maximum of three consecutive attempts.
  Failure and suspended automation are announced when speech is
  enabled, including routes without turn guidance. A replacement route without
  turn guidance explicitly announces that limitation instead of silently falling
  back to map-only navigation. Manual recalculation resumes
  suspended automation; confirmed healthy on-route travel resets the count.
- Voice guidance and automatic recalculation remain independent settings.
  Disabling automatic recalculation still permits local guidance re-anchoring,
  but it prevents the stalled-guidance watchdog from making a network route
  request.
- Ending navigation, selecting a new destination, receiving a replacement
  route, or starting navigation again resets pending stalled-guidance recovery
  along with the other navigation timers and speech state.

## Regression checklist

Road-test reference: riding through the Laimer Unterführung at Wotanstraße
successfully produced the missing-guidance/GPS warning, then recalculated and
resumed spoken directions after the tunnel. The rider observed recovery near
the junction roughly 150 metres away; retain this timing observation for a
future log comparison. Removing the extra recalculation announcement does not
change recovery thresholds or the three short route-left announcements observed
when riding in the opposite direction.

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
- GPS outage with more than 200 metres displacement, followed by valid riding
- stop/resume and off-route/ambiguous/missing changes during one unresolved stall
- expired rerouting timers, GPS lookup errors/timeouts, failed request and retry
- local recovery restores an announced maneuver; unresolved recovery recalculates
- legitimate final straight and known overlapping sections do not loop rerouting
- failure/suspended-automation warnings are audible, not only visible
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
