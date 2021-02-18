defmodule ExLox.Environment do
  alias __MODULE__
  alias ExLox.MutableMap

  @type t :: %Environment{map: MutableMap.t(), enclosing: nil | t()}

  @enforce_keys [:map]
  defstruct [:map, :enclosing]

  @spec new :: t()
  def new do
    %Environment{
      map: MutableMap.new()
    }
  end

  @spec from(t()) :: t()
  def from(env) do
    %Environment{
      map: MutableMap.new(),
      enclosing: env
    }
  end

  @spec define(t(), String.t(), any()) :: nil
  def define(env, name, value) do
    map = MutableMap.get(env.map)

    map = Map.put(map, name, value)
    MutableMap.put(env.map, map)

    nil
  end

  @spec get(t(), String.t()) :: {:ok, any()} | :error
  def get(env, name) do
    map = MutableMap.get(env.map)

    if Map.has_key?(map, name) do
      {:ok, Map.get(map, name)}
    else
      if env.enclosing do
        get(env.enclosing, name)
      else
        :error
      end
    end
  end

  @spec get_at(t(), integer(), String.t()) :: {:ok, any()} | :error
  def get_at(env, distance, name) do
    if distance == 0 do
      get(env, name)
    else
      get_at(env.enclosing, distance - 1, name)
    end
  end

  @spec assign(t(), String.t(), any()) :: :ok | :error
  def assign(env, name, value) do
    map = MutableMap.get(env.map)

    if Map.has_key?(map, name) do
      map = Map.put(map, name, value)
      MutableMap.put(env.map, map)
      :ok
    else
      if env.enclosing do
        assign(env.enclosing, name, value)
      else
        :error
      end
    end
  end

  @spec assign_at(t(), integer(), String.t(), any()) :: :ok | :error
  def assign_at(env, distance, name, value) do
    if distance == 0 do
      assign(env, name, value)
    else
      assign_at(env.enclosing, distance - 1, name, value)
    end
  end
end
