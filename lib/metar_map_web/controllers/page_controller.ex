defmodule MetarMapWeb.PageController do
  use MetarMapWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
