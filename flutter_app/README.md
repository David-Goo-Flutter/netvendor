# netvendor (Flutter app)

The desktop half of NetVendor: reads your local ARP table to resolve an IP to a MAC address,
then asks the Rails API (`../rails_api`) for its vendor.

See the [top-level README](../README.md) for the full picture — architecture, how to run both
halves together, and known limitations. Quick start:

```bash
flutter pub get
flutter run -d macos     # the Rails API needs to be running first
flutter test
```
