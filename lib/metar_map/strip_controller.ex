defmodule MetarMap.StripController do
  use GenServer
  require Logger
  alias MetarMap.Timeline

  @channel 0
  @render_interval_ms 20
  @brightness_transition_ms 500

  def start_link(prefs) do
    GenServer.start_link(__MODULE__, prefs, name: __MODULE__)
  end

  def put_prefs(prefs) do
    GenServer.cast(__MODULE__, {:put_prefs, prefs})
  end

  def init(opts) do
    prefs = Keyword.fetch!(opts, :prefs)

    initial_state = %{
      prefs: prefs,
      brightness_timeline:
        Timeline.init(preferred_brightness(prefs), {MetarMap.Interpolation, :integers}),
      latest_brightness: preferred_brightness(prefs),
      room: :bright
    }

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
    next_room = room_designation(state.prefs, ldr_brightness)
    next_state = %{state | room: next_room}

    if next_room != state.room do
      Logger.info("[StripController] Room went #{state.room} -> #{next_room}")
    end

    {:noreply, put_brightness_transition(next_state)}
  end

  defp put_brightness_transition(state) do
    # TODO: Averaging? Hysterisis?
    dimmed_brightness = trunc(preferred_brightness(state.prefs) * room_factor(state.room))

    next_timeline =
      Timeline.append(state.brightness_timeline, @brightness_transition_ms, dimmed_brightness)

    %{state | brightness_timeline: next_timeline}
  end

  defp preferred_brightness(prefs) do
    trunc(prefs.brightness_pct / 100 * 255)
  end

  defp room_designation(prefs, ldr_brightness) do
    cond do
      ldr_brightness < prefs.dark_room_intensity + 0.1 -> :dark
      ldr_brightness > prefs.bright_room_intensity - 0.1 -> :bright
      true -> :normal
    end
  end

  defp room_factor(:dark), do: 0.5
  defp room_factor(:normal), do: 0.75
  defp room_factor(:bright), do: 1.0
end
