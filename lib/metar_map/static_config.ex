defmodule MetarMap.StaticConfig do
  defstruct [:stations]

  def read(filename) do
    config_map =
      filename
      |> Code.eval_file()
      |> elem(0)

    stations =
      Enum.map(config_map.stations, fn {station_id, index} ->
        %MetarMap.Station{
          id: station_id,
          index: index
        }
      end)

    %__MODULE__{
      stations: stations
    }
  end
end
