defmodule MetarMap.Metar do
  defstruct [
    :station_id,
    :category,
    :wind_speed_kt,
    :wind_gust_kt,
    :wind_dir_degrees,
    :latitude,
    :longitude,
    :sky_conditions,
    :visibility
  ]

  @doc """
  Returns `{{min_lat, max_lat}, {min_lon, max_lon}}`
  """
  def find_bounds([first_metar | _] = metars) do
    initial_acc =
      {{first_metar.latitude, first_metar.latitude},
       {first_metar.longitude, first_metar.longitude}}

    Enum.reduce(metars, initial_acc, fn metar, {{min_lat, max_lat}, {min_lon, max_lon}} ->
      {
        {min(min_lat, metar.latitude), max(max_lat, metar.latitude)},
        {min(min_lon, metar.longitude), max(max_lon, metar.longitude)}
      }
    end)
  end
end
