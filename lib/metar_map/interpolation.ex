defmodule MetarMap.Interpolation do
  def blend_colors(from_color, to_color, range, value) do
    MetarMap.blend(from_color, to_color, range, value)
  end

  def toggle_colors(from_color, _to_color, _range, _value), do: from_color

  def integers(from_value, to_value, range, value) do
    difference = to_value - from_value
    progress = MetarMap.normalize(range.first, range.last, value)

    from_value + trunc(difference * progress)
  end

  def floats(from_value, to_value, range, value) do
    difference = to_value - from_value
    progress = MetarMap.normalize(range.first, range.last, value)

    from_value + difference * progress
  end
end
