defmodule ExLox.Klass do
  alias ExLox.Func
  @type t :: %__MODULE__{name: String.t(), methods: %{optional(String.t()) => Func.t()}}

  @enforce_keys [:name, :methods]
  defstruct [:name, :methods]

  @spec find_method(t(), String.t()) :: nil | Func.t()
  def find_method(klass, name) do
    Map.get(klass.methods, name)
  end
end
