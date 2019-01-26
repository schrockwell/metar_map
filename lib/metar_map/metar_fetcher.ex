defmodule MetarMap.MetarFetcher do
  use GenServer

  @poll_interval_ms 60_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    filename = Application.get_env(:metar_map, :stations)

    if !filename do
      raise "Missing: `config :metar_map, :stations, \"/some/path.exs\""
    end

    send(self(), :poll)

    stations =
      filename
      |> MetarMap.Station.list()
      |> Enum.map(&{&1.id, &1})
      |> Map.new()

    {:ok, %{stations: stations}}
  end

  @impl true
  def handle_info(:poll, state) do
    state = put_latest_metars(state)

    state.stations
    |> Map.values()
    |> Enum.sort_by(& &1.index)
    |> MetarMap.LightController.render_stations()

    Process.send_after(self(), :poll, @poll_interval_ms)
    {:noreply, state}
  end

  defp put_latest_metars(state) do
    state.stations
    |> Map.keys()
    |> MetarMap.AviationWeather.fetch_latest_metars()
    |> case do
      {:ok, metars} ->
        merge_metars(state, metars)

      {:error, _error} ->
        state
    end
  end

  defp merge_metars(state, metars) do
    metar_station_ids = Enum.map(metars, & &1.station_id)
    config_station_ids = Map.keys(state.stations)
    missing_station_ids = config_station_ids -- metar_station_ids
    extra_station_ids = metar_station_ids -- config_station_ids

    if !Enum.empty?(missing_station_ids) do
      IO.puts("[MetarFetcher] WARNING: Could not find #{Enum.join(missing_station_ids, ", ")}")
    end

    if !Enum.empty?(extra_station_ids) do
      IO.puts("[MetarFetcher] WARNING: Found extra #{Enum.join(extra_station_ids, ", ")}")
    end

    new_stations =
      Enum.reduce(metars, state.stations, fn metar, stations ->
        if Map.has_key?(stations, metar.station_id) do
          Map.update!(stations, metar.station_id, &MetarMap.Station.put_metar(&1, metar))
        else
          stations
        end
      end)

    %{state | stations: new_stations}
  end
end
