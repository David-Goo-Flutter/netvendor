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
