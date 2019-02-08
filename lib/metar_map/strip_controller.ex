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

    initial_brightness = room_brightness(prefs, :bright)

    initial_state = %{
      prefs: prefs,
      brightness_timeline: Timeline.init(initial_brightness, {MetarMap.Interpolation, :integers}),
      latest_brightness: initial_brightness,
      room: :bright
    }

    Blinkchain.set_brightness(@channel, initial_brightness)

    send(self(), :render)

    {:ok, initial_state}
  end

  def handle_cast({:put_prefs, prefs}, state) do
    next_state = %{state | prefs: prefs}
    {:noreply, put_brightness_transition(next_state)}
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
    next_room = designate_room(state, ldr_brightness)
    next_state = %{state | room: next_room}

    if next_room != state.room do
      Logger.info("[StripController] Room went #{state.room} -> #{next_room}")
    end

    {:noreply, put_brightness_transition(next_state)}
  end

  defp put_brightness_transition(state) do
    next_timeline =
      Timeline.append(
        state.brightness_timeline,
        @brightness_transition_ms,
        room_brightness(state.prefs, state.room)
      )

    %{state | brightness_timeline: next_timeline}
  end

  defp designate_room(state, ldr_brightness) do
    cond do
      ldr_brightness < state.prefs.dark_sensor_pct / 100 -> :dark
      ldr_brightness > state.prefs.bright_sensor_pct / 100 -> :bright
      true -> state.room
    end
  end

  defp room_brightness(prefs, room) do
    room_brightness(prefs, room, MetarMap.LdrSensor.available?())
  end

  defp room_brightness(prefs, _, false) do
    prefs.brightness_pct
  end

  defp room_brightness(prefs, :dark, true) do
    prefs.dark_brightness_pct / 100 * 255
  end

  defp room_brightness(prefs, :bright, true) do
    prefs.bright_brightness_pct / 100 * 255
  end
end
