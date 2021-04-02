# FindSiteIcon

Finds a large icon for a website given a URL.

## Usage
```elixir
case FindSiteIcon.find_icon(url, opts) do
  {:ok, icon_url} -> # A usable icon_url
  {:error, reason} -> # Reason for why the icon_url could not be fetched.
```

`opts` is an optional keyword list.
* `html` -> If provided, it does not need to fetch the html for the url, to extract the icons.
* `default_icon_url` -> Will be used if no valid icon_url found. Response is always {:ok, icon_url || default_icon_url} in this case.

## Installation

The package can be installed by adding `find_site_icon` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:find_site_icon, "~> 0.3.8"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/find_site_icon](https://hexdocs.pm/find_site_icon).
