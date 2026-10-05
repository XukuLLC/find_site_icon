# Changelog

## 1.1.0 - 2026-10-05

### Fixed

- Stopped passing `:pool_max_idle_time` to Req as a top-level option. Req 0.7 deprecated it in favour of `finch: [pool_max_idle_time: ...]`, and because `IO.warn/1` attaches a stacktrace to every occurrence, a single icon lookup emitted dozens of multi-line warnings to stderr. `:connect_options`, `:inet6` and `:pool_max_idle_time` are now folded into one `:finch` keyword list via `Req.Finch.pool_options/1`, which produces identical Finch pool options.

### Added

- `FindSiteIcon.Util.HTTPUtils.new/1` accepts `:finch` options, merged over the computed pool options. `finch: [name: MyFinch]` is taken verbatim and the library's pool defaults are not applied, since Req rejects pool options next to a pool name. Previously any `finch:` option raised, because `:connect_options` was always set alongside it.

### Changed

- Requires Req `~> 0.7`. `finch: [pool_options]` and `Req.Finch.pool_options/1` were both introduced in Req 0.7.0, so the fix cannot be expressed on 0.5/0.6.
- `do_get/3` and `do_head/3` now translate only the options they are handed, layering them over whatever the request already carries. A prebuilt `Req.Request` keeps its pool settings instead of reverting to the defaults.

## 1.0.3 - 2026-06-29

### Fixed

- Enabled Req response decompression by default so compressed pages and icons continue to be decoded correctly with Req 0.6+. ([#17](https://github.com/XukuLLC/find_site_icon/issues/17))
- Declared Elixir 1.20 support in package metadata after adding it to CI.

## 1.0.2 - 2026-05-18

### Fixed

- Set a finite default `pool_max_idle_time` (30 seconds) for the internal Req/Finch HTTP client so idle connections release their file descriptors. Without this, processing large lists of distinct hosts could exhaust the per-process open-file limit and silently truncate results or crash the BEAM. ([#15](https://github.com/XukuLLC/find_site_icon/issues/15))

### Added

- New `:pool_max_idle_time` option on `FindSiteIcon.find_icon/2` so callers can override the default 30-second Finch idle-pool timeout per call. Accepts a positive integer in milliseconds or `:infinity` (which restores Req's pre-1.0.2 behaviour of keeping idle pools alive forever).

## 1.0.1 - 2026-05-16

### Fixed

- Restored v0.x behavior of probing all candidate icon URLs by default. v1.0.0 accidentally capped candidates at 20 unless callers overrode `:max_icons`.
- Fixed header parsing for Req responses, which store headers as a map of header names to value lists.
- Fall back to GET when a HEAD response succeeds but reports a non-image content type or zero content length.
- Return a smaller non-empty icon when every discovered candidate is below the preferred size threshold.
- Include `.ico` icon URLs and `/favicon.ico` as a final fallback.

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
