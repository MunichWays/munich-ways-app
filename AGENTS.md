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

## Scrumboard and user stories

- Without explicit user approval, limit Scrumboard and user-story updates to
  the agent's own comments, clearly marked as AI comments. Editing story
  descriptions, titles, status, fields, or other board content requires approval.
- Keep additions and changes to user stories brief: summaries only. Put
  implementation details in the branch and pull request.
- At completion, the user story should concisely document:
  1. What problem, feature, or requirement is addressed.
  2. How it was implemented: a broad summary of the code changes, with links
     to the branch and pull request for details.
  3. How to test it: what to check during hands-on phone testing and beta
     testing, with concrete user steps, relevant conditions, and expected app
     behavior. Do not include AI verification, automated code tests, analysis,
     or build results in this section; report those in the pull request and
     technical handoff instead.
- Provide this completion summary in an AI comment unless the user has
  approved editing the story itself. Do not imply that a branch, pull request,
  or successful check exists before it has been created or verified.

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

Only one Flutter tool command may own this workspace at a time. Never run
analysis, tests, builds, or deployments in parallel. While the user has an
active VS Code phone run, limit work to code inspection and read-only ADB/log
diagnostics. Wait until the user reports that USB is disconnected and the
Flutter run has ended before starting automated Flutter checks.

Before handing a code change to the user for a local phone test, finish all
analysis, tests, and builds and verify that their processes have exited. Check
the workspace status and any remaining Flutter, Dart, Gradle, or VS Code run
processes using this workspace; an available Flutter lock alone does not prove
that a failed build or run has stopped. Do not start `Run Without Debugging` or
`run_local_test_build.ps1` while another process is still building, analyzing,
testing, deploying, or running this app. If a stale process remains after a
failed attempt, stop it and check again before starting the phone test. Do not
report the build as ready for local testing while this check is unresolved.

For every code change:

1. Format the changed Dart files.
2. Run `git diff --check`.
3. Run static analysis, and wait for it to finish.
4. Run focused tests for the affected behavior after analysis has finished.
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
