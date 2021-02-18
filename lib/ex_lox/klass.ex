defmodule ExLox.Klass do
  alias ExLox.Func

  @type t :: %__MODULE__{
          name: String.t(),
          methods: %{optional(String.t()) => Func.t()},
          superklass: nil | t()
        }

  @enforce_keys [:name, :methods]
  defstruct [:name, :methods, :superklass]

  @spec find_method(t(), String.t()) :: nil | Func.t()
  def find_method(klass, name) do
    case Map.get(klass.methods, name) do
      nil ->
        if klass.superklass do
          find_method(klass.superklass, name)
        end

      method ->
        method
    end
  end

  @spec arity(t()) :: integer()
  def arity(klass) do
    if init = find_method(klass, "init") do
      Func.arity(init)
    else
      0
    end
  end
end
