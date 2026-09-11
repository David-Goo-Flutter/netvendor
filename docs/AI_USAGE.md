# How AI Was Used

Tool: Claude Code (CLI agent, Claude Opus), driven from a written plan (`README.md` describes the resulting architecture).
Workflow: I wrote the plan (architecture, endpoint semantics, folder layout, test strategy) myself, then had Claude
implement it milestone by milestone while I reviewed each step. Entries are added as each milestone finishes.

---

## Milestone 1 — Rails setup, `Lookup` model, `VendorLookupService`

**Asked for:** Rails `--api` app with Postgres, `Lookup` model per the plan, a vendor lookup service with a
fallback provider and a cache-first read, RSpec + WebMock specs.

**What Claude did before writing code**
- Probed the candidate vendor APIs with `curl` to learn their real response shapes instead of guessing:
  - maclookup.app returns `200 {"found": false}` for an unregistered OUI (not a 404) and `400` for malformed input.
  - macvendors.com returns plain text on success and `404` for an unregistered OUI.
  - Result: "unknown vendor" is a definitive answer from either provider; only timeouts / 5xx / 429 / bad bodies
    trigger the fallback. This distinction (`unknown` vs `error`) drives both the service and the API status codes.
- Looked at the real `arp -a` output on the dev machine and noticed randomized (locally administered) MACs,
  e.g. `92:90:ae:…` from an iPhone's private Wi-Fi address. These have no vendor by definition, so the service
  short-circuits them to `unknown` without a network call. This was not in my original plan.
- Noticed macOS `arp` drops leading zeros (`0:1a:2b:3:4:5`), so MAC normalization zero-pads octets.

**Environment problems it diagnosed**
- `gem install rails` failed linking a native extension "for iOS": the shell exports `SDKROOT` pointing at the
  iPhoneOS SDK. Fixed per-command (`SDKROOT=$(xcrun --sdk macosx --show-sdk-path)`) without editing my profile.
- Homebrew Ruby's default bundler 2.6.8 was missing its executable; installed a current bundler.
- json 3.0 vs ActiveSupport 8.1.3 incompatibility (`JSON.parse` keyword-only options) broke every `jsonb` read.
  Found from the backtrace; pinned `json < 3` with a comment in the Gemfile.

**Reviewed / decided by me**
- Kept Postgres (the plan stores `raw_response` as `jsonb`).
- Cache only reuses `found`/`unknown` rows — an earlier `error` row must not block a retry.

## Milestone 2 — `POST /lookups`, `GET /lookups`, request specs

**Plan gap caught:** the plan had both "`GET /lookups` = history" and "`GET /lookups?mac=` with missing `mac` → 422".
Those share a path, so "missing mac" can only mean *present but blank*; no `mac` key means history.

**Decisions**
- `POST` validates IP/MAC before calling any external API (no wasted calls on bad input).
- `POST` still records a lookup when every provider fails (`201`, `status: "error"`) so history shows the attempt;
  the side-effect-free `GET ?mac=` returns `502 vendor_lookup_unavailable` in the same situation since nothing
  was created.
- `raw_response` stays in the DB for debugging but is never returned to clients.

**Result:** 54 specs (model, service, request), all external HTTP blocked by WebMock; RuboCop clean.

## Milestones 3-6 — Flutter app: Riverpod structure, ARP parser, screen, auto IP detection

Built in one pass since the layers are small and interdependent: domain entities/repository interface,
data (ARP + network-interface + Dio datasources, models, repository impl), presentation (providers,
screen, widgets), then tests for each, following the plan's folder layout exactly.

