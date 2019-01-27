defmodule MetarMap.MetarFetcher do
  use GenServer
  require Logger

  alias MetarMap.{AviationWeather, Metar, LedController}

  @poll_interval_ms 60_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    station_list = Keyword.fetch!(opts, :stations)
    station_ids = Enum.map(station_list, & &1.id)

    send(self(), :poll)

    {:ok, %{station_ids: station_ids}}
  end

  @impl true
  def handle_info(:poll, state) do
    state.station_ids
    |> AviationWeather.fetch_latest_metars()
    |> case do
      {:ok, metars} ->
        bounds = Metar.find_bounds(metars)

        for metar <- metars do
          if LedController.exists?(metar.station_id) do
            LedController.put_metar(metar, bounds)
          else
            Logger.warn("[MetarFetcher] Could not find LED for #{metar.station_id}")
          end
        end

      _ ->
        Logger.warn("[MetarFetcher] Error fetching METARs")
    end

    Process.send_after(self(), :poll, @poll_interval_ms)

    {:noreply, state}
  end
end
