defmodule ExLox.Stmt do
  alias __MODULE__
  alias ExLox.Expr

  @type t ::
          Stmt.Block.t()
          | Stmt.Expression.t()
          | Stmt.Function.t()
          | Stmt.If.t()
          | Stmt.Print.t()
          | Stmt.Return.t()
          | Stmt.Var.t()
          | Stmt.While.t()

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

  defmodule Function do
    @type t :: %__MODULE__{
            name: String.t(),
            params: list(String.t()),
            body: list(Stmt.t())
          }

    @enforce_keys [:name, :params, :body]
    defstruct [:name, :params, :body]
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

  defmodule Return do
    @type t :: %__MODULE__{value: nil | Expr.t()}

    defstruct [:value]
  end

  defmodule Var do
    @type t :: %__MODULE__{name: String.t(), initializer: Expr.t() | nil}

    @enforce_keys [:name]
    defstruct [:name, initializer: nil]
  end

  defmodule While do
    @type t :: %__MODULE__{condition: Expr.t(), body: Stmt.t()}

    @enforce_keys [:condition, :body]
    defstruct [:condition, :body]
  end
end
