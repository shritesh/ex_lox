defmodule ExLox.Environment do
  alias __MODULE__

  @table_name :environments

  @type t :: %Environment{ref: reference()}

  @enforce_keys [:ref]
  defstruct [:ref]

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

  @spec define(t(), String.t(), any()) :: nil
  def define(env, name, value) do
    table =
      get_table(env.ref)
      |> Map.put(name, value)

    put_table(env.ref, table)

    nil
  end

  @spec get(t(), String.t()) :: {:ok, any()} | :error
  def get(env, name) do
    table = get_table(env.ref)

    if Map.has_key?(table, name) do
      {:ok, Map.get(table, name)}
    else
      :error
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
