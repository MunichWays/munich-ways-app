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
