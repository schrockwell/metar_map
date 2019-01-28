defmodule MetarMap.LedController do
  use GenServer
  require Logger

  alias Blinkchain.Color
  alias MetarMap.{Station, Timeline}

  @frame_interval_ms 20
  @fade_duration_ms 1500
  @wipe_duration_ms 2000

  @colors %{
    off: %Color{r: 0, g: 0, b: 0},
    red: %Color{r: 0xFF, g: 0, b: 0},
    orange: %Color{r: 0xFF, g: 0x80, b: 0},
    yellow: %Color{r: 0xFF, g: 0xFF, b: 0},
    green: %Color{r: 0, g: 0xFF, b: 0},
    blue: %Color{r: 0, g: 0, b: 0xFF},
    purple: %Color{r: 0xFF, g: 0, b: 0xFF},
    white: %Color{r: 0xFF, g: 0xFF, b: 0xFF}
  }

  defmodule State do
    defstruct [:station, :timeline, :prefs, :flash_timer, :latest_color, :initialized, :pixel]
  end

  def start_link(%Station{} = station, prefs) do
    GenServer.start_link(__MODULE__, {station, prefs}, name: name(station.id))
  end

  def put_metar(metar, bounds) do
    metar.station_id |> name() |> GenServer.cast({:put_metar, metar, bounds})
  end

  def put_prefs(prefs) do
    Registry.dispatch(__MODULE__.Registry, nil, fn entries ->
      for {pid, _id} <- entries do
        GenServer.cast(pid, {:put_prefs, prefs})
      end
    end)
  end

  def exists?(id_or_station) do
    !is_nil(id_or_station |> name() |> Process.whereis())
  end

  defp name(%Station{id: id}), do: name(id)
  defp name(id) when is_binary(id), do: Module.concat([__MODULE__, id])

  def child_spec(opts) do
    station = Keyword.fetch!(opts, :station)
    prefs = Keyword.fetch!(opts, :prefs)

    %{
      id: name(station.id),
      start: {__MODULE__, :start_link, [station, prefs]}
    }
  end

  def init({station, prefs}) do
    {:ok, _} = Registry.register(__MODULE__.Registry, nil, station.id)

    send(self(), :frame)
    send(self(), :flash_winds)

    {:ok,
     %State{
       station: station,
       prefs: prefs,
       timeline: Timeline.init(),
       initialized: false,
       pixel: {station.index, 0}
     }}
  end

  def handle_cast({:put_metar, metar, bounds}, state) do
    next_station =
      state.station
      |> MetarMap.Station.put_metar(metar)
      |> put_station_position(metar, bounds)

    Logger.info(
      Enum.join(
        [
          "[#{next_station.id}]",
          next_station |> Station.get_category() |> Atom.to_string() |> String.upcase(),
          "#{Station.get_max_wind(next_station)} kts"
        ],
        " "
      )
    )

    next_state = %{state | station: next_station, initialized: true}
    delay_ms = if state.initialized, do: 0, else: wipe_delay_ms(next_state)

    {:noreply, update_station_color(next_state, delay_ms: delay_ms)}
  end

  def handle_cast({:put_prefs, new_prefs}, state) do
    # If we change modes, fade out and then back in
    timeline =
      if new_prefs.mode != state.prefs.mode do
        state.timeline
        |> Timeline.abort()
        |> Timeline.append(@fade_duration_ms, @colors.off, min_delay_ms: wipe_delay_ms(state))
        |> Timeline.append(@fade_duration_ms, station_color(state.station, new_prefs.mode))
      else
        state.timeline
      end

    # Cancel the previous wind check timer, then start it up again with the new interval
    if state.flash_timer do
      Process.cancel_timer(state.flash_timer)
    end

    # Immediately flash if the wind settings have changed
    if {new_prefs.max_wind_kts, new_prefs.wind_flash_interval_sec} !=
         {state.prefs.max_wind_kts, state.prefs.wind_flash_interval_sec} do
      send(self(), :flash_winds)
    end

    {:noreply, %{state | prefs: new_prefs, flash_timer: nil, timeline: timeline}}
  end

  def handle_info(:flash_winds, %{prefs: %{max_wind_kts: 0}} = state) do
    {:noreply, state}
  end

  def handle_info(:flash_winds, %{prefs: %{mode: mode}} = state) when mode != "flight_category" do
    {:noreply, state}
  end

  def handle_info(:flash_winds, state) do
    # Fade out and back in for windy stations
    next_timeline =
      if Station.get_max_wind(state.station) >= state.prefs.max_wind_kts do
        state.timeline
        |> Timeline.append(@fade_duration_ms, @colors.off)
        |> Timeline.append(@fade_duration_ms, station_color(state.station, state.prefs.mode))
      else
        state.timeline
      end

    next_flash_interval = 2 * @fade_duration_ms + state.prefs.wind_flash_interval_sec * 1000

    flash_timer = Process.send_after(self(), :flash_winds, next_flash_interval)

    {:noreply, %{state | timeline: next_timeline, flash_timer: flash_timer}}
  end

  def handle_info(:frame, state) do
    Process.send_after(self(), :frame, @frame_interval_ms)
    {color, timeline} = Timeline.interpolate(state.timeline)

    # For performance - only update if necessary
    if color != state.latest_color do
      Blinkchain.set_pixel(state.pixel, color)
    end

    {:noreply, %{state | timeline: timeline, latest_color: color}}
  end

  def terminate(_, state) do
    Blinkchain.set_pixel(state.pixel, @colors.off)
  end

  defp update_station_color(state, opts) do
    next_color = station_color(state.station, state.prefs.mode)

    if next_color != state.timeline.latest_color do
      delay_ms = Keyword.get(opts, :delay_ms, 0)
      duration_ms = Keyword.get(opts, :duration_ms, @fade_duration_ms)
      timeline = Timeline.append(state.timeline, duration_ms, next_color, min_delay_ms: delay_ms)
      %{state | timeline: timeline}
    else
      state
    end
  end

  defp station_color(station, "flight_category") do
    station
    |> Station.get_category()
    |> case do
      :vfr -> @colors.green
      :mvfr -> @colors.blue
      :ifr -> @colors.red
      :lifr -> @colors.purple
      _ -> @colors.off
    end
  end

  defp station_color(station, "wind_speed") do
    station
    |> Station.get_max_wind()
    |> case do
      kts when kts in 0..5 -> @colors.green
      kts when kts in 6..10 -> MetarMap.blend(@colors.green, @colors.yellow, 6..10, kts)
      kts when kts in 11..25 -> MetarMap.blend(@colors.yellow, @colors.red, 11..25, kts)
      kts when kts in 26..35 -> MetarMap.blend(@colors.red, @colors.purple, 26..35, kts)
      kts when kts in 36..50 -> MetarMap.blend(@colors.purple, @colors.white, 36..50, kts)
      _ -> @colors.white
    end
  end

  defp station_color(station, "ceiling") do
    station
    |> Station.get_ceiling()
    |> case do
      nil -> @colors.green
      ft when ft in 0..1000 -> @colors.red
      ft when ft in 1000..3000 -> MetarMap.blend(@colors.red, @colors.orange, 1000..3000, ft)
      ft when ft in 3000..5000 -> MetarMap.blend(@colors.orange, @colors.yellow, 3000..5000, ft)
      ft when ft in 5000..10000 -> MetarMap.blend(@colors.yellow, @colors.green, 5000..10000, ft)
      _ -> @colors.green
    end
  end

  defp wipe_delay_ms(%{station: %{position: nil}}), do: 0

  defp wipe_delay_ms(%{station: %{position: {_x, y}}}) do
    # Wipe downwards, so invert y-axis
    trunc(@wipe_duration_ms * (1.0 - y))
  end

  defp put_station_position(
         %{position: nil} = station,
         metar,
         {{min_lat, max_lat}, {min_lon, max_lon}}
       ) do
    x_position = MetarMap.normalize(min_lon, max_lon, metar.longitude)
    y_position = MetarMap.normalize(min_lat, max_lat, metar.latitude)

    %{station | position: {x_position, y_position}}
  end

  defp put_station_position(station, _metar, _bounds), do: station
end
