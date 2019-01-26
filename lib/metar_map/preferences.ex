defmodule MetarMap.Preferences do
  alias MetarMap.Dets

  @channel 0

  def get(:brightness) do
    Dets.get(:brightness, 64)
  end

  def get(:do_flash_wind) do
    Dets.get(:do_flash_wind, true)
  end

  def get(:max_wind_kts) do
    Dets.get(:max_wind_kts, 20)
  end

  def get(:wind_flash_interval_ms) do
    Dets.get(:wind_flash_interval_ms, 5000)
  end

  def set(:brightness, value) do
    Dets.put(:brightness, value)
    Blinkchain.set_brightness(@channel, value)
    Blinkchain.render()
  end

  def set(key, value) do
    Dets.put(key, value)
  end
end
