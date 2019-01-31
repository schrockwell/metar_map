defmodule MetarMap.AviationWeather do
  #
  # API DOCUMENTATION: https://www.aviationweather.gov/dataserver
  #

  @base_url "https://www.aviationweather.gov/adds/dataserver_current/httpparam"
  @base_params %{
    dataSource: "metars",
    requestType: "retrieve",
    format: "xml",
    mostRecentForEachStation: "true",
    hoursBeforeNow: "2"
  }

  def fetch_latest_metars(station_ids) do
    station_string = station_ids |> Enum.join(" ")
    params = @base_params |> Map.put(:stationString, station_string)

    with {:ok, response} <- HTTPoison.get(@base_url, [], params: params) do
      {:ok, parse_metars(response)}
    end
  end

  #
  # Example METAR node:
  #
  #   <METAR>
  #     <raw_text>KBDL 241951Z 19015G22KT 5SM -RA BR FEW009 BKN015 OVC030 12/12 A2922 RMK AO2 SLP896 P0045 T01220122</raw_text>
  #     <station_id>KBDL</station_id>
  #     <observation_time>2019-01-24T19:51:00Z</observation_time>
  #     <latitude>41.93</latitude>
  #     <longitude>-72.68</longitude>
  #     <temp_c>12.2</temp_c>
  #     <dewpoint_c>12.2</dewpoint_c>
  #     <wind_dir_degrees>190</wind_dir_degrees>
  #     <wind_speed_kt>15</wind_speed_kt>
  #     <wind_gust_kt>22</wind_gust_kt>
  #     <visibility_statute_mi>5.0</visibility_statute_mi>
  #     <altim_in_hg>29.220472</altim_in_hg>
  #     <sea_level_pressure_mb>989.6</sea_level_pressure_mb>
  #     <quality_control_flags>
  #       <auto_station>TRUE</auto_station>
  #     </quality_control_flags>
  #     <wx_string>-RA BR</wx_string>
  #     <sky_condition sky_cover="FEW" cloud_base_ft_agl="900" />
  #     <sky_condition sky_cover="BKN" cloud_base_ft_agl="1500" />
  #     <sky_condition sky_cover="OVC" cloud_base_ft_agl="3000" />
  #     <flight_category>MVFR</flight_category>
  #     <precip_in>0.45</precip_in>
  #     <metar_type>METAR</metar_type>
  #     <elevation_m>60.0</elevation_m>
  #   </METAR>
  #
  defp parse_metars(%HTTPoison.Response{body: body}) do
    import SweetXml

    body
    |> parse()
    |> xpath(~x"//METAR"l,
      station_id: ~x"station_id/text()"s,
      category: ~x"flight_category/text()"s |> transform_by(&normalize_category/1),
      wind_speed_kt: ~x"wind_speed_kt/text()"s |> transform_by(&normalize_integer/1),
      wind_gust_kt: ~x"wind_gust_kt/text()"s |> transform_by(&normalize_integer/1),
      latitude: ~x"latitude/text()"f,
      longitude: ~x"longitude/text()"f,
      sky_conditions: [
        ~x"sky_condition"l,
        cover: ~x"@sky_cover"S,
        base_agl: ~x"@cloud_base_ft_agl"I
      ],
      visibility: ~x"visibility_statute_mi/text()"s |> transform_by(&normalize_float/1)
    )
    |> Enum.map(&struct(MetarMap.Metar, &1))
  end

  defp normalize_integer(""), do: nil
  defp normalize_integer(string), do: string |> String.to_integer()

  defp normalize_float(""), do: nil
  defp normalize_float(string), do: string |> String.to_float()

  defp normalize_category("VFR"), do: :vfr
  defp normalize_category("MVFR"), do: :mvfr
  defp normalize_category("IFR"), do: :ifr
  defp normalize_category("LIFR"), do: :lifr
  defp normalize_category(_), do: :unknown
end
