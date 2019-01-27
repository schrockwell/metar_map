defmodule MetarMap.Timeline do
  alias Blinkchain.Color

  defstruct transitions: [], latest_color: %Color{r: 0, g: 0, b: 0, w: 0}, point: {0, 0}

  defmodule Transition do
    defstruct [:start_at, :start_color, :end_at, :end_color]
  end

  def init(point, start_color \\ %Color{r: 0, g: 0, b: 0, w: 0}) do
    %__MODULE__{point: point, latest_color: start_color}
  end

  defp now_ms, do: :erlang.monotonic_time(:millisecond)

  @doc """
  Enqueues a color transition.

  Will always begin after the last scheduled transition, or in `min_delay_ms`, whichever comes
  first.
  """
  def append(timeline, duration_ms, color, opts \\ []) do
    min_delay_ms = Keyword.get(opts, :min_delay_ms, 0)

    start_at = find_start_at(timeline, now_ms(), min_delay_ms)
    start_color = timeline.latest_color
    end_at = start_at + duration_ms
    end_color = color

    transition = %Transition{
      start_at: start_at,
      start_color: start_color,
      end_at: end_at,
      end_color: end_color
    }

    %{timeline | transitions: timeline.transitions ++ [transition], latest_color: end_color}
  end

  # Returns the earliest time a transition could begin
  defp find_start_at(timeline, now, min_delay_ms) do
    earliest_start = now + min_delay_ms

    if Enum.empty?(timeline.transitions) do
      earliest_start
    else
      latest_start = List.last(timeline.transitions).end_at
      max(earliest_start, latest_start)
    end
  end

  @doc """
  Determines the current color of the pixel.

  Returns a tuple containing the color and the updated timeline.
  """
  def interpolate(timeline) do
    now = now_ms()
    initial_acc = {timeline.latest_color, []}

    {color, next_transitions} =
      Enum.reduce(timeline.transitions, initial_acc, fn transition, {color, transitions} ->
        cond do
          transition.end_at < now ->
            # The transition has passed - set the end color and discard it
            {transition.end_color, transitions}

          transition.start_at > now ->
            # The transition has not yet begun - keep it
            {color, transitions ++ [transition]}

          true ->
            color =
              MetarMap.blend(
                transition.start_color,
                transition.end_color,
                transition.start_at..transition.end_at,
                now
              )

            {color, transitions ++ [transition]}
        end
      end)

    {color, %{timeline | transitions: next_transitions}}
  end
end
