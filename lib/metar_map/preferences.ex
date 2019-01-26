defmodule MetarMap.Preferences do
  alias MetarMap.Dets
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :brightness_pct, :integer, default: 25
    field :max_wind_kts, :integer, default: 20
    field :wind_flash_interval_sec, :integer, default: 5
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
      :wind_flash_interval_sec
    ]

    prefs
    |> cast(params, permitted)
    |> validate_number(:brightness_pct, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:max_wind_kts, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:wind_flash_interval_sec,
      greater_than_or_equal_to: 5,
      less_than_or_equal_to: 60
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

        MetarMap.LightController.reload_preferences()

        {:ok, prefs}

      changeset ->
        {:error, changeset}
    end
  end

  def save(%__MODULE__{} = prefs) do
    prefs
    |> Map.take(MetarMap.Preferences.__schema__(:fields))
    |> Dets.put()

    prefs
  end
end
