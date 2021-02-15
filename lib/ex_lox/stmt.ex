defmodule ExLox.Stmt do
  alias __MODULE__
  alias ExLox.Expr

  @type t ::
          Stmt.Expression.t()
          | Stmt.Print.t()

  defmodule Expression do
    @type t :: %__MODULE__{expression: Expr.t()}

    @enforce_keys [:expression]
    defstruct [:expression]
  end

  defmodule Print do
    @type t :: %__MODULE__{expression: Expr.t()}

    @enforce_keys [:expression]
    defstruct [:expression]
  end
end
