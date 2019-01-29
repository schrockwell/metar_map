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
    field :dark_room_intensity, :float, default: 0.5
    field :bright_room_intensity, :float, default: 0.9
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
      :dark_room_intensity,
      :bright_room_intensity
    ]

    prefs
    |> cast(params, permitted)
    |> validate_inclusion(:mode, ["flight_category", "wind_speed", "ceiling"])
    |> validate_number(:brightness_pct, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:max_wind_kts, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:wind_flash_interval_sec,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 60
    )
    |> validate_number(:dark_room_intensity,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:bright_room_intensity,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1.0
    )
    |> Map.put(:action, :update)
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

  def calibrate_dark_room(prefs) do
    update(prefs, %{dark_room_intensity: MetarMap.LdrSensor.read()})
  end

  def calibrate_bright_room(prefs) do
    update(prefs, %{bright_room_intensity: MetarMap.LdrSensor.read()})
  end

  def save(%__MODULE__{} = prefs) do
    prefs
    |> Map.take(MetarMap.Preferences.__schema__(:fields))
    |> Dets.put()

    prefs
  end
end
