defmodule MetarMap do
  @moduledoc """
  MetarMap keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

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
    factor = (value - range.first) / (range.last - range.first)
    blend(from_color, to_color, factor)
  end
end
