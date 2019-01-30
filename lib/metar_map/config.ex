defmodule MetarMap.Config do
  def ldr_pin() do
    Application.get_env(:metar_map, :ldr_pin, false)
  end

  def stations() do
    for {station_id, index} <- Application.get_env(:metar_map, :stations, []) do
      %MetarMap.Station{
        id: station_id,
        index: index
      }
    end
  end
end