**Kept from the plan, unchanged:** hand-written providers/`fromJson` (no `riverpod_generator`/`freezed`,
per the plan's own scope note), `AsyncNotifier` for the controller, mocktail for the domain-level mocks,
`Process.run('arp', ['-a'])` with parsing split into a pure `parseArpOutput` function.

**Small additions beyond the plan's file tree, and why**
- `lib/utils/mac_address.dart` / `ip_address.dart` -- pure validation/normalization, mirroring the Rails
  `MacAddress` module so both sides agree on what's a valid MAC/IPv4 and on canonical MAC formatting.
- `domain/exceptions/lookup_exceptions.dart` and `data/exceptions/lookup_api_exception.dart` -- the plan's
  "clear error message" requirement needed a real type for the repository to throw and the controller's
  `AsyncError` to carry; `LookupRepositoryImpl` translates data-layer exceptions into domain ones so
  `LookupResultCard` can show a specific message without knowing whether ARP, this machine's network, or
  the API request failed.
- `presentation/providers/local_ip_address_provider.dart` -- a `FutureProvider` wrapping
  `detectLocalIpAddress()`, watched once by `LookupInputField` via `ref.listen` to pre-fill the text field
  without clobbering anything the user already typed.

**What Claude did before/while writing code**
- Reused the real `arp -a` output already captured while building the Rails side (including the
  randomized-MAC and `(incomplete)` entries) as the actual test fixtures for `parseArpOutput`, rather than
  inventing sample strings -- so the parser is verified against this machine's actual format, not a guess.
- The two response shapes from Rails (`POST /lookups`'s `cached` field vs `GET /lookups`'s list items) map
  to two separate models/entities (`LookupResultModel`/`LookupResult` vs `RecentLookupModel`/`RecentLookup`)
  per the plan's domain split, even though most fields overlap -- kept them separate rather than
  "simplifying" to one shared type, since the plan explicitly wanted lookup_result and recent_lookup as
  distinct entities.

**Bug found only by running the real app (not caught by any test):** the built macOS app could launch and
render, but every API call silently failed with "Could not reach the NetVendor API" -- even with the real
Rails server running and reachable via `curl`. Cause: Flutter's default macOS App Sandbox entitlements
(`macos/Runner/*.entitlements`) grant `network.server` (needed for the debug/hot-reload connection) but not
`network.client`, so the sandbox blocks the app's own outgoing HTTP requests. Added
`com.apple.security.network.client` to both `DebugProfile.entitlements` and `Release.entitlements`. This is
a good example of why "tests pass" isn't the same as "the app works": the widget tests use a mocked
repository and never touch the real network stack, so they couldn't have caught this.

**Verification performed**
- `flutter analyze`: 0 issues (lib and test).
- `flutter test`: 39/39 passing across ARP parsing, MAC/IP validation, repository, controller, and 2 widget
  tests (success and error paths through the real `LookupScreen` widget tree, repository mocked).
- `flutter build macos --debug`: builds cleanly.
- Ran the actual built app against the actual running Rails server (not mocks): confirmed the IP field
  auto-fills with this machine's real LAN IP, and confirmed (via screenshot, before and after the
  entitlement fix) that "Recent lookups" changes from an unreachable-API error to the real seeded history
  with correctly color-coded status dots and relative timestamps.
- Did not verify the live "type an IP → click Look up → new lookup appears" path through the actual GUI:
  driving the built app's UI needed macOS Accessibility permissions this shell doesn't have, and no
  `cliclick`/equivalent was installed. That exact code path (`LookupInputField` → `lookupControllerProvider`
  → `LookupResultCard`) is covered by the widget tests against a mocked repository, and the ARP parser and
  the Rails `POST /lookups` endpoint were each independently verified against real data, so the only
  unverified link was the GUI click itself -- **the human (David) confirmed this manually** before Milestone 7.

## Milestone 7 — Error-case sweep

Went through each error case end-to-end, checking the actual UI state produced, not just the HTTP status
underneath it. Found one real gap while doing this: `LookupRemoteDatasource`'s HTTP-error-to-domain-exception
mapping (`_mapError`) was only ever exercised through a *mocked* `LookupRemoteDatasource` in the repository
and controller tests -- meaning the code that actually parses a Dio response/exception had zero direct
coverage. Added `test/features/lookup/data/datasources/lookup_remote_datasource_test.dart`, mocking `Dio`
itself (a standard pattern: mocktail's `noSuchMethod`-based mocking doesn't care about a method's generic
type argument, so `class _MockDio extends Mock implements Dio {}` works despite `Dio.get<T>`/`post<T>` being
generic) to stub realistic responses/`DioException`s and verify the real mapping logic.

