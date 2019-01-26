defmodule MetarMap.Dets do
  @doc """
  Gets many keys as a map. Missing keys are set to `nil`
  """
  def get(keys) when is_list(keys) do
    keys |> Enum.map(&{&1, get(&1)}) |> Map.new()
  end

  @doc """
  Gets a value
  """
  def get(key, default \\ nil) do
    open_table!()

    result =
      case :dets.lookup(:config, key) do
        [] -> default
        [{^key, value}] -> value
      end

    close_table!()
    result
  end

  @doc """
  Stores many values at once. Can be a map or keyword list.
  """
  def put(values) when is_map(values) or is_list(values) do
    values |> Enum.each(fn {key, value} -> put(key, value) end)
    :ok
  end

  @doc """
  Stores a single value.
  """
  def put(key, value) do
    open_table!()

    :dets.insert(:config, [{key, value}])

    close_table!()
    :ok
  end

  @doc """
  Stores many new values at once. Can be a map or keyword list.
  """
  def put_new(values) when is_map(values) or is_list(values) do
    values |> Enum.each(fn {key, value} -> put_new(key, value) end)
    :ok
  end

  @doc """
  Puts a single new value if it doesn't yet exist.
  """
  def put_new(key, value) do
    open_table!()

    :dets.insert_new(:config, [{key, value}])

    close_table!()
    :ok
  end

  defp open_table! do
    filename = [:code.priv_dir(:metar_map), 'dets_config'] |> Path.join() |> String.to_charlist()

    {:ok, :config} = :dets.open_file(:config, type: :set, file: filename)
  end

  defp close_table! do
    :ok = :dets.close(:config)
  end
end
