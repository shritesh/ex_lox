defmodule ExLox.Expr do
  alias __MODULE__

  @type t() ::
          Expr.Binary.t()
          | Expr.Grouping.t()
          | Expr.Literal.t()
          | Expr.Unary.t()
          | Expr.Variable.t()

  defmodule Binary do
    @type binary_op :: :not_eq | :eq | :gr | :gr_eq | :le | :le_eq | :sub | :add | :div | :mul
    @type t :: %__MODULE__{
            left: Expr.t(),
            operator: binary_op(),
            right: Expr.t(),
            line: non_neg_integer()
          }

    @enforce_keys [:left, :operator, :right, :line]
    defstruct [:left, :operator, :right, :line]
  end

  defmodule Grouping do
    @type t :: %__MODULE__{expression: Expr.t()}

    @enforce_keys [:expression]
    defstruct [:expression]
  end

  defmodule Literal do
    @type t :: %__MODULE__{value: any()}

    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule Unary do
    @type unary_op :: :not | :neg

    @type t :: %__MODULE__{operator: unary_op(), right: Expr.t()}

    @enforce_keys [:operator, :right]
    defstruct [:operator, :right]
  end

  defmodule Variable do
    @type t :: %__MODULE__{name: String.t(), line: non_neg_integer()}

    @enforce_keys [:name, :line]
    defstruct [:name, :line]
  end
end
