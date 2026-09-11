# NetVendor

IP → MAC → vendor lookup. A Flutter desktop app reads your local ARP table to find the MAC
address behind an IP on your network, a Rails API resolves that MAC to a hardware vendor
(with caching and a fallback provider), and every lookup is recorded so you can browse recent
history.

## How it fits together

```
netvendor/
├── rails_api/      Rails 8 API-only app (Postgres) — resolves + persists lookups
├── flutter_app/     Flutter desktop app (macOS; Riverpod) — ARP + UI
├── docs/
│   └── AI_USAGE.md  Running log of how AI was used to build this
└── README.md         this file
```

**Flow:** you type an IP in the app → the app reads this machine's local ARP table
(`arp -a`) to find that IP's MAC address → the app sends `{ ip_address, mac_address }` to the
Rails API → Rails checks the database for that MAC first, and only calls out to an external
vendor API on a miss → Rails saves the result and returns it → the app shows it and refreshes
the recent-lookups list.

ARP only knows about devices this machine has recently talked to on the same local network, so
a lookup only works for IPs your machine has seen traffic from/to recently (its own IP, other
devices on the LAN, etc.) — not arbitrary internet hosts.

### Why `GET` and `POST` are separate endpoints

The brief's example (`GET /lookups?mac=...`) reads as one endpoint that both looks up and saves
a vendor. We split that on purpose:

- **`POST /lookups`** — the endpoint the Flutter app actually calls. Takes `{ ip_address,
  mac_address }`, resolves the vendor, and always creates a `Lookup` record — even when every
  vendor provider fails (`status: "error"`), so a failed attempt still shows up in history.
- **`GET /lookups?mac=...`** — a pure, side-effect-free vendor lookup with no database write.
  A `GET` silently writing to the database is surprising REST behavior, so this exists as a
  standalone wrapper around the vendor API for other consumers; the desktop app never calls it.
- **`GET /lookups`** (no `mac` param) — paginated lookup history, newest first.

## Rails API (`rails_api/`)

**Requirements:** Ruby 3.4.2 (see `.ruby-version`), PostgreSQL running locally, Bundler.

```bash
cd rails_api
bundle install
bin/rails db:create db:migrate
bin/rails server            # http://localhost:3000
```

If Postgres isn't running: `brew services start postgresql@17` (or whichever version you have).
The default `config/database.yml` connects over TCP to `localhost:5432` with no password
(matches Homebrew's default trust/peer auth) — adjust it or set `DATABASE_URL` for a different
setup.

### Endpoints

| Method | Path | Behavior |
|---|---|---|
| `POST` | `/lookups` | Body `{ ip_address, mac_address }`. Resolves the vendor and creates a `Lookup`. `201` on success (including a saved `status: "error"` row when every vendor provider failed), `422` on invalid/missing input. |
| `GET` | `/lookups?mac=AA:BB:CC:DD:EE:FF` | Vendor-only lookup, nothing persisted. `200` with `status: "found"`/`"unknown"`, `422` on missing/invalid `mac`, `502` if every vendor provider failed. |
| `GET` | `/lookups?page=&per_page=` | Paginated history, newest first (no `mac` param = this mode). |

Every error response has the shape `{ "error": { "code": "...", "message": "..." } }`.

### Tests

```bash
cd rails_api
bundle exec rspec      # 81 examples
```

All external vendor-API calls are blocked by WebMock, so the suite passes regardless of those
APIs' real availability.

## Flutter app (`flutter_app/`)

**Requirements:** Flutter SDK (Dart `^3.10.4`) with macOS desktop enabled
(`flutter config --enable-macos-desktop`), Xcode command line tools, and the Rails API running
locally first (see above).

```bash
cd flutter_app
flutter pub get
flutter run -d macos
```

The API base URL defaults to `http://localhost:3000`. Point at a different host/port with:

```bash
flutter run -d macos --dart-define=NETVENDOR_API_BASE_URL=http://host:port
```

### Tests

```bash
cd flutter_app
flutter test        # 49 tests
flutter analyze      # 0 issues
```

Architecture follows Clean Architecture per feature: `domain` (entities, the `LookupRepository`
interface, typed exceptions) knows nothing about `data` (ARP parsing, network-interface
detection, the Dio HTTP client, and `LookupRepositoryImpl` composing them) or `presentation`
(Riverpod providers, the screen, widgets) — `presentation → domain ← data`. This is what lets
the repository, controller, and widget tests each mock only the layer directly below them.

**Deliberate test-scope choice:** no automated test drives the app against a live, running Rails
server — the widget tests' mocked-`LookupRepository` boundary is the intended ceiling for the
automated suite, not a gap to fill in later. `LookupRemoteDatasource`'s HTTP-error mapping is
still verified directly (against a mocked `Dio`, not a mocked datasource), and the ARP parser is
tested against real captured `arp -a` output, so the boundary sits at "the network," not at
anything ARP- or vendor-response-shape-related. The one thing genuinely outside that boundary —
whether the live GUI itself works end-to-end — is covered by manual verification instead; see
"Known limitations" below.

## Known limitations

- **Linux desktop is scaffolded, not verified.** `flutter create` targeted both macOS and Linux,
  but this development machine has no Linux desktop tooling installed, so the Linux build was
  never produced or run — only macOS was.
- **Windows isn't targeted.** ARP output parsing covers the macOS and Linux `arp -a` formats
  only.
- **The live "type an IP → click Look up → see a new result" path was verified by hand, not by
  this session.** Everything around it was verified independently: a widget test exercises the
  exact same widget tree end-to-end against a mocked repository; the real `arp -a` process was
  run against this machine's actual ARP table outside the test suite; the built macOS app was
  launched against the real running Rails API and confirmed to auto-fill the local IP and load
  real lookup history. The one link connecting all of that — an actual click in the live,
  unmocked GUI — needed driving the running app's UI, which this Claude Code session couldn't do
  itself (no macOS Accessibility permission for automated UI clicking, and no `cliclick` or
  equivalent installed). David verified that step manually before this was called done.
- **No authentication.** The API is meant to run locally for this exercise.
- **No Swagger/OpenAPI docs** in this iteration — the endpoint table above and the request specs
  are the source of truth for the API's behavior.

## AI usage

This was built with Claude Code from a plan I wrote (architecture, endpoint semantics, folder
layout, test strategy). See [`docs/AI_USAGE.md`](docs/AI_USAGE.md) for a running, per-milestone
log: what was asked for, decisions made along the way, bugs Claude found (including one only
caught by actually running the built app, not by any test), and anywhere its output needed
correcting.
