defmodule MetarMap.StripController do
  use GenServer

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
      ldr_brightness: 1.0,
      brightness_timeline:
        Timeline.init(preferred_brightness(prefs), {MetarMap.Interpolation, :integers}),
      latest_brightness: preferred_brightness(prefs)
    }

    send(self(), :render)

    {:ok, initial_state}
  end

  def handle_cast({:put_prefs, prefs}, state) do
    next_state = transition_brightness(%{state | prefs: prefs})

    {:noreply, next_state}
  end

  def handle_info(:render, state) do
    next_brightness = Timeline.evaluate(state.brightness_timeline)

    if next_brightness != state.latest_brightness do
      Blinkchain.set_brightness(@channel, next_brightness)
    end

    Blinkchain.render()

    Process.send_after(self(), :render, @render_interval_ms)

    {:noreply, %{state | latest_brightness: next_brightness}}
  end

  def handle_info({:ldr_brightness, brightness}, state) do
    next_state = transition_brightness(%{state | ldr_brightness: brightness})

    {:noreply, next_state}
  end

  defp transition_brightness(state) do
    # TODO: Averaging? Hysterisis?
    dimmed_brightness = trunc(preferred_brightness(state.prefs) * state.ldr_brightness)

    next_timeline =
      Timeline.append(state.brightness_timeline, @brightness_transition_ms, dimmed_brightness)

    %{state | brightness_timeline: next_timeline}
  end

  defp preferred_brightness(prefs) do
    trunc(prefs.brightness_pct / 100 * 255)
  end
end
