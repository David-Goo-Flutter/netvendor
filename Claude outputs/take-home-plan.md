# Flutter + Rails Take-Home Plan — Option 1 (IP → MAC → Vendor Lookup)

## 0. Naming

- App name: **NetVendor**
- Flutter `pubspec.yaml` name: `netvendor`
- Rails app: `netvendor_api`
- GitHub repo: `netvendor`

## 1. Repo Structure (Monorepo)

```
netvendor/
├── rails_api/              # Rails API (netvendor_api, JSON only, --api mode)
├── flutter_app/            # Flutter desktop app (NetVendor, Riverpod)
├── README.md                # Overview, architecture, how to run, AI usage notes
└── docs/
    └── AI_USAGE.md           # Log for the "how did you use AI" interview question
```

Go with a single monorepo, and make sure the top-level README spells out "cd rails_api && ...", "cd flutter_app && ..." so a reviewer can run everything immediately.

## 2. Rails API Design

### 2.1 Model
`Lookup` (table `lookups`)
- `ip_address:string`
- `mac_address:string` (normalized: lowercase, colon-separated)
- `vendor:string` (nullable — allow failed lookups / unknown vendors)
- `status:string` (`found` / `unknown` / `error`)
- `raw_response:jsonb` (nullable, stores the raw external API response — useful for debugging/audit)
- `created_at`

Index on `mac_address` (so a repeat lookup of the same MAC hits the cache).

### 2.2 Service Object
`app/services/vendor_lookup_service.rb`
- Takes a MAC address and calls an external vendor lookup API (macvendorlookup.com, or maclookup.app as a free-tier alternative — plan for one as a fallback)
- Use Faraday (or Net::HTTP), with timeouts and handling for 404 / rate limits
- Cache-first: skip the external call if the MAC is already in the DB

### 2.3 Endpoints (decided: separate GET and POST)

The brief's example (`GET /lookups?mac=...`) implies a single endpoint that both looks up and persists. We're deliberately splitting this so GET stays a pure, side-effect-free read (no DB write). Note the rationale in the README.

- `GET /lookups?mac=AA:BB:CC:DD:EE:FF` — single lookup, no persistence. Missing `mac` param → 422; invalid MAC format → 422; vendor not found → 200 with `status: unknown` (reserving 404 for "the resource itself doesn't exist" — "looked it up but don't know the vendor" is more correctly a 200)
- `POST /lookups` — takes IP + MAC, looks up the vendor, and creates a record (this is the endpoint the Flutter app actually calls; `GET /lookups?mac=` is kept separate as a pure wrapper around the vendor API)
- `GET /lookups` — recent lookup history (paginated, newest first)

Standardize the error shape as `{ error: { code:, message: } }`.

### 2.4 Tests (RSpec + WebMock)
- `spec/services/vendor_lookup_service_spec.rb`: stub the external API with WebMock for success / failure / timeout / unknown-vendor cases
- `spec/requests/lookups_spec.rb`: status codes, response bodies, and 422 cases for the POST/GET endpoints
- `spec/models/lookup_spec.rb`: validations (MAC format, IP format)
- Block all real network calls with WebMock (`WebMock.disable_net_connect!`) so tests always pass regardless of whether the external API is up

## 3. Flutter App Design (Riverpod, desktop)

### 3.1 Folder Structure (root + per-feature domain/data/presentation)

Clean Architecture style: each feature has its own domain/data/presentation, feature-specific providers live inside that feature, and only providers shared across multiple features (e.g. the Dio instance) live in a root-level `providers/` folder.

```
lib/
├── main.dart
├── providers/                                  # ROOT: global providers only
│   └── dio_provider.dart                         # Dio instance (base URL, app-wide config)
└── features/
    └── lookup/
        ├── domain/
        │   ├── entities/
        │   │   ├── lookup_result.dart              # IP/MAC/Vendor result entity
        │   │   └── recent_lookup.dart               # item in the recent-lookups list
        │   └── repositories/
        │       └── lookup_repository.dart            # abstract interface (domain knows nothing about implementations)
        ├── data/
        │   ├── datasources/
        │   │   ├── arp_local_datasource.dart          # ARP table lookup + parsing
        │   │   ├── network_interface_datasource.dart  # auto-detect this machine's active IP
        │   │   └── lookup_remote_datasource.dart      # calls the Rails API (via Dio)
        │   ├── models/
        │   │   └── lookup_result_model.dart            # fromJson/toJson, maps to the domain entity
        │   └── repositories/
        │       └── lookup_repository_impl.dart          # implements the domain interface (composes the datasources)
        └── presentation/
            ├── providers/                                # FEATURE-specific providers only
            │   ├── lookup_repository_provider.dart         # repository DI (wires up the datasources)
            │   ├── lookup_controller_provider.dart          # AsyncNotifier — lookup state
            │   └── recent_lookups_provider.dart              # FutureProvider — recent list
            ├── screens/
            │   └── lookup_screen.dart
            └── widgets/
                ├── lookup_input_field.dart
                ├── lookup_result_card.dart
                └── recent_lookups_list.dart
```

