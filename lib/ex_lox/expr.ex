defmodule ExLox.Expr do
  alias __MODULE__

  @type t() ::
          Expr.Assign.t()
          | Expr.Binary.t()
          | Expr.Call.t()
          | Expr.Get.t()
          | Expr.Grouping.t()
          | Expr.Literal.t()
          | Expr.Logical.t()
          | Expr.Set.t()
          | Expr.Super.t()
          | Expr.This.t()
          | Expr.Unary.t()
          | Expr.Variable.t()

  defmodule Assign do
    @type t :: %__MODULE__{
            name: String.t(),
            value: Expr.t(),
            line: non_neg_integer(),
            distance: nil | integer()
          }

    @enforce_keys [:name, :value, :line]
    defstruct [:name, :value, :line, :distance]
  end

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

  defmodule Call do
    @type t :: %__MODULE__{callee: Expr.t(), arguments: list(Expr.t()), line: non_neg_integer()}

    @enforce_keys [:callee, :arguments, :line]
    defstruct [:callee, :paren, :arguments, :line]
  end

  defmodule Get do
    @type t :: %__MODULE__{object: Expr.t(), name: String.t(), line: non_neg_integer()}

    @enforce_keys [:object, :name, :line]
    defstruct [:object, :name, :line]
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

  defmodule Logical do
    @type logical_op :: :or | :and
    @type t :: %__MODULE__{left: Expr.t(), operator: logical_op(), right: Expr.t()}

    @enforce_keys [:left, :operator, :right]
    defstruct [:left, :operator, :right]
  end

  defmodule Set do
    @type t :: %__MODULE__{
            object: Expr.t(),
            name: String.t(),
            value: Expr.t(),
            line: non_neg_integer()
          }
    @enforce_keys [:object, :name, :value, :line]
    defstruct [:object, :name, :value, :line]
  end

  defmodule Super do
    @type t :: %__MODULE__{method: String.t(), line: non_neg_integer(), distance: nil | integer()}

    @enforce_keys [:method, :line]
    defstruct [:method, :line, :distance]
  end

  defmodule This do
    @type t :: %__MODULE__{line: non_neg_integer(), distance: nil | integer()}

    @enforce_keys [:line]
    defstruct [:line, :distance]
  end

  defmodule Unary do
    @type unary_op :: :not | :neg

    @type t :: %__MODULE__{operator: unary_op(), right: Expr.t()}

    @enforce_keys [:operator, :right]
    defstruct [:operator, :right]
  end

  defmodule Variable do
    @type t :: %__MODULE__{name: String.t(), line: non_neg_integer(), distance: nil | integer()}

    @enforce_keys [:name, :line]
    defstruct [:name, :line, :distance]
  end
end
