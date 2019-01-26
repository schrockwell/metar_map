defmodule MetarMap.Station do
  defstruct [:id, :index, :metar]

  def init(id, index) do
    %__MODULE__{
      id: id,
      index: index,
      metar: nil
    }
  end

  def get_category(%__MODULE__{metar: nil}), do: :unknown
  def get_category(%__MODULE__{metar: %{category: category}}), do: category

  def get_max_wind(%__MODULE__{metar: nil}), do: 0

  def get_max_wind(%__MODULE__{metar: metar}) do
    max(metar.wind_speed_kt || 0, metar.wind_gust_kt || 0)
  end

  def put_metar(%__MODULE__{} = station, metar), do: %{station | metar: metar}
end
