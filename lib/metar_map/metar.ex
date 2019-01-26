defmodule MetarMap.Metar do
  defstruct [:station_id, :category, :wind_speed_kt, :wind_gust_kt, :wind_dir_degrees]
end
