defmodule ExLox.Func do
  alias __MODULE__
  alias ExLox.Stmt

  @type t :: %Func{params: list(String.t()), body: list(Stmt.t())}

  @enforce_keys [:params, :body]
  defstruct [:params, :body]
end
