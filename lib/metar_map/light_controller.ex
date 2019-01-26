defmodule MetarMap.LightController do
  use GenServer

  alias Blinkchain.Color
  alias MetarMap.{Station, Preferences}

  @channel 0
  @frame_interval_ms 20
  @fade_in_delay_ms 250
  @fade_duration_ms 1500

  defmodule Led do
    defstruct [:latest_color, :transitions, :index]
  end

  defmodule Transition do
    defstruct [:start_at, :start_color, :end_at, :end_color]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def render_stations(stations) do
    GenServer.cast(__MODULE__, {:render_stations, stations})
  end

  @impl true
  def init(_opts) do
    # Reset the LEDs to be all off
    prefs = Preferences.load()
    :ok = Blinkchain.set_brightness(@channel, prefs.brightness)
    Blinkchain.render()

    # Kick off animations
    send(self(), :tick)

    # Kick off max wind flashing
    send(self(), :check_winds)

    {:ok,
     %{
       leds: %{},
       first_render: true,
       latest_stations: []
     }}
  end

  @impl true
  def handle_cast({:render_stations, stations}, %{first_render: true} = state) do
    stations |> Enum.map(&{&1.id, Station.get_category(&1)}) |> IO.inspect()

    # Build the map
    leds =
      stations
      |> Enum.map(
        &{&1.index,
         %Led{
           index: &1.index,
           latest_color: color(:off),
           transitions: []
         }}
      )
      |> Map.new()

    # Do the fade-in effect
    leds =
      stations
      |> Enum.with_index()
      |> Enum.reduce(leds, fn {station, i}, leds ->
        set_station_color(leds, station, delay_ms: i * @fade_in_delay_ms)
      end)

    Blinkchain.render()

    {:noreply, %{state | leds: leds, first_render: false, latest_stations: stations}}
  end

  @impl true
  def handle_cast({:render_stations, stations}, state) do
    # The list of stations we get here should be already sorted by index
    stations |> Enum.map(&{&1.id, Station.get_category(&1)}) |> IO.inspect()

    leds = Enum.reduce(stations, state.leds, &set_station_color(&2, &1))

    Blinkchain.render()

    {:noreply, %{state | leds: leds, first_render: false, latest_stations: stations}}
  end

  @impl true
  def handle_info(:tick, state) do
    # Do the animations here
    leds = apply_transitions(state.leds)
    Blinkchain.render()

    Process.send_after(self(), :tick, @frame_interval_ms)

    {:noreply, %{state | leds: leds}}
  end

  def handle_info(:check_winds, state) do
    prefs = Preferences.load()

    if prefs.max_wind_kts > 0 do
      leds =
        Enum.reduce(state.latest_stations, state.leds, fn station, leds ->
          if Station.get_max_wind(station) >= prefs.max_wind_kts and
               state.leds[station.index].transitions == [] do
            leds
            |> schedule_transition(station.index, 0, @fade_duration_ms, color(:off))
            |> schedule_transition(
              station.index,
              @fade_duration_ms + 100,
              @fade_duration_ms,
              color(station)
            )
          else
            leds
          end
        end)

      Process.send_after(self(), :check_winds, prefs.wind_flash_interval_ms)
      {:noreply, %{state | leds: leds}}
    else
      Process.send_after(self(), :check_winds, prefs.wind_flash_interval_ms)
      {:noreply, state}
    end
  end

  defp now_ms, do: :erlang.monotonic_time(:millisecond)

  # Gets the color for a flight category
  defp color(%Station{} = station) do
    station |> Station.get_category() |> color()
  end

  defp color(:vfr), do: %Color{r: 0, g: 0xFF, b: 0}
  defp color(:mvfr), do: %Color{r: 0, g: 0, b: 0xFF}
  defp color(:ifr), do: %Color{r: 0xFF, g: 0, b: 0}
  defp color(:lifr), do: %Color{r: 0xFF, g: 0, b: 0xFF}
  defp color(:off), do: %Color{r: 0, g: 0, b: 0}
  defp color(_), do: %Color{r: 0, g: 0, b: 0}

  # Schedules an LED color transitions 
  defp set_station_color(leds, %Station{index: index} = station, opts \\ []) do
    target_color = color(station)

    if leds[index].latest_color == target_color do
      leds
    else
      delay_ms = Keyword.get(opts, :delay_ms, 0)
      duration_ms = Keyword.get(opts, :duration_ms, @fade_duration_ms)
      schedule_transition(leds, index, delay_ms, duration_ms, target_color)
    end
  end

  # Puts an LED transition in the queue. Note that the LED will flicker weirdly if 
  # transitions overlap in time for a given LED. Just… don't do that, okay?
  defp schedule_transition(leds, index, delay_ms, duration_ms, color) do
    start_at = now_ms() + delay_ms
    start_color = leds[index].latest_color
    end_at = start_at + duration_ms
    end_color = color

    transition = %Transition{
      start_at: start_at,
      start_color: start_color,
      end_at: end_at,
      end_color: end_color
    }

    leds
    |> Map.update!(index, fn led ->
      %{led | transitions: [transition | led.transitions], latest_color: end_color}
    end)
  end

  # This does the actual transition interpolation and animation
  defp apply_transitions(leds) do
    now = now_ms()

    leds
    |> Enum.map(fn {index, led} ->
      next_transitions =
        Enum.flat_map(led.transitions, fn transition ->
          cond do
            transition.end_at < now ->
              # The transition has passed - set the end color and discard it
              :ok = Blinkchain.set_pixel({index, 0}, transition.end_color)
              []

            transition.start_at > now ->
              # The transition has not yet begun
              [transition]

            true ->
              # Figure out the progress (0.0 to 1.0) and blend the colors, then apply it
              progress = (now - transition.start_at) / (transition.end_at - transition.start_at)
              color = blend(transition.start_color, transition.end_color, progress)
              :ok = Blinkchain.set_pixel({index, 0}, color)
              [transition]
          end
        end)

      # Some transitions might have gone away, so update the list
      {index, %{led | transitions: next_transitions}}
    end)
    |> Map.new()
  end

  # Naively blends two colors
  defp blend(from_color, to_color, to_factor) do
    from_factor = 1.0 - to_factor

    %Color{
      r: trunc(from_color.r * from_factor + to_color.r * to_factor),
      g: trunc(from_color.g * from_factor + to_color.g * to_factor),
      b: trunc(from_color.b * from_factor + to_color.b * to_factor),
      w: trunc(from_color.w * from_factor + to_color.w * to_factor)
    }
  end
end
