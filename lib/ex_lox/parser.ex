defmodule ExLox.Parser do
  alias ExLox.{Stmt, Token}
  alias ExLox.Expr.{Assign, Binary, Grouping, Literal, Logical, Unary, Variable}
  alias ExLox.Stmt.{Block, Expression, If, Print, Var, While}

  defmodule ParserException do
    defexception [:message, :tokens]
  end

  @spec parse(list(Token.t())) :: {:ok, list(Stmt.t())} | {:error, list(ExLox.error())}
  def parse(tokens) do
    parse([], [], tokens)
  end

  defp parse(statements, errors, []) do
    if Enum.empty?(errors) do
      statements = Enum.reverse(statements)
      {:ok, statements}
    else
      errors = Enum.reverse(errors)
      {:error, errors}
    end
  end

  defp parse(statements, errors, tokens) do
    case declaration(tokens) do
      {:ok, stmt, rest} -> parse([stmt | statements], errors, rest)
      {:error, error, rest} -> parse(statements, [error | errors], rest)
    end
  end

  defp declaration(tokens) do
    try do
      {stmt, rest} =
        case tokens do
          [%Token{type: :var} | rest] -> var_declaration(rest)
          _ -> statement(tokens)
        end

      {:ok, stmt, rest}
    rescue
      e in [ParserException] ->
        line =
          case e.tokens do
            [] -> :eof
            [%Token{line: line} | _] -> line
          end

        error = {line, e.message}
        tokens = synchronize(e.tokens)

        {:error, error, tokens}
    end
  end

  defp var_declaration(tokens) do
    case tokens do
      [%Token{type: {:identifier, name}}, %Token{type: :equal} | rest] ->
        {initializer, rest} = expression(rest)
        rest = consume(rest, :semicolon, "Expect ';' after variable declaration")

        stmt = %Var{name: name, initializer: initializer}
        {stmt, rest}

      [%Token{type: {:identifier, name}} | rest] ->
        rest = consume(rest, :semicolon, "Expect ';' after variable declaration")

        stmt = %Var{name: name}
        {stmt, rest}

      _ ->
        raise ParserException, message: "Expect variable name.", tokens: tokens
    end
  end

  defp statement(tokens) do
    case tokens do
      [%Token{type: :print} | rest] ->
        print_statement(rest)

      [%Token{type: :if} | rest] ->
        if_statement(rest)

      [%Token{type: :while} | rest] ->
        while_statement(rest)

      [%Token{type: :left_brace} | rest] ->
        {statements, rest} = block(rest, [])
        stmt = %Block{statements: statements}
        {stmt, rest}

      _ ->
        expression_statement(tokens)
    end
  end

  defp if_statement(tokens) do
    rest = consume(tokens, :left_paren, "Expect '(' after 'if'.")
    {condition, rest} = expression(rest)
    rest = consume(rest, :right_paren, "Expect ')' after if condition.")

    {then_branch, rest} = statement(rest)

    {else_branch, rest} =
      case rest do
        [%Token{type: :else} | rest] ->
          statement(rest)

        _ ->
          {nil, rest}
      end

    stmt = %If{condition: condition, then_branch: then_branch, else_branch: else_branch}
    {stmt, rest}
  end

  defp print_statement(tokens) do
    {value, rest} = expression(tokens)
    rest = consume(rest, :semicolon, "Expect ';' after value.")

    stmt = %Print{expression: value}
    {stmt, rest}
  end

  defp while_statement(tokens) do
    rest = consume(tokens, :left_paren, "Expect '(' after 'while'.")
    {condition, rest} = expression(rest)
    rest = consume(rest, :right_paren, "Expect ')' after condition.")

    {body, rest} = statement(rest)

    stmt = %While{condition: condition, body: body}
    {stmt, rest}
  end

  defp block(tokens, statements) do
    case tokens do
      [] ->
        raise ParserException,
          message: "Expect '}' after block.",
          tokens: tokens

      [%Token{type: :right_brace} | rest] ->
        statements = Enum.reverse(statements)
        {statements, rest}

      _ ->
        {:ok, stmt, rest} = declaration(tokens)
        block(rest, [stmt | statements])
    end
  end

  defp expression_statement(tokens) do
    {value, rest} = expression(tokens)
    rest = consume(rest, :semicolon, "Expect ';' after expression.")

    stmt = %Expression{expression: value}
    {stmt, rest}
  end

  defp expression(tokens) do
    assignment(tokens)
  end

  defp assignment(tokens) do
    {expr, rest} = or_(tokens)

    {expr, rest} =
      case rest do
        [%Token{type: :equal} | rest] ->
          {value, rest} = assignment(rest)

          case expr do
            %Variable{name: name, line: line} ->
              expr = %Assign{name: name, value: value, line: line}
              {expr, rest}

            _ ->
              raise ParserException, message: "Invalid assignment target.", tokens: rest
          end

        _ ->
          {expr, rest}
      end

    {expr, rest}
  end

  defp or_(tokens) do
    {expr, rest} = and_(tokens)
    or_inner(expr, rest)
  end

  defp or_inner(expr, tokens) do
    case tokens do
      [%Token{type: :or} | rest] ->
        {right, rest} = and_(rest)
        expr = %Logical{left: expr, operator: :or, right: right}
        or_inner(expr, rest)

      _ ->
        {expr, tokens}
    end
  end

  defp and_(tokens) do
    {expr, rest} = equality(tokens)
    and_inner(expr, rest)
  end

  defp and_inner(expr, tokens) do
    case tokens do
      [%Token{type: :and} | rest] ->
        {right, rest} = equality(rest)
        expr = %Logical{left: expr, operator: :and, right: right}
        and_inner(expr, rest)

      _ ->
        {expr, tokens}
    end
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

      [%Token{type: {:identifier, identifier}, line: line} | rest] ->
        expr = %Variable{name: identifier, line: line}
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

  defp synchronize(tokens) do
    case tokens do
      [] ->
        []

      [%Token{type: :semicolon} | rest] ->
        rest

      [%Token{type: type} | _rest]
      when type in [:class, :fun, :var, :for, :if, :while, :print, :return] ->
        tokens

      [_token | rest] ->
        synchronize(rest)
    end
  end

  defp consume(tokens, type, message) do
    case tokens do
      [%Token{type: ^type} | rest] -> rest
      _ -> raise ParserException, message: message, tokens: tokens
    end
  end
end
