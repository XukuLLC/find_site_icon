# Changelog

## 1.0.1 - 2026-05-16

### Fixed

- Restored v0.x behavior of probing all candidate icon URLs by default. v1.0.0 accidentally capped candidates at 20 unless callers overrode `:max_icons`.
- Fixed header parsing for Req responses, which store headers as a map of header names to value lists.
- Fall back to GET when a HEAD response succeeds but reports a non-image content type or zero content length.

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
