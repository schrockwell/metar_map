defmodule MetarMap.StripController do
  use GenServer
  require Logger
  alias MetarMap.Timeline

  @channel 0
  @render_interval_ms 40
  @brightness_transition_ms 500

  def start_link(prefs) do
    GenServer.start_link(__MODULE__, prefs, name: __MODULE__)
  end

  def put_prefs(prefs) do
    GenServer.cast(__MODULE__, {:put_prefs, prefs})
  end

  def init(opts) do
    prefs = Keyword.fetch!(opts, :prefs)

    initial_brightness = led_brightness(prefs, :bright)

    initial_state = %{
      prefs: prefs,
      brightness_timeline: Timeline.init(initial_brightness, {MetarMap.Interpolation, :integers}),
      latest_brightness: initial_brightness,
      room: :bright,
      ldr_brightness: 0.0
    }

    Blinkchain.set_brightness(@channel, initial_brightness)

    send(self(), :render)

    {:ok, initial_state}
  end

  def handle_cast({:put_prefs, prefs}, state) do
    {:noreply, update_brightness(%{state | prefs: prefs})}
  end

  def handle_info(:render, state) do
    {next_brightness, next_timeline} = Timeline.evaluate(state.brightness_timeline)

    if next_brightness != state.latest_brightness do
      Blinkchain.set_brightness(@channel, next_brightness)
    end

    Blinkchain.render()

    Process.send_after(self(), :render, @render_interval_ms)

    {:noreply, %{state | latest_brightness: next_brightness, brightness_timeline: next_timeline}}
  end

  def handle_info({:ldr_brightness, ldr_brightness}, state) do
    {:noreply, update_brightness(%{state | ldr_brightness: ldr_brightness})}
  end

  defp update_brightness(state) do
    next_room = designate_room(state)

    if next_room != state.room do
      Logger.info("[StripController] Room went #{state.room} -> #{next_room}")
    end

    next_timeline =
      Timeline.append(
        state.brightness_timeline,
        @brightness_transition_ms,
        led_brightness(state.prefs, next_room)
      )

    %{state | brightness_timeline: next_timeline, room: next_room}
  end

  defp designate_room(state) do
    cond do
      state.ldr_brightness < state.prefs.dark_sensor_pct / 100 -> :dark
      state.ldr_brightness > state.prefs.bright_sensor_pct / 100 -> :bright
      true -> state.room
    end
  end

  defp led_brightness(prefs, room) do
    led_brightness(prefs, room, MetarMap.LdrSensor.available?())
  end

  defp led_brightness(prefs, _, false) do
    prefs.brightness_pct
  end

  defp led_brightness(prefs, :dark, true) do
    trunc(prefs.dark_brightness_pct / 100 * 255)
  end

  defp led_brightness(prefs, :bright, true) do
    trunc(prefs.bright_brightness_pct / 100 * 255)
  end
end
