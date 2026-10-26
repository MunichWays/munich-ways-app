# Contributing to MunichWays

## Speech input foundation (issue #137)

`SpeechInputController` is provided lazily at app scope. The home destination
panel and separate place search sheet offer microphone buttons. Navigation
commands remain a later increment. Startup never initializes the recognizer
or requests microphone permission.

Voice commands for navigation (#239) are deferred pending a viable voice
activation approach. A microphone tap before each command was rejected as
insufficiently useful. See the [analysis and decision](docs/analysis/239-sprachsteuerung-hauptfunktionen.md).

The microphone dialog calls `start(localeId: ...)` and awaits one recognized
text (or null on cancellation/error). During recording, `partialText` is
preview-only; do not submit it to search. A final result takes precedence.
If recognition ends with `done` or `noMatch` after recognizing text, the
controller waits briefly for a final correction, then retains the text.
The device adapter ignores Android `error_client` only after native `done`
with nonempty recognized text: a redundant stop can report this error after
recognition ended. The final-result grace period continues unchanged. Earlier
client errors, empty results, and all other errors are still reported.
An empty final result also preserves previously recognized text. Technical
errors return null and retain the preview for explicit "Use text" confirmation
after cleanup. They never submit it automatically. Retrying clears the preview;
cancellation never changes the existing query.
The owning view must call `cancel()` on close. `stop()`
allows the recognizer to deliver its final result. Only one session may run,
including setup and cleanup. The controller exposes typed failures for the UI
to localize, does not log transcripts and does not change navigation state.

Speech input is available for foreground planning before navigation starts.
The planner hides it during navigation until microphone/TTS coordination has
been implemented. On first use per app session, the dialog waits for an
explicit recording start. Listening is highlighted in red; failures show a
warning symbol and an actionable message.
Subsequent microphone taps start recording directly. Partial text stays in the
dialog; only the completed result replaces the query and triggers one search.
Cancellation preserves the previous query; choosing a search result remains
explicit. Offline recognition is not guaranteed.
Android Bluetooth routing is explicitly disabled in this increment; headset
input and headset-button activation require separate device tests.

Before user-facing release, test on physical Android and iOS devices:

- Grant/deny permissions, grant later in Settings, and revoke after use.
- Start, stop, cancel, retry, close search, background/resume, and incoming call.
- No speech, incomplete speech, network loss, unavailable recognition service,
  missing language, and successful recovery after each transient failure.
- Repeated recordings, microphone release, German street names/house numbers,
  ambient noise, and accessibility feedback.
- Existing TTS/navigation remains usable after microphone access ends.

Automated coverage lives in `test/speech/`; native audio, permission dialogs
and recognition quality still require device verification.

For a device failure, capture the debug console lines containing `Speech input:`.
They distinguish native error codes, status, setup phase, and whether text was
received. Transcripts, audio, and arbitrary platform error details are not logged;
leave the plugin's verbose `debugLogging` disabled. An unknown completion error
is not evidence that the device has no recognition service.

## Address and POI search (issue #245)

- Search original spelling first. After empty results, normalize CamelCase
  boundaries and association suffixes. Preserve address numbers, locations
  and punctuation. Only one additional spelling variant is tried.
- Discard autocomplete suggestions that contradict the parsed query postcode
  or city so they cannot block the existing Nominatim fallback. Missing
  location fields remain valid. Preserve city-name prefixes while typing,
  umlaut transliterations and fully recognized localized city names.
- One conservative compound-name retry is allowed for empty or unrelated mixed
  results; exact original names and normal street/city results
  keep their existing fast path. Never replace usable results with loose matches
  or an optional request failure.
- Keep Nominatim alternative names with the canonical destination and coordinates.
  Saved favorites and recent destinations remain compatible with older data.
- Query cancellation and replacement govern both results and provider attribution.
  Empty input must end loading and invalidate a pending request.
- See `docs/analysis/245-adresssuche-pois-alternativnamen.md` for current scope,
  remaining work and concrete phone tests.

## App reviews (issue #257)

The info menu exposes a localized Feedback subpage in the same sheet frame as Legend & tips with a store button
and clickable email and MunichWays website links. Email keeps the subject and app version;
test both external launches, closing, large text and missing email apps.
Automatic native review
requests are optional and never run at startup or during navigation. A trip
counts only when the orange Finish button shown after final arrival is pressed.
The close/cancel button never counts. Planning, aborts, intermediate stops, pause/resume and rerouting
do not add completions. Map-only routes without an arrival signal are excluded.

After the third qualifying completion, a two-second idle window may request a
native review. Further attempts require at least three more qualifying trips,
30 days since the last attempt, a different marketing app version, and fewer
than three attempts in the rolling preceding 365 days. Each marketing version
is requested at most once, even across restarts or a downgrade; changing only
the build number does not qualify. These thresholds suit occasional use without
requiring 50 or 100 trips. Passing time or installing an update alone never
requests a review: a qualifying completion must still trigger the idle window.
Trips made during a waiting period count toward the next opportunity, without
queuing multiple prompts. User interaction, backgrounding or a new task cancels this window.
Existing installations start at zero on update when review state is absent,
just like new installations; no first-run flag is used. Each attempt is persisted
before native handoff; silent suppression or native failure still consumes that
opportunity. Old schema 2 consumed attempts have no date or version: the first
subsequent state-changing operation conservatively anchors them to the current
date and app version, once. Diagnostics alone does not migrate or change state.
The unreleased schema 1 manual-store flag remains ignored. Manual store launches
leave the counter and automatic request state unchanged. No review result is inferred.
Counts and attempt dates/versions live only in `app_review.json`; no route or
account data is saved. This is attempt history, never evidence of a shown
dialog or submitted rating. The total trip counter continues past three.

Run the focused tests in `test/reviews/` and
`test/ui/info/info_sheet_review_test.dart`. For native Android UI testing use an
internal Play test track with the app in the test account's Play library. iOS
development builds can show the prompt; TestFlight cannot. An absent production
prompt is not by itself a failure. Test the manual link, store return, muted
guidance, aborts, background/resume and recovery after unavailable networking.
Test an update of an existing installation without deleting personal data.
For repeated eligible attempts, also verify the additional-trip requirement,
version restriction, cooldown and rolling yearly limit using controlled test
state; do not clear personal data to make a production prompt appear. The old
one-attempt policy in the [original analysis](docs/analysis/257-app-store-bewertungen.md)
is superseded by issue #296 and these rules.

Diagnostics are available under About & attributions, between Terms and the
version. They read persisted review state without changing it and show a bounded
in-memory review event history. API completion never proves that a dialog was
shown. Use Refresh and Copy to inspect counters, handoff, cancellation and store
availability. No coordinates, destinations, favorites or credentials are included;
no data is transmitted automatically. Wait ten seconds after the third Finish
before opening Info, which otherwise cancels a pending automatic prompt.

## Local phone tests in VS Code

Select the local launch configuration `munich-ways-app (release mode)` for
hands-on phone tests, `profile mode` for performance inspection, or the
standard debug configuration for development. Each configuration runs
`Handy: Testbuild vorbereiten` as its `preLaunchTask` and supplies
`--dart-define-from-file=${workspaceFolder}/.local/test_build_defines.json`
in `toolArgs`. Preserve the same Geoapify API key in all three local
configurations. The ignored `.vscode/launch.json` remains machine-local.

The preparation task invokes `tool/run_local_test_build.ps1 -PrepareOnly`.
It increments the existing `.local/test_build_number` counter and writes
`LOCAL_TEST_BUILD` to the JSON defines file. Every new VS Code launch gets
a new number, shown in the app's version information as `Testbuild N`.
Hot reload/restart within the same run keeps the number. Failed build attempts
may leave gaps; the counter is independent of the published app version.
Both generated files are ignored by Git. The existing command-line testbuild
script shares the counter and uses the Flutter version pinned in `.fvmrc`.

After installation, stop the VS Code run, force-stop the app on the phone,
unplug USB and open the app from its icon for a fresh standalone test.
Keep app data for normal update tests. When a failure occurs, reconnect and
collect logs before restarting the app. Profile/release app logging requires
separate configuration; this launch setup does not enable diagnostic logging.

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
  preserve BRouter fallback. Direct uses Fastbike and is identified
  as BRouter. Valid maneuver data enables voice guidance, including intermediate
  stops matched within 20 metres to unambiguous route positions in planned order.
  Absent/invalid hints or ambiguous/distant stops retain map-only guidance. Never
  substitute standard as direct. See `docs/analysis/249-brouter-abbiegeansagen.md`.
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

## Map inspection during navigation (issue #274)

Touching, panning, pinching or turning north-up releases only the camera.
Speech, remaining values, off-route
handling and guidance recovery continue. Confirmed GPS movement after all
fingers are lifted and a three-second quiet period restores follow-and-rotate
without recalculation or a new navigation start. Stationary GPS jitter, stale
fixes and jumps must not restore following. Keep the chosen zoom when following
resumes and until the next recalculation; warning-driven zoom changes also
respect manual map inspection. Picking a route point holds the camera until
selection ends. The close button explicitly pauses navigation; movement and
the location button must not clear that pause. Resume remains deliberate.

On Android and iOS, stop at a safe place during navigation, inspect the map and
change zoom. Keep the view still while stopped, then ride on: following and
direction-based rotation should return while the zoom stays chosen. Repeat
while already moving, with two fingers, after GPS loss/recovery, screen lock,
and with speech and automatic rerouting independently disabled. Leave/rejoin
the route while inspecting it and verify guidance recovers. Press close while
the camera is detached: navigation must stay paused until explicitly resumed.

## Closely spaced spoken turns (issue #287)

Automatic approach prompts use the existing speed lookahead and require at
least 40 metres of remaining lead; the usual approach window still ends at
60 metres and the immediate turn threshold remains 15 metres. Automatic
startup/recovery announcements also omit a late approach prompt. Explicitly
re-enabling speech still gives a short instruction when close to the turn.
The navigation header and explicit route-start preview remain available.

For maneuvers at most 35 metres apart, the combined spoken instruction omits
street names and uses shorter German turn wording. Direction qualifiers,
roundabout exits and road/cycleway transitions remain. A following isolated
turn retains its street name. Native speech interruption and cancellation
are unchanged so an urgent current instruction can still replace old speech.

On Android and iOS, compare slow and brisk riding, late GPS recovery and
recalculation 20-40 metres before a turn: no extra late approach prompt should
precede the normal immediate turn. Repeat with speech toggled off/on. Ride
the Birketweg crossing in both directions, then two and three nearby turns:
listen for complete directions and their order, including slight/sharp turns
and cycleway changes. Check long street names, screen lock and energy saving.
Actual voice duration and audible interruptions still require device tests.

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
- Rerouting retains the released start gate. Confirmed GPS displacement against
  an unambiguous route direction shows and announces a safe turn-around once,
  suppressing ordinary turns and arrivals until forward movement resumes.
  Displacement across a sharp bend and known outbound/return overlaps must not
  create a false turn-around. Stopping preserves the pending direction state;
  GPS gaps, jumps and poor fixes cannot establish a new direction.
  After such an interruption, two confirmed movements with agreeing bearings
  allow a new turn-around warning; a single GPS correction must not announce
  one. Forward movement can still clear an existing warning immediately.
  Movement for camera following and guidance recovery remains
  available after the first confirmed displacement. On Birketweg westbound
  after the underpass near 48.145456, 11.519798, restore tracking after screen
  lock/energy saving: expect no false turn-around and the regular right turn
  into Schloßschmidstraße. Also ride genuinely backwards after restoring GPS:
  the warning should appear after the second agreeing movement.
  Miss a turn by a few metres, immediately turn back and join the correct
  outgoing leg: a previous turn-around warning must clear, with regular
  guidance and remaining values restored. Repeat on the reported route from
  Bad-Schachener-Straße toward Bad-Kreuther-Straße, then deliberately ride
  backwards on the outgoing leg to verify that a new warning still works.
  On iOS and Android, leave a route so recalculation leads back the way you
  came: expect the turn-around promptly, continue away briefly (no ordinary
  turn countdowns), then safely turn and verify regular guidance resumes.
  Repeat with a stop, locked screen, restored GPS, and speech or automatic
  rerouting disabled independently. Also check a recalculated route branching
  ahead, a sharp bend and an overlapping return leg.
- Normal route matching shows and announces approach, turn, intermediate-stop,
  and final-destination guidance once at the appropriate progress thresholds.
  Intermediate and final arrival use the same 25 metre radius. On iOS and
  Android, ride just inside and outside that radius, including two nearby
  intermediate stops used to shape the route. Passed stops use a separate
  35 metre rerouting tolerance, independently of speech. After passing both,
  recalculate with speech on and off: neither stop should be requested again.
  Repeat after a failed recalculation and retry; unvisited stops must remain.
- A brief departure from the route marks guidance recovery as pending. Re-entry
  on any valid part of the route re-anchors maneuver progress and resumes normal
  guidance without requiring a network recalculation.
- A genuinely off-route rider is handled by the existing movement-aware flow:
  delayed visual status, delayed spoken warning, and automatic recalculation
  after 30 seconds when enabled. Stationary riders and isolated inaccurate fixes
  must not trigger this flow.
  A stop or a gap between confirmed movements preserves an existing off-route
  episode. If the spoken-warning timer expires without fresh moving GPS, the
  next confirmed off-route movement delivers the pending warning once, without
  restarting its delay. Rejoining the route or ending navigation cancels it.
  On iOS and Android, test leaving the route, briefly stopping before the
  warning, then continuing off route: the warning should resume, followed by
  recalculation and spoken guidance on the new route. Also rejoin the old route
  before continuing and verify that no pending warning is spoken.
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
- An unsupported guidance route, explicitly paused navigation, and the
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

## Remaining distance and time (issue #189)

The destination summary (#275) is one line: finish flag, bold estimated minutes,
arrival clock, distance. The clock icon is omitted. Navigation arrival time
belongs to the same remaining-progress snapshot: pause freezes it, stale or
unreliable progress removes it, and a fresh fix or replacement route restores
it. Repeated endpoint fixes retain the reached arrival time. The planning
preview refreshes its clock each minute and after app resume, without routing
or GPS requests. Large accessibility text scrolls horizontally instead of
shrinking or adding another row. Test Android/iOS in portrait and landscape,
large text, English, midnight rollover, pause/resume, GPS recovery and rerouting.

Before navigation the header shows route totals. During navigation it uses the
existing reliable route match for remaining distance and proportional travel
time, marked with `≈`. It never requests a route to update statistics. Values
expire 15 seconds after the location timestamp, independently of speech;
the matched route endpoint yields zero. The distance uses a finish flag icon.
Unknown and rerouting states show unavailable values until a reliable
fix restores them. Pausing retains the last displayed distance and time without
updates or expiry; resuming reinstates GPS freshness checks. Route replacement
and navigation end still clear retained values. Destination proximity alone
cannot manufacture zero or end guidance at an earlier occurrence on a loop.

Final destination access does not suppress statistics: distance and time refer
to the end of the calculated navigable route. Access length appears in the route
planner below the destination name, replacing its generic destination label;
the blue navigation panel keeps remaining distance and time without that row.
OSRM final access step metrics are removed from navigation totals; incomplete
step metrics use a geometric proportion as an estimate. Planning totals stay
unchanged. BRouter totals already stop at its route endpoint. Missing voice
hints, loops and repeated segments do not by themselves suppress statistics;
an actually ambiguous match still does. No extra routing requests are made.
In portrait, side controls follow the measured panel height so large text and
folding cannot leave the compass behind the panel.
Landscape panels reserve a horizontal lane for the side controls on their
selected side, preserving the limited vertical space.
See [scope and acceptance scenarios](docs/analysis/189-reststrecke-restzeit.md).

For phone/beta testing, ride a normal route with speech and automatic rerouting
each enabled/disabled, stop, briefly leave/rejoin, then trigger a real reroute.
Interrupt GPS/tracking and networking, restore them and verify recovery.
Check intermediate stops, out-and-back/loop/access routes, app return
after screen lock, energy saving, large text and English. Remaining values must
not trigger routing, speech or camera movement. Battery/performance comparisons
still require matched physical-device runs.

## Regression checklist

Navigation perspective (#276): on iOS and Android, start a new route and a
saved original route. While following the travel direction, expect a gentle
30-degree tilt without changing the established zoom. Pan/zoom the map: no
forced perspective jump during the gesture; confirmed riding restores the
tilted following view. North-up, pause, navigation end and route planning must
be flat. Resume or successfully Refresh: the riding perspective returns.
Repeat after screen lock/unlock, location loss/recovery and a light/dark style
change. Check route/position alignment, readable street labels and buildings,
portrait/landscape, zoom controls, and the unchanged spoken guidance.

Screen wake lock (#285): on iOS and Android with a short system auto-lock time,
start navigation from a new plan and a saved original route; the visible app
must keep the display on. Map inspection and muted guidance must retain this.
Pause navigation and wait: normal auto-lock must work, including after an app
switch. Continue or successfully Refresh: keep-awake must resume. A failed
Refresh must leave a paused route paused. End navigation: normal auto-lock must
return. Repeat foreground/background transitions, manual screen lock/unlock,
location-service loss/recovery and system power saving. Manual device locking
and background guidance remain under their existing system rules.

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

- Android map rendering (#287): on Flip3/Fairphone and another Android device,
  start with a fresh installation and immediately grant location permission.
  Start the first route, ride with the display on, then repeat several manual
  screen lock/unlock cycles, including a longer locked interval and an app
  switch. After every return, the position and route must update visibly and
  pan/zoom must respond immediately. Repeat with an existing installation,
  after ending/restarting navigation, in light/dark mode and with power saving.
  Check smoothness, map controls, overlays and unchanged background speech.
  If frozen, copy Info > Diagnostics before restarting, note the local time
  and collect Android logs. Successful native calls alone do not prove that
  the map image is being presented to Flutter.
- iOS: start navigation in the foreground, lock the screen and verify location
  updates and spoken turns continue, including after a longer stationary stop
- iOS: restore GPS after an outage with the screen locked; verify guidance
  recovers, then unlock and check route progress remains current
- iOS: end navigation and verify background location tracking stops; restart
  navigation and lock again to verify tracking and speech resume
- iOS: verify speaker and Bluetooth output, including interruptions from calls
  and spoken media; test with When In Use location permission
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
