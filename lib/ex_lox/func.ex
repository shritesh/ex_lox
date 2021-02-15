defmodule ExLox.Func do
  alias __MODULE__
  alias ExLox.{Environment, Stmt}

  @type t :: %Func{params: list(String.t()), body: list(Stmt.t()), closure: Environment.t()}

  @enforce_keys [:params, :body, :closure]
  defstruct [:params, :body, :closure]
end
