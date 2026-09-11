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
  "명확한 에러 메시지" requirement needed a real type for the repository to throw and the controller's
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
  unverified link is the GUI click itself -- worth a manual check before considering the app fully done.
