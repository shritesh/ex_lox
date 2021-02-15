defmodule ExLox.Resolver do
  alias ExLox.Stmt
  alias ExLox.Stmt.{Block, Expression, Function, If, Print, Return, Var, While}
  alias ExLox.Expr.{Assign, Binary, Call, Grouping, Literal, Logical, Unary, Variable}

  defmodule ResolverException do
    defexception [:message, :line]
  end

  @spec resolve(list(Stmt.t())) :: {:ok, list(Stmt.t())} | {:error, ExLox.error()}
  def resolve(statements) do
    try do
      {statements, _scopes} = resolve(statements, [])
      {:ok, statements}
    rescue
      e in [ResolverException] ->
        error = {e.line, e.message}
        {:error, error}
    end
  end

  defp resolve(item, scopes) do
    case item do
      statements when is_list(statements) ->
        Enum.map_reduce(statements, scopes, &resolve/2)

      %Block{statements: statements} ->
        scopes = begin_scope(scopes)
        {statements, scopes} = resolve(statements, scopes)
        scopes = end_scope(scopes)

        {%Block{statements: statements}, scopes}

      %Expression{expression: expression} ->
        {expression, scopes} = resolve(expression, scopes)

        {%Expression{expression: expression}, scopes}

      %Function{name: name, params: params, body: body} ->
        scopes =
          scopes
          |> declare(name)
          |> define(name)

        scopes = begin_scope(scopes)

        scopes =
          Enum.reduce(params, scopes, fn name, scopes ->
            scopes
            |> declare(name)
            |> define(name)
          end)

        {body, scopes} = resolve(body, scopes)
        scopes = end_scope(scopes)

        {%Function{name: name, params: params, body: body}, scopes}

      %If{condition: condition, then_branch: then_branch, else_branch: else_branch} ->
        {condition, scopes} = resolve(condition, scopes)
        {then_branch, scopes} = resolve(then_branch, scopes)

        {else_branch, scopes} =
          if else_branch do
            resolve(else_branch, scopes)
          else
            {nil, scopes}
          end

        {%If{condition: condition, then_branch: then_branch, else_branch: else_branch}, scopes}

      %Print{expression: expression} ->
        {expression, scopes} = resolve(expression, scopes)

        {%Print{expression: expression}, scopes}

      %Return{value: value} ->
        {value, scopes} =
          if value do
            resolve(value, scopes)
          else
            {nil, scopes}
          end

        {%Return{value: value}, scopes}

      %Var{name: name, initializer: initializer} ->
        scopes = declare(scopes, name)

        {initializer, scopes} =
          if initializer do
            resolve(initializer, scopes)
          else
            {nil, scopes}
          end

        scopes = define(scopes, name)

        {%Var{name: name, initializer: initializer}, scopes}

      %While{condition: condition, body: body} ->
        {condition, scopes} = resolve(condition, scopes)
        {body, scopes} = resolve(body, scopes)

        {%While{condition: condition, body: body}, scopes}

      %Assign{name: name, value: value, line: line} ->
        {value, scopes} = resolve(value, scopes)
        distance = resolve_distance(scopes, name)

        {%Assign{name: name, value: value, line: line, distance: distance}, scopes}

      %Binary{left: left, operator: operator, right: right, line: line} ->
        {left, scopes} = resolve(left, scopes)
        {right, scopes} = resolve(right, scopes)

        {%Binary{left: left, operator: operator, right: right, line: line}, scopes}

      %Call{callee: callee, arguments: arguments, line: line} ->
        {callee, scopes} = resolve(callee, scopes)
        {arguments, scopes} = Enum.map_reduce(arguments, scopes, &resolve/2)

        {%Call{callee: callee, arguments: arguments, line: line}, scopes}

      %Grouping{expression: expression} ->
        {expression, scopes} = resolve(expression, scopes)

        {%Grouping{expression: expression}, scopes}

      %Literal{value: value} ->
        {%Literal{value: value}, scopes}

      %Logical{left: left, operator: operator, right: right} ->
        {left, scopes} = resolve(left, scopes)
        {right, scopes} = resolve(right, scopes)

        {%Logical{left: left, operator: operator, right: right}, scopes}

      %Unary{operator: operator, right: right} ->
        {right, scopes} = resolve(right, scopes)

        {%Unary{operator: operator, right: right}, scopes}

      %Variable{name: name, line: line} ->
        with [locals | _rest] <- scopes,
             :declared <- locals[name] do
          raise ResolverException,
            message: "Can't read local variable '#{name}' in its own initializer.",
            line: line
        else
          _ ->
            distance = resolve_distance(scopes, name)
            {%Variable{name: name, line: line, distance: distance}, scopes}
        end
    end
  end

  defp resolve_distance(scopes, name) do
    Enum.find_index(scopes, fn locals -> Map.has_key?(locals, name) end)
  end

  defp declare(scopes, name) do
    case scopes do
      [] ->
        []

      [locals | rest] ->
        locals = Map.put(locals, name, :declared)
        [locals | rest]
    end
  end

  defp define(scopes, name) do
    case scopes do
      [] ->
        []

      [locals | rest] ->
        locals = Map.put(locals, name, :defined)
        [locals | rest]
    end
  end

  defp begin_scope(scopes) do
    [%{} | scopes]
  end

  defp end_scope([_local | scopes]) do
    scopes
  end
end
