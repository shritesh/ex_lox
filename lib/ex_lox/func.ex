defmodule ExLox.Func do
  alias __MODULE__
  alias ExLox.{Environment, Instance, Stmt}

  @type t :: %Func{params: list(String.t()), body: list(Stmt.t()), closure: Environment.t()}

  @enforce_keys [:params, :body, :closure]
  defstruct [:params, :body, :closure]

  @spec bind(t(), Instance.t()) :: t()
  def bind(func, instance) do
    environment = Environment.from(func.closure)
    Environment.define(environment, "this", instance)
    %Func{params: func.params, body: func.body, closure: environment}
  end

  @spec arity(t()) :: integer()
  def arity(func) do
    length(func.params)
  end
end
