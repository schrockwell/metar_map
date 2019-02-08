defmodule MetarMapWeb.PreferencesController do
  use MetarMapWeb, :controller

  alias MetarMap.Preferences

  plug :put_sensor_status

  def show(conn, _params) do
    render(conn, "show.html", changeset: Preferences.load() |> Preferences.changeset())
  end

  def update(conn, %{"preferences" => params}) do
    Preferences.load()
    |> Preferences.update(params)
    |> case do
      {:ok, _prefs} ->
        conn
        |> put_flash(:info, "Settings updated")
        |> redirect(to: Routes.preferences_path(conn, :show))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Settings invalid; try again")
        |> render("show.html", changeset: changeset)
    end
  end

  def calibrate_room(conn, %{"room" => room}) do
    Preferences.load()
    |> Preferences.calibrate_room(room)
    |> case do
      {:ok, _prefs} ->
        conn
        |> put_flash(
          :info,
          "Calibrated #{room} room"
        )
        |> redirect(to: Routes.preferences_path(conn, :show))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Could not calibrate #{room} room; try again")
        |> render("show.html", changeset: changeset)
    end
  end

  defp put_sensor_status(conn, _), do: assign(conn, :has_sensor, MetarMap.LdrSensor.available?())
end
