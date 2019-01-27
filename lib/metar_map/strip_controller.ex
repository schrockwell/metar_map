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

    send(self(), :render)
    set_brightness(prefs)
    {:ok, %{prefs: prefs}}
  end

  def handle_cast({:put_prefs, prefs}, state) do
    set_brightness(prefs)
    {:noreply, %{state | prefs: prefs}}
  end

  def handle_info(:render, state) do
    Blinkchain.render()
    Process.send_after(self(), :render, @render_interval_ms)
    {:noreply, state}
  end

  defp set_brightness(prefs) do
    brightness = trunc(prefs.brightness_pct / 100 * 255)
    :ok = Blinkchain.set_brightness(@channel, brightness)
  end
end
