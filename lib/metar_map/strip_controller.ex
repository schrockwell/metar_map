defmodule MetarMap.StripController do
  use GenServer

  @channel 0
  @render_interval_ms 20

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
      ldr_brightness: 1.0
    }

    send(self(), :render)
    set_brightness(initial_state)

    {:ok, initial_state}
  end

  def handle_cast({:put_prefs, prefs}, state) do
    next_state = %{state | prefs: prefs}
    set_brightness(next_state)

    {:noreply, next_state}
  end

  def handle_info(:render, state) do
    Blinkchain.render()

    Process.send_after(self(), :render, @render_interval_ms)

    {:noreply, state}
  end

  def handle_info({:ldr_brightness, brightness}, state) do
    next_state = %{state | ldr_brightness: brightness}

    set_brightness(state)

    {:noreply, next_state}
  end

  defp set_brightness(state) do
    preferred_brightness = trunc(state.prefs.brightness_pct / 100 * 255)

    # TODO: Averaging? Hysterisis?
    adjusted_brightness = trunc(preferred_brightness * state.ldr_brightness)

    :ok = Blinkchain.set_brightness(@channel, adjusted_brightness)
  end
end
