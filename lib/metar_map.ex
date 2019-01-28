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
    blend(from_color, to_color, normalize(range.first, range.last, value))
  end

  @doc """
  Changes a color's brightness.
  """
  def brighten(color, rate) do
    %Color{
      r: (color.r * rate) |> min(255) |> max(0),
      g: (color.g * rate) |> min(255) |> max(0),
      b: (color.b * rate) |> min(255) |> max(0),
      w: (color.w * rate) |> min(255) |> max(0)
    }
  end

  @doc """
  Normalize a value from 0.0 to 1.0.
  """
  def normalize(min, max, value) do
    (value - min) / (max - min)
  end
end
