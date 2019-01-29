defmodule MetarMapWeb.Router do
  use MetarMapWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MetarMapWeb do
    pipe_through :browser

    resources "/", PreferencesController, singleton: true
    post "/calibrate_room", PreferencesController, :calibrate_room
  end

  # Other scopes may use custom stacks.
  # scope "/api", MetarMapWeb do
  #   pipe_through :api
  # end
end
