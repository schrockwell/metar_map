defmodule MetarMap.Preferences do
  alias MetarMap.Dets
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :brightness_pct, :integer, default: 25
    field :max_wind_kts, :integer, default: 20
    field :wind_flash_interval_sec, :integer, default: 5
    field :mode, :string, default: "flight_category"

    field :dark_sensor_pct, :integer, default: 30
    field :bright_sensor_pct, :integer, default: 50
    field :dark_brightness_pct, :integer, default: 25
    field :bright_brightness_pct, :integer, default: 50
  end

  def load do
    :fields
    |> MetarMap.Preferences.__schema__()
    |> Dets.get()
    |> Enum.reduce(%__MODULE__{}, fn {field, value}, prefs ->
      if is_nil(value) do
        prefs
      else
        Map.put(prefs, field, value)
      end
    end)
  end

  def changeset(prefs, params \\ %{}) do
    permitted = [
      :brightness_pct,
      :max_wind_kts,
      :wind_flash_interval_sec,
      :mode,
      :dark_sensor_pct,
      :bright_sensor_pct,
      :dark_brightness_pct,
      :bright_brightness_pct
    ]

    prefs
    |> cast(params, permitted)
    |> validate_inclusion(:mode, ["flight_category", "wind_speed", "ceiling", "visibility"])
    |> validate_percents([
      :brightness_pct,
      :dark_brightness_pct,
      :bright_brightness_pct,
      :dark_sensor_pct,
      :bright_sensor_pct
    ])
    |> validate_number(:max_wind_kts, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:wind_flash_interval_sec,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 60
    )
    |> Map.put(:action, :update)
  end

  defp validate_percents(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      validate_number(changeset, field, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    end)
  end

  def update(prefs, params) do
    prefs
    |> changeset(params)
    |> case do
      %{valid?: true} = changeset ->
        prefs =
          changeset
          |> apply_changes()
          |> save()

        MetarMap.StripController.put_prefs(prefs)
        MetarMap.LedController.put_prefs(prefs)

        {:ok, prefs}

      changeset ->
        {:error, changeset}
    end
  end

  def calibrate_room(prefs, "dark") do
    update(prefs, %{dark_sensor_pct: trunc(MetarMap.LdrSensor.read() * 100)})
  end

  def calibrate_room(prefs, "bright") do
    update(prefs, %{bright_sensor_pct: trunc(MetarMap.LdrSensor.read() * 100)})
  end

  def save(%__MODULE__{} = prefs) do
    prefs
    |> Map.take(MetarMap.Preferences.__schema__(:fields))
    |> Dets.put()

    prefs
  end
end
