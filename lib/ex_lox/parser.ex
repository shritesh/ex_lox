defmodule ExLox.Parser do
  alias ExLox.{Expr, Token}
  alias ExLox.Expr.{Binary, Grouping, Literal, Unary}

  defmodule ParserException do
    defexception [:message, :tokens]
  end

  @spec parse(list(Token.t())) :: {:ok, Expr.t()} | {:error, ExLox.error()}
  def parse(tokens) do
    try do
      {expr, _} = expression(tokens)
      {:ok, expr}
    rescue
      e in [ParserException] ->
        line =
          case e.tokens do
            [] -> :eof
            [%Token{line: line} | _] -> line
          end

        error = {line, e.message}
        {:error, error}
    end
  end

  defp expression(tokens) do
    equality(tokens)
  end

  defp equality(tokens) do
    {expr, rest} = comparison(tokens)
    equality_inner(expr, rest)
  end

  defp equality_inner(expr, tokens) do
    case tokens do
      [%Token{type: :bang_equal, line: line} | rest] ->
        {right, rest} = comparison(rest)
        expr = %Binary{operator: :not_eq, left: expr, right: right, line: line}
        equality_inner(expr, rest)

      [%Token{type: :equal_equal, line: line} | rest] ->
        {right, rest} = comparison(rest)
        expr = %Binary{operator: :eq, left: expr, right: right, line: line}
        equality_inner(expr, rest)

      _ ->
        {expr, tokens}
    end
  end

  defp comparison(tokens) do
    {expr, rest} = term(tokens)
    comparison_inner(expr, rest)
  end

  defp comparison_inner(expr, tokens) do
    case tokens do
      [%Token{type: :greater, line: line} | rest] ->
        {right, rest} = term(rest)
        expr = %Binary{operator: :gr, left: expr, right: right, line: line}
        comparison_inner(expr, rest)

      [%Token{type: :greater_equal, line: line} | rest] ->
        {right, rest} = term(rest)
        expr = %Binary{operator: :gr_eq, left: expr, right: right, line: line}
        comparison_inner(expr, rest)

      [%Token{type: :less, line: line} | rest] ->
        {right, rest} = term(rest)
        expr = %Binary{operator: :le, left: expr, right: right, line: line}
        comparison_inner(expr, rest)

      [%Token{type: :less_equal, line: line} | rest] ->
        {right, rest} = term(rest)
        expr = %Binary{operator: :le_eq, left: expr, right: right, line: line}
        comparison_inner(expr, rest)

      _ ->
        {expr, tokens}
    end
  end

  defp term(tokens) do
    {expr, rest} = factor(tokens)
    term_inner(expr, rest)
  end

  defp term_inner(expr, tokens) do
    case tokens do
      [%Token{type: :minus, line: line} | rest] ->
        {right, rest} = factor(rest)
        expr = %Binary{operator: :sub, left: expr, right: right, line: line}
        term_inner(expr, rest)

      [%Token{type: :plus, line: line} | rest] ->
        {right, rest} = factor(rest)
        expr = %Binary{operator: :add, left: expr, right: right, line: line}
        term_inner(expr, rest)

      _ ->
        {expr, tokens}
    end
  end

  defp factor(tokens) do
    {expr, rest} = unary(tokens)
    factor_inner(expr, rest)
  end

  defp factor_inner(expr, tokens) do
    case tokens do
      [%Token{type: :slash, line: line} | rest] ->
        {right, rest} = unary(rest)
        expr = %Binary{operator: :div, left: expr, right: right, line: line}
        factor_inner(expr, rest)

      [%Token{type: :star, line: line} | rest] ->
        {right, rest} = unary(rest)
        expr = %Binary{operator: :mul, left: expr, right: right, line: line}
        factor_inner(expr, rest)

      _ ->
        {expr, tokens}
    end
  end

  defp unary(tokens) do
    case tokens do
      [%Token{type: :bang} | rest] ->
        {right, rest} = unary(rest)
        expr = %Unary{operator: :not, right: right}
        {expr, rest}

      [%Token{type: :minus} | rest] ->
        {right, rest} = unary(rest)
        expr = %Unary{operator: :neg, right: right}
        {expr, rest}

      _ ->
        primary(tokens)
    end
  end

  defp primary(tokens) do
    case tokens do
      [%Token{type: false} | rest] ->
        expr = %Literal{value: false}
        {expr, rest}

      [%Token{type: true} | rest] ->
        expr = %Literal{value: true}
        {expr, rest}

      [%Token{type: nil} | rest] ->
        expr = %Literal{value: nil}
        {expr, rest}

      [%Token{type: {:number, number}} | rest] ->
        expr = %Literal{value: number}
        {expr, rest}

      [%Token{type: {:string, string}} | rest] ->
        expr = %Literal{value: string}
        {expr, rest}

      [%Token{type: :left_paren} | rest] ->
        {expr, rest} = expression(rest)
        rest = consume(rest, :right_paren, "Expect ')' after expression.")

        expr = %Grouping{expression: expr}
        {expr, rest}

      _ ->
        raise ParserException, message: "Expect expression.", tokens: tokens
    end
  end

  defp consume(tokens, type, message) do
    case tokens do
      [%Token{type: ^type} | rest] -> rest
      _ -> raise ParserException, message: message, tokens: tokens
    end
  end
end
