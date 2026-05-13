# Changelog

## 1.0.0 - 2026-05-13

### Changed

- Replaced Tesla with a small Req-based HTTP wrapper.
- Added `:timeout` to cap an entire icon lookup and pass the same timeout to internal HTTP requests.
- Added `:http_options`, `:max_concurrency`, and `:max_icons` options.
- Probes icon metadata with HEAD first and falls back to GET when needed.
- Parses `cache-control: max-age` for cached icon expiration.
- Tags live website smoke coverage as `:external` so normal test runs are deterministic.

### Added

- SVG and WebP icon URL support.
- Bypass-backed HTTP wrapper tests.
- Quokka formatting, Credo configuration, Dialyzer, and GitHub Actions CI.
- Expanded README with badges, option docs, and hot-path timeout guidance.

### Removed

- Tesla and Mint direct dependencies.
