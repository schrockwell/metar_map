defmodule MetarMap.LdrSensor do
  use GenServer

  alias Circuits.GPIO

  @pulse_duration_ms 100
  @read_duration_ms 900

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def read() do
    GenServer.call(__MODULE__, :read)
  end

  def init(opts) do
    gpio_pin = Keyword.fetch!(opts, :gpio_pin)

    send(self(), :start_pulse)

    {:ok, gpio} = GPIO.open(gpio_pin, :output)

    GPIO.set_interrupts(gpio, :both)

    {:ok,
     %{
       gpio: gpio,
       running_average: 0,
       samples_counted: 0
     }}
  end

  def handle_cast(:read, _, state) do
    {:reply, state.running_average, state}
  end

  def handle_info(:poll, state) do
    {:noreply, state}
  end

  def handle_info(:start_pulse, state) do
    :ok = GPIO.set_direction(state.gpio, :output)
    :ok = GPIO.write(state.gpio, 0)

    Process.send_after(self(), :end_pulse, @pulse_duration_ms)

    {:noreply, state}
  end

  def handle_info(:end_pulse, state) do
    :ok = GPIO.set_direction(state.gpio, :input)

    Process.send_after(self(), :start_pulse, @read_duration_ms)

    {:noreply, state}
  end

  def handle_info({:gpio, _pin_number, timestamp, value}, state) do
    IO.puts("Got transition to #{value} at #{timestamp}")
    {:noreply, state}
  end
end
