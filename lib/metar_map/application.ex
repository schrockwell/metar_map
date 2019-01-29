defmodule MetarMap.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    static_config = load_static_config()
    prefs = MetarMap.Preferences.load()

    # List all child processes to be supervised
    children =
      List.flatten([
        {Registry, keys: :duplicate, name: MetarMap.LedController.Registry},
        Enum.map(static_config.stations, &{MetarMap.LedController, station: &1, prefs: prefs}),
        {MetarMap.StripController, prefs: prefs},
        {MetarMap.MetarFetcher, stations: static_config.stations},
        MetarMapWeb.Endpoint
      ])

    children =
      if static_config.ldr_pin do
        [{MetarMap.LdrSensor, gpio_pin: static_config.ldr_pin}] ++ children
      else
        children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MetarMap.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MetarMapWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp load_static_config do
    filename = Application.get_env(:metar_map, :config)

    unless filename do
      raise "Missing: `config :metar_map, :stations, \"/some/path.exs\""
    end

    MetarMap.StaticConfig.read(filename)
  end
end
