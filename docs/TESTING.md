# Testing strategy

Every ticket ships with tests for its core functionality, and every behaviour is tested **once**, at the lowest layer where it can be tested. Higher layers trust lower layers instead of re-testing them. CI runs all of it on every pull request; nothing merges unless it passes.

## Layers

| Layer | Where | Tests | Does not test | Tool | In CI |
|---|---|---|---|---|---|
| **1. Rules** | `packages/sva_core/test/` | Pure logic: ascent rules (style and tries), grade conversion, stats maths, insights, skill points, gear and shoe due dates, goal progress | Storage, UI | `package:test` | Every PR |
| **2. Data** | `packages/sva_data/test/` | Schema and migrations, repositories, queries and their results, sync adapters, against an in-memory database | Rule logic (calls `sva_core` and trusts it), UI | `package:test` + drift in-memory | Every PR |
| **3. Widgets** | `packages/sva_ui/test/`, `app/test/` | One screen or component at a time with fake repositories: what it shows, what each tap does, empty and error states, accessibility labels, both themes | Rules, queries (faked) | `flutter_test` | Every PR |
| **4. Server** | `supabase/tests/` | Row-level security, Postgres functions, triggers, scheduled jobs | App code | pgTAP | Every PR (from M11) |
| **5. Flows** | `app/integration_test/` | A few end-to-end journeys across screens with a real local database: log a session, edit it, see it in history | Every detail (covered below) | `integration_test` on an Android emulator | Every PR (from M0-8) |

### Shared rule cases

Rules that run both in the app and on the server (style and tries) are written once as JSON cases in `shared/test_cases/` at the repository root, so the server tests can read them without reaching into a Dart package. Layer 1 and layer 4 both run the same file. That is one set of cases, not two overlapping test suites.

### Golden tests

Illustrations (logo, gear, shoes, topos, charts) use golden image tests in layer 3, in both themes. Update goldens only on purpose, and include the new images in the PR.

## One test per "Done when" item

1. Every item in a ticket's "Done when" list gets at least one test, at the layer named in the ticket's **Tests** section.
2. The test's description starts with the ticket code, so it can be traced back:

   ```dart
   test('M1-4: a flash is always one try', () { ... });
   testWidgets('M2-3: save is disabled until a style is picked', (tester) async { ... });
   ```

3. Supporting tests (edge cases, regressions) go in the same file and also start with the code.
4. A "Done when" item that cannot be automated (for example "you can install it on your iPhone") is checked by hand and marked as manual in the PR.

## Avoiding overlap

- **Lowest layer wins.** If a rule can be tested in `sva_core`, it is tested there and nowhere else. A widget test for the log screen checks that the screen *shows* the hint from the rule, not every case of the rule.
- **Fake what is below.** Widget tests use fake repositories; repository tests trust `sva_core`. Only layer 5 runs the real stack, and only for a few journeys.
- **One owner per behaviour.** Before adding a test, search for the ticket code and the behaviour (`grep -rn "M1-4" packages app`). Extend the existing test instead of adding a parallel one.
- **Flows test journeys, not features.** Each milestone adds at most one or two flow tests: the main path a tester would follow.
- **Reviewers check it.** The code reviewer (`review-pr`) flags missing tests for "Done when" items and tests that duplicate a lower layer.

## Running tests

```bash
tool/check.sh                              # everything CI runs on every PR, except flows
cd app && flutter test integration_test    # flows, needs a simulator or emulator
```

In CI, flows run in the "Flow tests" job on an Android emulator (API 34). The emulator snapshot is cached, so a warm run takes a few minutes. New flows go into `app/integration_test/` and run in the same job; do not add a job per flow. With several devices connected, pick one with `-d <device id>` (see `flutter devices`).

## Coverage

`sva_core` aims for full branch coverage of its rules; other layers aim for the behaviours in each ticket rather than a percentage. A coverage report is added to CI with the first rules (M1).
