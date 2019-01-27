defmodule MetarMap.LedController do
  use GenServer
  require Logger

  alias Blinkchain.Color
  alias MetarMap.{Station, Timeline}

  @frame_interval_ms 20
  @fade_duration_ms 1500
  @colors %{
    off: %Color{r: 0, g: 0, b: 0},
    red: %Color{r: 0xFF, g: 0, b: 0},
    orange: %Color{r: 0xFF, g: 0x80, b: 0},
    yellow: %Color{r: 0xFF, g: 0xFF, b: 0},
    green: %Color{r: 0, g: 0xFF, b: 0},
    blue: %Color{r: 0, g: 0, b: 0xFF},
    purple: %Color{r: 0xFF, g: 0, b: 0xFF}
  }

  defmodule State do
    defstruct [:station, :timeline, :prefs, :flash_timer]
  end

  defmodule Transition do
    defstruct [:start_at, :start_color, :end_at, :end_color]
  end

  def start_link(%Station{} = station, prefs) do
    GenServer.start_link(__MODULE__, {station, prefs}, name: name(station.id))
  end

  def put_station(%Station{} = station) do
    station |> name() |> GenServer.cast({:put_station, station})
  end

  def put_prefs(prefs) do
    Registry.dispatch(__MODULE__.Registry, nil, fn entries ->
      for {pid, _id} <- entries do
        GenServer.cast(pid, {:put_prefs, prefs})
      end
    end)
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

    blinkchain_point = {station.index, 0}

    send(self(), :frame)
    send(self(), :flash_winds)

    {:ok,
     %State{
       station: station,
       prefs: prefs,
       timeline: Timeline.init(blinkchain_point)
     }}
  end

  def handle_cast({:put_station, station}, state) do
    Logger.info("[#{station.id}] #{Station.get_category(station)}")

    {:noreply, update_station_color(%{state | station: station})}
  end

  def handle_cast({:put_prefs, new_prefs}, state) do
    # If we change modes, fade out and then back in
    timeline =
      if new_prefs.mode != state.prefs.mode do
        state.timeline
        |> Timeline.append(@fade_duration_ms, @colors.off)
        |> Timeline.append(@fade_duration_ms, station_color(state.station, new_prefs.mode))
      else
        state.timeline
      end

    # Cancel the previous wind check timer, then start it up again with the new interval
    if state.flash_timer do
      Process.cancel_timer(state.flash_timer)
    end

    send(self(), :flash_winds)

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

    flash_timer =
      Process.send_after(self(), :flash_winds, state.prefs.wind_flash_interval_sec * 1000)

    {:noreply, %{state | timeline: next_timeline, flash_timer: flash_timer}}
  end

  def handle_info(:frame, state) do
    Process.send_after(self(), :frame, @frame_interval_ms)
    {color, timeline} = Timeline.interpolate(state.timeline)
    Blinkchain.set_pixel({state.station.index, 0}, color)
    {:noreply, %{state | timeline: timeline}}
  end

  defp update_station_color(state, opts \\ []) do
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
      kts when kts in 6..15 -> MetarMap.blend(@colors.green, @colors.yellow, 6..15, kts)
      kts when kts in 16..25 -> MetarMap.blend(@colors.yellow, @colors.red, 16..25, kts)
      _ -> @colors.red
    end
  end
end
