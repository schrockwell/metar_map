defmodule MetarMap.Config do
  defstruct brightness: 64,
            stations: %{},
            max_wind_kts: nil,
            wind_flash_interval_ms: nil

  def load_file(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.reduce(%__MODULE__{}, &parse_line/2)
  end

  defp parse_line("#" <> _rest, config), do: config
  defp parse_line("", config), do: config

  defp parse_line("BRIGHTNESS=" <> percent, config) do
    percent = String.to_integer(percent)
    %{config | brightness: trunc(percent / 100 * 255)}
  end

  defp parse_line("MAX_WIND_KTS=" <> kts, config) do
    kts = String.to_integer(kts)

    if kts == 0 do
      %{config | max_wind_kts: nil}
    else
      %{config | max_wind_kts: kts}
    end
  end

  defp parse_line("WIND_FLASH_INTERVAL=" <> sec, config) do
    sec = String.to_integer(sec)

    if sec == 0 do
      %{config | wind_flash_interval_ms: nil}
    else
      %{config | wind_flash_interval_ms: max(sec, 5) * 1000}
    end
  end

  defp parse_line(line, config) do
    line
    |> String.split("=")
    |> case do
      [station_id, led_index] ->
        station = MetarMap.Station.init(station_id, String.to_integer(led_index))
        %{config | stations: Map.put(config.stations, station_id, station)}

      _ ->
        config
    end
  end
end
