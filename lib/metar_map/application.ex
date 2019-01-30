defmodule MetarMap.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias MetarMap.Config

  def start(_type, _args) do
    prefs = MetarMap.Preferences.load()
    stations = Config.stations()
    ldr_pin = Config.ldr_pin()

    # List all child processes to be supervised
    children =
      List.flatten([
        {Registry, keys: :duplicate, name: MetarMap.LedController.Registry},
        Enum.map(stations, &{MetarMap.LedController, station: &1, prefs: prefs}),
        {MetarMap.StripController, prefs: prefs},
        {MetarMap.MetarFetcher, stations: stations},
        if(ldr_pin, do: [{MetarMap.LdrSensor, gpio_pin: ldr_pin}], else: []),
        MetarMapWeb.Endpoint
      ])

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
end
