defmodule MetarMap.LdrSensor do
  use GenServer

  alias Circuits.GPIO

  # The duration to force 0 output to discharge the capacitor
  @pulse_duration_ms 100

  # The duration after the pulse to wait for a rising edge
  @read_duration_ms 600

  # Process to notify of LDR changes
  @notify_server MetarMap.StripController

  # Use the median of X LDR readings
  @ldr_averaging 5

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
       rise_times: []
     }}
  end

  def handle_call(:read, _, state) do
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

  # If we get a rising edge but haven't detected the pulse falling edge yet, then do nothing
  def handle_info({:gpio, _pin_number, _timestamp_ns, 1}, %{pulsed_at_ns: nil} = state),
    do: {:noreply, state}

  # When transitioning to 1 after pulsing, record the timestamp and determine the rise time
  def handle_info({:gpio, _pin_number, timestamp_ns, 1}, %{pulsed: true} = state) do
    rise_time_ms = trunc((timestamp_ns - state.pulsed_at_ns) / 1_000_000) - @pulse_duration_ms
    rise_times = append_rise_time(state.rise_times, rise_time_ms)

    state = %{state | pulsed_at_ns: nil, rise_times: rise_times, pulsed: false}

    # IO.puts("Median rise time: #{median(rise_times)}ms")

    send(@notify_server, {:ldr_brightness, normalize_value(state)})

    {:noreply, state}
  end

  # Ignore all other transitions (lazy debounce)
  def handle_info({:gpio, _pin_number, _timestamp, _value}, state) do
    {:noreply, state}
  end

  defp normalize_value(state) do
    # Inverse relationship: bright => lower resistance => faster rise time
    (1.0 - median(state.rise_times) / @read_duration_ms) |> max(0.0) |> min(1.0)
  end

  def median(list) do
    list |> Enum.sort() |> Enum.at(trunc(length(list) / 2))
  end

  defp append_rise_time(list, rise_time) when length(list) < @ldr_averaging do
    list ++ [rise_time]
  end

  defp append_rise_time([_head | tail], rise_time) do
    tail ++ [rise_time]
  end
end
