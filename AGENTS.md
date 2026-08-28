# MunichWays agent instructions

## Priorities

Stability, data reliability, performance, accessibility, and simple operation
take precedence over new functionality. A small improvement must not break a
more important existing workflow. Prefer the simpler solution; if an extension
cannot be made clearly safe, do not ship it or revert it narrowly.

Treat startup, update, offline use, recovery after errors, routing, navigation,
and automatic rerouting as critical paths.

## Git workflow

- Work only on a feature or bugfix branch, never directly on `master`.
- Inspect the branch and working tree before editing. Preserve user changes.
- Do not commit or push unless the user explicitly asks for it in the current
  task. An earlier request does not authorize later commits or pushes.
- Keep unrelated work separate. Never hide failures by reverting user changes,
  weakening checks, or disabling tests.
- Before a requested commit or push, review the complete diff and run the
  quality checks below. Commit only files belonging to the requested work.

## Engineering workflow

Before changing code, trace the complete affected flow and its existing tests.
Distinguish the root cause from symptoms and choose the smallest causal fix.

For asynchronous flows and state machines:

- Maintain one authoritative state instead of adding competing state logic.
- Check start, cancellation, timeout, retry, error, and recovery transitions.
- Do not accidentally cancel, duplicate, or permanently block timers, streams,
  background work, loading states, speech, or navigation updates.
- Preserve offline and bundled fallbacks independently of network responses.

When the cause or safety of a fix is unclear, gather logs or add a reproducer
before changing behavior. If a regression comes from a risky enhancement,
prefer reverting only that enhancement while retaining unrelated fixes.

## Verification

For every code change:

1. Format the changed Dart files.
2. Run `git diff --check`.
3. Run static analysis.
4. Run focused tests for the affected behavior.
5. Add a regression test when practical.
6. Before a requested push, run the full test suite.

Standard commands:

```text
dart format --output=none --set-exit-if-changed <changed Dart files>
git diff --check
flutter analyze --no-pub
flutter test --no-pub
```

Do not report a blocked or skipped check as successful. State exactly what was
not run and why. Do not push with a blocked or failing required check unless the
user explicitly accepts that risk after being informed.

For critical behavior, also test recovery: the app must return to normal after
a transient failure. Use the scenario checklist in `CONTRIBUTING.md`.

## Handoff

Report the root cause, changed behavior, relevant side effects checked, test and
analysis results, skipped checks, and whether changes are uncommitted,
committed, or pushed.