| Case | Where it's decided | UI state confirmed |
|---|---|---|
| No ARP entry for the IP | `ArpLocalDatasource.findMacAddress` returns `null` → `ArpEntryNotFoundException` | Error card: "…is not visible on the local network…" (widget test + real `arp -a` run below) |
| Invalid IP format | `LookupRepositoryImpl.lookup` validates before touching ARP → `InvalidIpAddressException` | Error card: `"999.1.1.1" is not a valid IPv4 address.` (new widget test) |
| Invalid MAC format | Rails-side only -- the app has no way to enter a MAC directly, it only ever comes from a real ARP entry that already passed `normalizeMacAddress`. Covered by `spec/requests/lookups_spec.rb` (422 `invalid_mac_address`) and re-verified live with `curl` in Milestone 1. `LookupRemoteDatasource`'s 422-body mapping is now also unit-tested directly (see above) so this would still degrade gracefully if it were ever reachable. | N/A in the live GUI; Rails returns `422 { error: { code: "invalid_mac_address", ... } }` |
| Both vendor providers down | Rails still returns `201` with `status: "error"` (this is a *successful* HTTP response, not a thrown exception) | Result card renders normally with a red "lookup failed" chip and "Unknown" vendor -- confirmed this does **not** hit the error-banner path (new widget test distinguishing it from the two exception-driven cases above) |

**Additional live check (not part of the automated suite):** wrote and ran a throwaway script exercising the
real `Process.run('arp', ['-a'])` path (the one thing no unit test touches, since `parseArpOutput` is tested
against fixed strings) against this machine's actual ARP table -- confirmed a known IP (`192.168.12.1`)
resolves to its real MAC and an IP absent from the table (`192.168.12.99`) returns `null`. Deleted the script
afterward; it wasn't meant to be part of the repo.

Result: 49 Flutter tests passing (10 new), 54 Rails specs still passing, `flutter analyze` clean.

## Course correction: two "finished" features that weren't actually there

Before Milestone 8, a "finish" prompt asked me to write the README referencing a Swagger UI link
and a port-3001 note as if both were already done. Checking the repo directly (`git log`,
`Gemfile`, `routes.rb`, `puma.rb`, `dio_provider.dart`) showed neither had actually been applied
-- no `rswag` gems, no `swagger/` directory, no `/api-docs` route, server still defaulting to
port 3000. Two other draft prompts sitting in `Claude outputs/` (`cli-prompt-swagger.md`,
`cli-prompt-port.md`) described that exact work in detail, so it looks like they were meant to be
pasted into this session before the "finish" one and never were -- separately, port 3000 really
was occupied by another process on this machine (`lsof -i :3000` showed a `node` process), so the
port-conflict premise itself was real, just not yet acted on here.

Flagged this rather than writing documentation for features that don't exist (or silently
building the two undone features myself, which would have been unrequested scope). Asked which
of: (a) do both first, then README; (b) skip both, README matches the repo's actual state; (c)
port fix only. Chose (b) -- README, item 7, and the GitHub push all reflect what's really in the
repo: port 3000, no Swagger UI.

## Milestone 8 — Top-level README

Covers the overview/flow, monorepo layout, the `GET`/`POST` split rationale (condensed from the
plan's own reasoning), how to run and test both halves (verified against port 3000, matching the
above), and a "known limitations" section -- Linux/Windows untested, no auth, no Swagger, and
that the live "click Look up in the running GUI" step was verified by David by hand rather than
by this session (see the Milestones 3-6 entry above for why). Also replaced the default `rails
new`/`flutter create` boilerplate READMEs in each subproject with short pointers back to this one,
since a reviewer would otherwise land on generic starter-template text.

## Milestone 9 — Public GitHub repo

Checked `gh auth status` (already authenticated as `davidsdream`) and confirmed no `netvendor`
repo already existed on the account before creating one, to avoid silently overwriting something.
Created `davidsdream/netvendor` as **public** via `gh repo create --source=. --remote=origin`,
pushed `main`, and confirmed via `gh repo view --json visibility` that it's actually public with
`main` as the default branch. Did not send the reviewer invite -- that needs their GitHub handle
or email, which wasn't provided yet.

## Catch-up: `MacAddress` direct unit spec

