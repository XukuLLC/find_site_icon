[![Hex.pm](https://img.shields.io/hexpm/v/find_site_icon)](https://hex.pm/packages/find_site_icon)
[![Hexdocs.pm](https://img.shields.io/badge/docs-hexdocs.pm-blue)](https://hexdocs.pm/find_site_icon)
[![GitHub Actions](https://github.com/XukuLLC/find_site_icon/actions/workflows/elixir.yml/badge.svg)](https://github.com/XukuLLC/find_site_icon/actions/workflows/elixir.yml)

# FindSiteIcon

Find a usable, high-quality icon for a website URL.

`FindSiteIcon` fetches a page, extracts known icon links, adds common fallback locations, probes the candidates, and returns the best icon URL it can validate. It is built on [Req](https://hexdocs.pm/req) and keeps the public API small enough to use directly in application code.

## Installation

Add `find_site_icon` to your dependencies:

```elixir
def deps do
  [
    {:find_site_icon, "~> 1.0"}
  ]
end
```

## Quick Start

```elixir
case FindSiteIcon.find_icon("https://nytimes.com") do
  {:ok, icon_url} ->
    icon_url

  {:error, reason} ->
    reason
end
```

If you already have the page HTML, pass it in to avoid an extra fetch:

```elixir
FindSiteIcon.find_icon("https://example.com/article", html: html)
```

For hot paths, cap the whole lookup:

```elixir
FindSiteIcon.find_icon("https://example.com", timeout: 3_000)
```

## Options

| Option | What it does |
| --- | --- |
| `:html` | Uses caller-provided HTML instead of fetching the page first. |
| `:default_icon_url` | Returns `{:ok, default_icon_url}` when no valid icon is found. |
| `:timeout` | Caps the whole lookup and applies the same timeout to internal HTTP requests. |
| `:http_options` | Passes Req options to the internal HTTP client. |
| `:max_concurrency` | Limits concurrent icon probes. Defaults to `8`. |
| `:max_icons` | Limits how many candidate icon URLs are probed. Defaults to no limit. |

## What It Checks

- HTML icon links: `apple-touch-icon`, `apple-touch-icon-precomposed`, `shortcut icon`, and `icon`.
- Common fallback locations such as `/apple-touch-icon.png`, `/favicon.png`, and `/favicon.ico`.
- PNG, JPEG, WebP, SVG, and ICO icon URLs.
- Response metadata with a HEAD-first request, falling back to GET when needed.
- `cache-control: max-age` for cache expiration when the server provides it.

## Development

```sh
mix deps.get
mix test
mix credo --strict
mix dialyzer
```

The live website smoke test is tagged `:external` so regular test runs do not depend on the public internet:

```sh
mix test --include external
```

Documentation is available at [hexdocs.pm/find_site_icon](https://hexdocs.pm/find_site_icon).
