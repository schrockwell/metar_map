defmodule MetarMap.MetarFetcher do
  use GenServer

  @poll_interval_ms 60_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    %{stations: stations} = opts |> Keyword.fetch!(:config_file) |> MetarMap.Config.load_file()

    send(self(), :poll)

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
    new_stations =
      Enum.reduce(metars, state.stations, fn metar, stations ->
        Map.update!(stations, metar.station_id, &MetarMap.Station.put_metar(&1, metar))
      end)

    %{state | stations: new_stations}
  end
end
