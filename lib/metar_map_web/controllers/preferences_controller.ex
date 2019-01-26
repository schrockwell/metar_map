defmodule MetarMapWeb.PreferencesController do
  use MetarMapWeb, :controller

  def show(conn, _params) do
    render(conn, "show.html")
  end
end
