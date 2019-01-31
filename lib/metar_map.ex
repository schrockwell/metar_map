defmodule MetarMap do
  @moduledoc """
  MetarMap keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  alias Blinkchain.Color

  @doc """
  Naively blends two colors
  """
  def blend(from_color, to_color, to_factor) do
    from_factor = 1.0 - to_factor

    %Color{
      r: trunc(from_color.r * from_factor + to_color.r * to_factor),
      g: trunc(from_color.g * from_factor + to_color.g * to_factor),
      b: trunc(from_color.b * from_factor + to_color.b * to_factor),
      w: trunc(from_color.w * from_factor + to_color.w * to_factor)
    }
  end

  @doc """
  Naively blends two colors
  """
  def blend(from_color, to_color, %Range{} = range, value) do
    blend(from_color, to_color, {range.first, range.last}, value)
  end

  def blend(from_color, to_color, {first, last}, value) do
    blend(from_color, to_color, normalize(first, last, value))
  end

  @spec blend_gradient([{number(), %Color{}}], number, term) :: %Color{} | term
  def blend_gradient(_, nil, default), do: default

  def blend_gradient(gradient, value, _default) when is_list(gradient) do
    gradient = Enum.sort(gradient)

    {first_value, first_color} = hd(gradient)
    {last_value, last_color} = List.last(gradient)

    cond do
      value <= first_value ->
        first_color

      value >= last_value ->
        last_color

      true ->
        pairs = Enum.zip(Enum.slice(gradient, 0..-2), Enum.slice(gradient, 1..-1))

        Enum.reduce_while(pairs, nil, fn
          {{min_value, _}, _}, _ when min_value > value ->
            {:cont, nil}

          {{min_value, min_color}, {max_value, max_color}}, _ ->
            {:halt, blend(min_color, max_color, {min_value, max_value}, value)}
        end)
    end
  end

  @doc """
  Changes a color's brightness.
  """
  def brighten(color, rate) do
    %Color{
      r: (color.r * rate) |> min(255) |> max(0) |> trunc(),
      g: (color.g * rate) |> min(255) |> max(0) |> trunc(),
      b: (color.b * rate) |> min(255) |> max(0) |> trunc(),
      w: (color.w * rate) |> min(255) |> max(0) |> trunc()
    }
  end

  @doc """
  Normalize a value from 0.0 to 1.0.
  """
  def normalize(min, max, value) do
    (value - min) / (max - min)
  end
end
