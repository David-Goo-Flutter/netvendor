# netvendor_api (Rails API)

The API half of NetVendor: resolves a MAC address to its hardware vendor (with caching and a
fallback provider) and persists each lookup.

See the [top-level README](../README.md) for the full picture — architecture, endpoint table,
the `GET`/`POST` split rationale, and how to run both halves together. Quick start:

```bash
bundle install
bin/rails db:create db:migrate
bin/rails server          # http://localhost:3000
bundle exec rspec         # 81 examples
```
