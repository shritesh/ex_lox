defmodule ExLox.MutableMap do
  @table_name :lox

  @type t :: reference()

  @spec init :: nil
  def init do
    :ets.new(@table_name, [:named_table, :private, :set])
  end

  def new() do
    ref = make_ref()
    :ets.insert(@table_name, {ref, %{}})
    ref
  end

  def get(ref) do
    [{_, map}] = :ets.lookup(@table_name, ref)
    map
  end

  def put(ref, map) do
    :ets.insert(@table_name, {ref, map})
  end
end
