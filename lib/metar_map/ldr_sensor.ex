defmodule MetarMap.LdrSensor do
  use GenServer

  alias Circuits.GPIO

  @pulse_duration_ms 100
  @read_duration_ms 600
  @notify MetarMap.StripController

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def read() do
    GenServer.call(__MODULE__, :read)
  end

  def available?() do
    !!Process.whereis(__MODULE__)
  end

  def init(opts) do
    gpio_pin = Keyword.fetch!(opts, :gpio_pin)

    send(self(), :start_pulse)

    {:ok, gpio} = GPIO.open(gpio_pin, :output)

    GPIO.set_interrupts(gpio, :both)

    {:ok,
     %{
       gpio: gpio,
       pulsed: false,
       pulsed_at_ns: nil,
       rise_time_ms: 0
     }}
  end

  def handle_cast(:read, _, state) do
    {:reply, normalize_value(state), state}
  end

  def handle_info(:poll, state) do
    {:noreply, state}
  end

  def handle_info(:start_pulse, state) do
    :ok = GPIO.set_direction(state.gpio, :output)
    :ok = GPIO.write(state.gpio, 0)

    Process.send_after(self(), :end_pulse, @pulse_duration_ms)

    {:noreply, %{state | pulsed: true}}
  end

  def handle_info(:end_pulse, state) do
    :ok = GPIO.set_direction(state.gpio, :input)

    Process.send_after(self(), :start_pulse, @read_duration_ms)

    {:noreply, state}
  end

  # When transitioning to 0 afer pulsing, record the timestamp
  def handle_info({:gpio, _pin_number, timestamp_ns, 0}, %{pulsed: true} = state) do
    {:noreply, %{state | pulsed_at_ns: timestamp_ns}}
  end

  # When transitioning to 1 after pulsing, record the timestamp and determine the rise time
  def handle_info({:gpio, _pin_number, timestamp_ns, 1}, %{pulsed: true} = state) do
    rise_time_ms = trunc((timestamp_ns - state.pulsed_at_ns) / 1_000_000) - @pulse_duration_ms
    state = %{state | pulsed_at_ns: nil, rise_time_ms: rise_time_ms, pulsed: false}

    send(@notify, {:ldr_brightness, normalize_value(state)})

    {:noreply, state}
  end

  # Ignore all other transitions (lazy debounce)
  def handle_info({:gpio, _pin_number, _timestamp, _value}, state) do
    {:noreply, state}
  end

  defp normalize_value(state) do
    # Inverse relationship: bright => lower resistance => faster rise time
    (1.0 - state.rise_time_ms / @read_duration_ms) |> max(0.0) |> min(1.0)
  end
end
