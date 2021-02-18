defmodule ExLox.Instance do
  alias ExLox.{Func, Klass, MutableMap}

  @type t :: %__MODULE__{klass: Klass.t(), map: MutableMap.t()}

  @enforce_keys [:klass, :map]
  defstruct [:klass, :map]

  def new(klass) do
    %__MODULE__{
      klass: klass,
      map: MutableMap.new()
    }
  end

  @spec get(t(), String.t()) :: :error | {:ok, any()}
  def get(instance, name) do
    fields = MutableMap.get(instance.map)

    if Map.has_key?(fields, name) do
      {:ok, Map.get(fields, name)}
    else
      case Klass.find_method(instance.klass, name) do
        nil ->
          :error

        method ->
          method = Func.bind(method, instance)
          {:ok, method}
      end
    end
  end

  @spec set(t(), String.t(), any()) :: nil
  def set(instance, name, value) do
    fields = MutableMap.get(instance.map)
    fields = Map.put(fields, name, value)
    MutableMap.put(instance.map, fields)
    nil
  end
end
