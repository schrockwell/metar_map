defmodule MetarMap.LedController do
  use GenServer
  require Logger

  alias Blinkchain.Color
  alias MetarMap.{Station, Timeline}

  @frame_interval_ms 40
  @fade_duration_ms 1500
  @wipe_duration_ms 2000
  @flicker_probability 0.2
  @flicker_brightness 0.7

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
    defstruct [
      :station,
      :timeline,
      :prefs,
      :latest_color,
      :initialized,
      :pixel,
      :flicker
    ]
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

    trigger_frame()

    {:ok,
     %State{
       station: station,
       prefs: prefs,
       timeline: Timeline.init(@colors.off, {MetarMap.Interpolation, :blend_colors}),
       initialized: false,
       pixel: {station.index, 0}
     }}
  end

  def handle_cast({:put_metar, metar, bounds}, state) do
    next_station =
      state.station
      |> Station.put_metar(metar)
      |> put_station_position(metar, bounds)

    Logger.debug(
      Enum.join(
        [
          "[#{next_station.id}]",
          next_station |> Station.get_category() |> Atom.to_string() |> String.upcase(),
          "#{Station.get_max_wind(next_station)} kts"
        ],
        " "
      )
    )

    if Station.get_category(next_station) == :unknown do
      Logger.warn("[#{next_station.id}] Flight category unknown")
    end

    next_state = %{state | station: next_station, initialized: true}
    delay_ms = if state.initialized, do: 0, else: wipe_delay_ms(next_state)

    trigger_frame()

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

    trigger_frame()

    {:noreply, %{state | prefs: new_prefs, timeline: timeline}}
  end

  def handle_info(:frame, state) do
    is_flickering = is_windy?(state)

    # Kick off the next frame ASAP if necessary
    if is_flickering or !Timeline.empty?(state.timeline) do
      trigger_frame(@frame_interval_ms)
    end

    {color, timeline} = Timeline.evaluate(state.timeline)

    # Randomly toggle the flickering if it's windy
    next_flicker =
      cond do
        !is_flickering -> false
        :rand.uniform() < @flicker_probability -> !state.flicker
        true -> state.flicker
      end

    # If flickering, dim it to 80%
    color = if next_flicker, do: MetarMap.brighten(color, @flicker_brightness), else: color

    # For performance - only update if necessary
    if color != state.latest_color do
      Blinkchain.set_pixel(state.pixel, color)
    end

    {:noreply, %{state | timeline: timeline, latest_color: color, flicker: next_flicker}}
  end

  def terminate(_, state) do
    Blinkchain.set_pixel(state.pixel, @colors.off)
  end

  defp update_station_color(state, opts) do
    next_color = station_color(state.station, state.prefs.mode)

    if next_color != state.timeline.latest_value do
      delay_ms = Keyword.get(opts, :delay_ms, 0)
      duration_ms = Keyword.get(opts, :duration_ms, @fade_duration_ms)
      timeline = Timeline.append(state.timeline, duration_ms, next_color, min_delay_ms: delay_ms)
      %{state | timeline: timeline}
    else
      state
    end
  end

  @wind_speed_gradient [
    {5, @colors.green},
    {10, @colors.yellow},
    {25, @colors.red},
    {35, @colors.purple},
    {50, @colors.white}
  ]

  @ceiling_gradient [
    {1000, @colors.red},
    {3000, @colors.orange},
    {5000, @colors.yellow},
    {10000, @colors.green}
  ]

  @visiblity_gradient [
    {1, @colors.red},
    {3, @colors.orange},
    {5, @colors.yellow},
    {10, @colors.green}
  ]

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
    MetarMap.blend_gradient(@wind_speed_gradient, Station.get_max_wind(station), @colors.off)
  end

  defp station_color(station, "ceiling") do
    MetarMap.blend_gradient(@ceiling_gradient, Station.get_ceiling(station), @colors.off)
  end

  defp station_color(station, "visibility") do
    MetarMap.blend_gradient(@visiblity_gradient, Station.get_visibility(station), @colors.off)
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

  defp is_windy?(state) do
    state.prefs.max_wind_kts > 0 and
      Station.get_max_wind(state.station) >= state.prefs.max_wind_kts
  end

  defp trigger_frame() do
    send(self(), :frame)
  end

  defp trigger_frame(delay_ms) do
    Process.send_after(self(), :frame, delay_ms)
  end
end
