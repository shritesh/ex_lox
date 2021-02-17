defmodule ExLox.Resolver do
  alias ExLox.Stmt
  alias ExLox.Expr.{Assign, Binary, Call, Grouping, Literal, Logical, Unary, Variable}
  alias ExLox.Stmt.{Block, Class, Expression, Function, If, Print, Return, Var, While}

  defmodule ResolverException do
    defexception [:message, :line]
  end

  @spec resolve(list(Stmt.t())) :: {:ok, list(Stmt.t())} | {:errors, ExLox.error()}
  def resolve(statements) do
    try do
      {statements, _scopes} = resolve(statements, {[], :none})
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

      %Class{name: name, methods: methods, line: line} ->
        scopes = scopes |> declare(name, line) |> define(name)

        {%Class{name: name, methods: methods, line: line}, scopes}

      %Expression{expression: expression} ->
        {expression, scopes} = resolve(expression, scopes)

        {%Expression{expression: expression}, scopes}

      %Function{name: name, params: params, body: body, line: line} ->
        scopes =
          scopes
          |> declare(name, line)
          |> define(name)

        # TODO: Extract resolve function

        {current_scopes, enclosing_function} = scopes
        scopes = {current_scopes, :function}

        scopes = begin_scope(scopes)

        scopes =
          Enum.reduce(params, scopes, fn name, scopes ->
            scopes
            |> declare(name, line)
            |> define(name)
          end)

        {body, scopes} = resolve(body, scopes)
        scopes = end_scope(scopes)

        {current_scopes, _current_function} = scopes
        scopes = {current_scopes, enclosing_function}

        {%Function{name: name, params: params, body: body, line: line}, scopes}

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

      %Return{value: value, line: line} ->
        {_current_scopes, current_function} = scopes

        if current_function == :none do
          raise ResolverException, message: "Can't return from top-level code.", line: line
        end

        {value, scopes} =
          if value do
            resolve(value, scopes)
          else
            {nil, scopes}
          end

        {%Return{value: value, line: line}, scopes}

      %Var{name: name, initializer: initializer, line: line} ->
        scopes = declare(scopes, name, line)

        {initializer, scopes} =
          if initializer do
            resolve(initializer, scopes)
          else
            {nil, scopes}
          end

        scopes = define(scopes, name)

        {%Var{name: name, initializer: initializer, line: line}, scopes}

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
        with {[locals | _rest], _current_function} <- scopes,
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

  defp resolve_distance({scopes, _}, name) do
    Enum.find_index(scopes, fn locals -> Map.has_key?(locals, name) end)
  end

  defp declare(scopes, name, line) do
    case scopes do
      {[], current_function} ->
        {[], current_function}

      {[locals | rest], current_function} ->
        if Map.has_key?(locals, name) do
          raise ResolverException,
            message: "Already variable with this name in this scope.",
            line: line
        end

        locals = Map.put(locals, name, :declared)
        {[locals | rest], current_function}
    end
  end

  defp define(scopes, name) do
    case scopes do
      {[], current_function} ->
        {[], current_function}

      {[locals | rest], current_function} ->
        locals = Map.put(locals, name, :defined)
        {[locals | rest], current_function}
    end
  end

  defp begin_scope({scopes, current_function}) do
    {[%{} | scopes], current_function}
  end

  defp end_scope({[_local | scopes], current_function}) do
    {scopes, current_function}
  end
end
