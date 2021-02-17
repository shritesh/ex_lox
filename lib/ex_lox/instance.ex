defmodule ExLox.Instance do
  alias ExLox.Klass
  @type t :: %__MODULE__{klass: Klass.t()}

  @enforce_keys [:klass]
  defstruct [:klass]
end
