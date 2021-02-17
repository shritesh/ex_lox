defmodule ExLox.Klass do
  @type t :: %__MODULE__{name: String.t()}

  @enforce_keys [:name]
  defstruct [:name]
end
