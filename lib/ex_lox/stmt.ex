defmodule ExLox.Stmt do
  alias __MODULE__
  alias ExLox.Expr

  @type t ::
          Stmt.Block.t()
          | Stmt.Expression.t()
          | Stmt.If.t()
          | Stmt.Print.t()
          | Stmt.Var.t()

  defmodule Block do
    @type t :: %__MODULE__{statements: list(Stmt.t())}

    @enforce_keys [:statements]
    defstruct [:statements]
  end

  defmodule Expression do
    @type t :: %__MODULE__{expression: Expr.t()}

    @enforce_keys [:expression]
    defstruct [:expression]
  end

  defmodule If do
    @type t :: %__MODULE__{
            condition: Expr.t(),
            then_branch: Stmt.t(),
            else_branch: Stmt.t() | nil
          }

    @enforce_keys [:condition, :then_branch]
    defstruct [:condition, :then_branch, :else_branch]
  end

  defmodule Print do
    @type t :: %__MODULE__{expression: Expr.t()}

    @enforce_keys [:expression]
    defstruct [:expression]
  end

  defmodule Var do
    @type t :: %__MODULE__{name: String.t(), initializer: Expr.t() | nil}

    @enforce_keys [:name]
    defstruct [:name, initializer: nil]
  end
end