Got a queued prompt (`cli-prompt-tests.md`) asking me to check whether `MacAddress`
(`app/models/mac_address.rb`) had its own direct unit spec before Milestones 4-5, and to add one
if it was only exercised indirectly. This prompt turned out to be earlier in the queue than the
"finish" one already handled -- everything else it asked for (the ARP parser + its tests, the
repository/controller/widget tests, `mocktail` as a dev dependency, the README's test-scope note)
was already done in Milestones 3-8. Checked the repo directly rather than assuming either way:
`spec/models/` only had `lookup_spec.rb`, so `MacAddress.normalize`/`.locally_administered?` were
indeed only ever exercised indirectly (through `Lookup`'s normalization and
`VendorLookupService`'s locally-administered short-circuit test).

Added `spec/models/mac_address_spec.rb` directly: all four accepted input formats
(colon/dash-separated, unpadded octets, Cisco-dotted, bare hex) plus invalid input for
`.normalize`, and `.locally_administered?` against a real captured example
(`92:90:ae:e9:5f:6b`), the canonical `02:00:00:00:00:00` textbook case, a real manufacturer MAC
(expected `false`), a multicast-but-not-locally-administered address (bit 0 vs bit 1, to make sure
the bit check isn't accidentally testing the wrong bit), and invalid input (returns `false`, not
an exception). 27 new examples; 81 total, 0 failures; RuboCop clean. Bumped the spec count in both
READMEs from 54 to 81.

## Catch-up: state the deliberate Flutter test-scope choice in the README

The same queued test-plan document (`Claude outputs/test-plan.md`) also asked that a specific
design decision be stated in the README "if asked": no automated test drives the app against a
live, running Rails server -- the widget tests' mocked-`LookupRepository` boundary is the
*intended* ceiling for the suite, not a gap. That framing was implicit (the "Known limitations"
section talked about the one thing outside it) but never said outright, so added a short
paragraph to the README's Flutter Tests section making it explicit, and noting that the boundary
specifically sits at "the network" rather than at ARP or vendor-response parsing -- both of those
are independently covered (ARP against real captured output, HTTP-error mapping against a mocked
`Dio` rather than a mocked datasource) inside that same boundary.

## Moved the public repo from a personal account to an org

Moved the repo from `davidsdream/netvendor` to `David-Goo-Flutter/netvendor`. Before creating
anything, checked that the org exists and that the authenticated account (`davidsdream`) actually
has admin membership on it (`gh api user/memberships/orgs/David-Goo-Flutter`), and that no
`netvendor` repo already existed there -- same "look before creating/overwriting" check as the
first time this repo was created. Created the new repo, repointed `origin`, pushed, then verified
the push by querying the GitHub API directly (`gh api repos/.../commits?sha=main`, plus
`default_branch`/`visibility`) rather than trusting `git push`'s exit code -- all 7 commit SHAs on
`main` matched the local `git log` exactly. Confirmed the old `davidsdream/netvendor` repo is
untouched and still public, as instructed (its fate is a separate decision, not made here).

Checked for anywhere the old URL/owner needed updating: the top-level README never actually
contained a repo link or clone URL, so there was nothing to fix there. The only mentions of
`davidsdream` were in this file's own Milestone 9 entry above, describing what was true *at that
point in the build* -- left that entry as accurate history rather than rewriting it, and recorded
the move here instead.

## UI polish round: six concrete fixes from screenshots

The user proposed a larger redesign earlier (dark theme, `NavigationRail`, a Stats tab) via the
brainstorming skill's bounded-path gate; that design is still awaiting approval. Separately, they
sent screenshots with six specific, unambiguous style fixes to the *current* UI -- these didn't
need another design/approval round, since there was no remaining ambiguity to explore, just
direct instructions:

1. Removed the debug banner (`debugShowCheckedModeBanner: false`).
2. `LookupInputField`: wrapped the input row in `IntrinsicHeight` with `CrossAxisAlignment.stretch`
   so the "Look up" button's height tracks the text field's actual rendered height instead of a
   guessed fixed value.
3. Same widget: gave the text field's `OutlineInputBorder` and the button's `RoundedRectangleBorder`
   the same `BorderRadius` (a shared `_fieldRadius` constant) so they read as one control instead of
   a pill button glued to a sharp-cornered field.
4. `LookupScreen`: enlarged and bolded the "NetVendor" title.
5. `LookupResultCard`: removed the separate bordered "Enter an IP address..." placeholder card;
   that message now lives as the text field's own `hintText` instead (replacing the old
   `"192.168.1.1"` example hint), and the card renders `SizedBox.shrink()` until there's a real
   result or error.
6. `RecentLookupsList`: wrapped the list itself in a `Card` with `Clip.antiAlias` so the rows and
   dividers respect its rounded corners.

Verified with `flutter analyze` (clean) and `flutter test` (49/49 still passing -- including the
initial-state widget test that looks for the "Enter an IP address..." text, which still matches
since Flutter renders `hintText` as a `Text` widget internally), then rebuilt the macOS app and
screenshotted it to visually confirm all six against the original screenshots.
