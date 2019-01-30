defmodule MetarMap.Timeline do
  defstruct transitions: [], latest_value: nil, interpolate_fun: nil

  defmodule Transition do
    defstruct [:start_at, :start_value, :end_at, :end_value]
  end

  def init(initial_value, interpolate_fun) do
    %__MODULE__{latest_value: initial_value, interpolate_fun: interpolate_fun}
  end

  defp now_ms, do: :erlang.monotonic_time(:millisecond)

  @doc """
  Enqueues a value transition.

  Will always begin after the last scheduled transition, or in `min_delay_ms`, whichever comes
  first.
  """
  def append(timeline, duration_ms, value, opts \\ []) do
    min_delay_ms = Keyword.get(opts, :min_delay_ms, 0)

    start_at = find_start_at(timeline, now_ms(), min_delay_ms)
    start_value = timeline.latest_value
    end_at = start_at + duration_ms
    end_value = value

    transition = %Transition{
      start_at: start_at,
      start_value: start_value,
      end_at: end_at,
      end_value: end_value
    }

    %{timeline | transitions: timeline.transitions ++ [transition], latest_value: end_value}
  end

  @doc """
  Immediately stops the timeline and freezes it to the latest inteprolated value.
  """
  def abort(timeline) do
    {value, timeline} = evaluate(timeline)
    %{timeline | transitions: [], latest_value: value}
  end

  def empty?(%{transitions: []}), do: true
  def empty?(_), do: false

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
  Determines the current value of the pixel.

  Returns a tuple containing the value and the updated timeline.
  """
  def evaluate(timeline) do
    evaluate(timeline, now_ms())
  end

  def evaluate(%{transitions: [], latest_value: value} = timeline, _now),
    do: {value, timeline}

  def evaluate(timeline, now) do
    # If we have no upcoming transitions, then just assume it's the latest value. Otherwise, we
    # might be in a period where no transition has yet begun, so assume we are leading UP to that
    # transition and assume its starting value.
    initial_value =
      if timeline.transitions == [] do
        timeline.latest_value
      else
        hd(timeline.transitions).start_value
      end

    initial_acc = {initial_value, []}

    {value, next_transitions} =
      Enum.reduce(timeline.transitions, initial_acc, fn transition, {value, transitions} ->
        cond do
          transition.end_at < now ->
            # The transition has passed - set the end value and discard it
            {transition.end_value, transitions}

          transition.start_at > now ->
            # The transition has not yet begun - keep it
            {value, transitions ++ [transition]}

          true ->
            value =
              do_apply(timeline.interpolate_fun, [
                transition.start_value,
                transition.end_value,
                transition.start_at..transition.end_at,
                now
              ])

            {value, transitions ++ [transition]}
        end
      end)

    {value, %{timeline | transitions: next_transitions}}
  end

  defp do_apply(fun, args) when is_function(fun), do: apply(fun, args)

  defp do_apply({module, fun}, args) when is_atom(module) and is_atom(fun),
    do: apply(module, fun, args)
end