Dependency direction: `presentation → domain ← data` (domain never imports another layer). `lookup_repository_provider` composes `arp_local_datasource` + `network_interface_datasource` + `lookup_remote_datasource` into a `LookupRepositoryImpl`; `lookup_controller_provider` only ever sees the domain `LookupRepository` interface, so tests can swap in a mock repository easily. There's only one feature (`lookup`) right now so root `providers/` is sparse, but the structure scales cleanly as features are added.

### 3.2 ARP Lookup
In `features/lookup/data/datasources/arp_local_datasource.dart`, run `Process.run('arp', ['-a'])` and parse the platform-specific output:
- macOS: `? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ...`
- Linux: `192.168.1.1 (192.168.1.1) at aa:bb:cc:dd:ee:ff [ether] on eth0`
- Windows isn't explicitly named as the desktop target in the brief; since development is happening on macOS, treat macOS as the primary target and cover the Linux format as best-effort. (Note "tested on macOS" in the README in case the reviewer runs it on Windows.)
- Keep the parsing logic as a pure function (`parseArpOutput(String raw)`), separate from the `Process.run` call, so it's unit-testable without actually spawning a process
- On parse failure / no ARP entry → show the user a clear error ("this IP isn't visible on the local network")

### 3.3 Auto IP Detection (bonus challenge)
In `features/lookup/data/datasources/network_interface_datasource.dart`, use `NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4)` to grab the first active IPv4 address and pre-fill the input field (still editable by the user).

### 3.4 Screen Layout
- Input field (IP) + "Look up" button (works immediately with the pre-filled IP)
- Result card: IP / MAC / Vendor, with clearly distinguished loading/error states
- "Recent lookups" list (sourced from Rails `GET /lookups`) — a manual refresh button instead of pull-to-refresh, since this is desktop

### 3.5 Tests
- Unit tests for `lookup_controller_provider` (mock `LookupRepository` via mocktail — mocking only the domain interface)
- Unit tests for `arp_local_datasource`'s `parseArpOutput` pure function (verify parsing against sample output strings, no real process execution)
- Unit tests for `lookup_repository_impl` (verify it correctly maps composed mock datasources into domain entities)
- 1-2 widget tests (input → result display flow, overriding `lookup_repository_provider` with a mock)

## 4. Required Packages

### 4.1 Flutter (`pubspec.yaml`)
- `flutter_riverpod` — core state management
- `riverpod_annotation` + `riverpod_generator` + `build_runner` (dev) — only if using code generation. Given the scope, it's fine to skip these and use `Provider`/`AsyncNotifierProvider` manually to save setup time
- `dio` — HTTP client for calling the Rails API (interceptors make error handling clean; the `http` package is a fine substitute)
- `freezed` + `freezed_annotation` + `json_serializable` (dev: `build_runner`) — for immutable response models (`LookupResult`, etc.). Also optional — a hand-written `fromJson` works fine too
- `mocktail` (dev) — for mocking in Riverpod provider / ARP service unit tests
- `flutter_test` — included with the SDK, for widget tests
- ARP lookup (`dart:io` Process) and auto IP detection (`dart:io` NetworkInterface) are both built into the SDK — no extra package needed

### 4.2 Rails (`Gemfile`)
- `rails` (generated in `--api` mode)
- `pg` — if using Postgres (`sqlite3` is a fine, simpler alternative; the brief doesn't specify a database)
- `faraday` — for calling the external vendor lookup API (`net/http` directly also works, but Faraday makes timeout/error handling cleaner)
- `rack-cors` — not actually needed if the Flutter app only runs as a native desktop build (CORS is a browser-enforced concept), but worth adding in case of testing via `flutter run -d chrome`

Test group:
- `rspec-rails`
- `webmock` — stub the external vendor API call (fully block real network calls during tests)
- `factory_bot_rails` — factory for `Lookup` records
- `shoulda-matchers` (optional) — makes validation specs concise

## 5. Build Order (Milestones)

1. Rails: project setup, `Lookup` model + migration, `VendorLookupService` (test-first with RSpec, WebMock stub fixtures ready)
2. Rails: `POST /lookups`, `GET /lookups` controllers + request specs
3. Flutter: project setup, Riverpod structure, API client
4. Flutter: ARP parser + unit tests (as a pure function, testable without spawning a process)
5. Flutter: assemble the screen (input → ARP lookup → call Rails → show result → recent list)
6. Add auto IP detection
7. Sweep through error cases (no ARP entry, vendor API down, invalid IP format, etc.)
8. Write README + AI_USAGE.md, verify both projects run end-to-end locally
9. Create the GitHub public repo, push, send the invite

## 6. Preparing for "How did you use AI?"

Since the brief explicitly says this will come up in the interview, log it in `docs/AI_USAGE.md` as you go:
- What you asked the AI to do and with what prompt (e.g. "had Claude draft the ARP parser, then fixed the macOS format edge cases myself")
- What you kept as-is from the AI's output vs. what you rewrote
- Where the AI got something wrong or needed correcting (e.g. "it initially missed vendor API error handling, so I explicitly asked it to add that")

Do this incrementally — a line or two after each milestone — rather than trying to reconstruct it all from memory after coding is done. It's both easier in practice and more convincing in the interview.
