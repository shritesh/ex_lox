defmodule ExLox.Environment do
  alias __MODULE__

  @table_name :environments

  @type t :: %Environment{ref: reference()}

  @enforce_keys [:ref]
  defstruct [:ref, :enclosing]

  @spec init :: nil
  def init do
    :ets.new(@table_name, [:named_table, :private, :set])
  end

  @spec new :: t()
  def new do
    %Environment{
      ref: new_table()
    }
  end

  @spec from(t()) :: t()
  def from(env) do
    %Environment{
      ref: new_table(),
      enclosing: env
    }
  end

  @spec define(t(), String.t(), any()) :: nil
  def define(env, name, value) do
    table = get_table(env.ref)

    table = Map.put(table, name, value)
    put_table(env.ref, table)

    nil
  end

  @spec get(t(), String.t()) :: {:ok, any()} | :error
  def get(env, name) do
    table = get_table(env.ref)

    if Map.has_key?(table, name) do
      {:ok, Map.get(table, name)}
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
    table = get_table(env.ref)

    if Map.has_key?(table, name) do
      table = Map.put(table, name, value)
      put_table(env.ref, table)
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

  defp new_table() do
    ref = make_ref()
    :ets.insert(@table_name, {ref, %{}})
    ref
  end

  defp get_table(ref) do
    [{_, table}] = :ets.lookup(@table_name, ref)
    table
  end

  defp put_table(ref, table) do
    :ets.insert(@table_name, {ref, table})
  end
end
