defmodule FindSiteIcon.Cache do
  @moduledoc """
  Cache for holding all the icons for websites. Ensures that we don't have to
  make unnecessary api calls.
  """
  use GenServer

  alias FindSiteIcon.IconInfo
  alias FindSiteIcon.Util.IconUtils

  # ETS used only for read concurrency
  @ets_table :find_site_icon

  def ets_table, do: @ets_table

  def get(url) when is_binary(url) do
    # We only store one site_icon per host for now
    host = extract_host(url)

    case :ets.lookup(@ets_table, host) do
      [{^host, %IconInfo{url: icon_url}}] = [{^host, stored_icon_info}] ->
        if stored_icon_valid?(stored_icon_info, url) do
          icon_url
        else
          update(url, nil)
          nil
        end

      _ ->
        nil
    end
  end

  def update(url, %IconInfo{} = icon_info) when is_binary(url) do
    host = extract_host(url)

    :ets.insert(@ets_table, {host, icon_info})
  end

  def update(_url, _), do: nil

  defp stored_icon_valid?(
         %IconInfo{url: icon_url, expiration_timestamp: expiration_timestamp},
         url
       ) do
    if IconUtils.unexpired?(expiration_timestamp) do
      true
    else
      icon_info = IconUtils.icon_info_for(icon_url)
      update(url, icon_info)
      !!icon_info
    end
  end

  defp stored_icon_valid?(_, _), do: false

  def extract_host(url) when is_binary(url) do
    # path is used in case url is provided without scheme, in which case the host can't be parsed
    %URI{host: host, path: path} = URI.parse(url)
    host || path
  end

  def start_link(default) when is_list(default) do
    GenServer.start_link(__MODULE__, default)
  end

  @impl true
  def init(_init_arg) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])
    {:ok, :empty}
  end
end
