defmodule MetarMapWeb.PreferencesController do
  use MetarMapWeb, :controller

  alias MetarMap.Preferences

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

  def calibrate_room(conn, %{"condition" => "dark"}) do
    Preferences.load()
    |> Preferences.calibrate_dark_room()
    |> case do
      {:ok, prefs} ->
        conn
        |> put_flash(
          :info,
          "Dark room calibrated to #{percent_string(prefs.dark_room_intensity)}"
        )
        |> redirect(to: Routes.preferences_path(conn, :show))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Could not calibrate dark room; try again")
        |> render("show.html", changeset: changeset)
    end
  end

  def calibrate_room(conn, %{"condition" => "bright"}) do
    Preferences.load()
    |> Preferences.calibrate_bright_room()
    |> case do
      {:ok, prefs} ->
        conn
        |> put_flash(
          :info,
          "Bright room calibrated to #{percent_string(prefs.bright_room_intensity)}"
        )
        |> redirect(to: Routes.preferences_path(conn, :show))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Could not calibrate bright room; try again")
        |> render("show.html", changeset: changeset)
    end
  end

  defp percent_string(float), do: "#{trunc(float * 100)}%"
end
