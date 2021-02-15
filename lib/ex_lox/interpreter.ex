defmodule ExLox.Interpreter do
  alias ExLox.{Expr, Stmt}
  alias ExLox.Expr.{Binary, Grouping, Literal, Unary}
  alias ExLox.Stmt.{Expression, Print}

  defmodule RuntimeException do
    defexception [:message, :line]
  end

  @spec interpret(list(Stmt.t())) :: :ok | {:error, ExLox.error()}
  def interpret(statements) do
    try do
      Enum.each(statements, &execute/1)
    rescue
      e in [RuntimeException] ->
        {:error, {e.line, e.message}}
    end
  end

  @spec execute(Stmt.t()) :: nil
  defp execute(stmt) do
    case stmt do
      %Expression{expression: expression} ->
        evaluate(expression)

      %Print{expression: expression} ->
        value = evaluate(expression)

        value
        |> stringify()
        |> IO.puts()
    end

    nil
  end

  @spec evaluate(Expr.t()) :: any()
  defp evaluate(expr) do
    case expr do
      %Binary{operator: operator, left: left, right: right, line: line} ->
        left = evaluate(left)
        right = evaluate(right)

        result =
          case operator do
            :eq ->
              equal?(left, right)

            :not_eq ->
              !equal?(left, right)

            :add when is_number(left) and is_number(right) ->
              left + right

            :add when is_binary(left) and is_binary(right) ->
              left <> right

            :add ->
              raise RuntimeException,
                message: "Operands must be two numbers or two strings.",
                line: line

            _ when not (is_number(left) and is_number(right)) ->
              raise RuntimeException,
                message: "Operands must be numbers.",
                line: line

            :sub ->
              left - right

            :mul ->
              left * right

            :div ->
              left / right

            :gr ->
              left > right

            :gr_eq ->
              left >= right

            :le ->
              left < right

            :le_eq ->
              left <= right
          end

        result

      %Grouping{expression: expr} ->
        evaluate(expr)

      %Literal{value: value} ->
        value

      %Unary{operator: :not, right: right} ->
        expr = evaluate(right)
        !truthy?(expr)

      %Unary{operator: :neg, right: right} ->
        expr = evaluate(right)
        -expr
    end
  end

  defp truthy?(nil), do: false
  defp truthy?(bool) when is_boolean(bool), do: bool
  defp truthy?(_), do: true

  defp equal?(nil, nil), do: true
  defp equal?(nil, _), do: false
  defp equal?(x, x), do: true
  defp equal?(_, _), do: false

  defp stringify(nil), do: "nil"
  defp stringify(num) when is_float(num), do: String.trim_trailing(to_string(num), ".0")
  defp stringify(obj), do: to_string(obj)
end
