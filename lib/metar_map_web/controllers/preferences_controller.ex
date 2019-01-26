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
end
