defmodule ExLox.Resolver do
  alias ExLox.{Expr, Stmt}

  alias ExLox.Expr.{
    Assign,
    Binary,
    Call,
    Get,
    Grouping,
    Literal,
    Logical,
    Set,
    This,
    Unary,
    Variable
  }

  alias ExLox.Stmt.{Block, Class, Expression, Function, If, Print, Return, Var, While}

  defmodule ResolverException do
    defexception [:message, :line]
  end

  @type t :: %__MODULE__{
          scopes: list(%{optional(String.t()) => :declared | :defined}),
          current_function: :none | :function | :method | :initializer,
          current_class: :none | :class
        }
  defstruct [:scopes, :current_function, :current_class]

  @spec resolve(list(Stmt.t())) :: {:ok, list(Stmt.t())} | {:errors, ExLox.error()}
  def resolve(statements) do
    try do
      resolver = %__MODULE__{
        scopes: [],
        current_function: :none,
        current_class: :none
      }

      {statements, _resolver} = resolve(statements, resolver)
      {:ok, statements}
    rescue
      e in [ResolverException] ->
        error = {e.line, e.message}
        {:error, error}
    end
  end

  @spec resolve(Expr.t() | Stmt.t() | list(Stmt.t()), t()) ::
          {Expr.t() | Stmt.t() | list(Stmt.t()), t()}
  defp resolve(item, resolver) do
    case item do
      statements when is_list(statements) ->
        Enum.map_reduce(statements, resolver, &resolve/2)

      %Block{statements: statements} ->
        resolver = begin_scope(resolver)
        {statements, resolver} = resolve(statements, resolver)
        resolver = end_scope(resolver)

        {%Block{statements: statements}, resolver}

      %Class{name: name, methods: methods, line: line} ->
        enclosing_class = resolver.current_class

        resolver = %{resolver | current_class: :class}

        resolver =
          resolver
          |> declare(name, line)
          |> define(name)

        resolver =
          resolver
          |> begin_scope()
          |> define("this")

        {methods, resolver} =
          Enum.map_reduce(methods, resolver, fn function, resolver ->
            if function.name == "init" do
              resolve_function(resolver, function, :initializer)
            else
              resolve_function(resolver, function, :method)
            end
          end)

        resolver = end_scope(resolver)

        resolver = %{resolver | current_class: enclosing_class}

        {%Class{name: name, methods: methods, line: line}, resolver}

      %Expression{expression: expression} ->
        {expression, resolver} = resolve(expression, resolver)

        {%Expression{expression: expression}, resolver}

      %Function{name: name, line: line} = function ->
        resolver =
          resolver
          |> declare(name, line)
          |> define(name)

        resolve_function(resolver, function, :function)

      %If{condition: condition, then_branch: then_branch, else_branch: else_branch} ->
        {condition, resolver} = resolve(condition, resolver)
        {then_branch, resolver} = resolve(then_branch, resolver)

        {else_branch, resolver} =
          if else_branch do
            resolve(else_branch, resolver)
          else
            {nil, resolver}
          end

        {%If{condition: condition, then_branch: then_branch, else_branch: else_branch}, resolver}

      %Print{expression: expression} ->
        {expression, resolver} = resolve(expression, resolver)

        {%Print{expression: expression}, resolver}

      %Return{value: value, line: line} ->
        if resolver.current_function == :none do
          raise ResolverException, message: "Can't return from top-level code.", line: line
        end

        {value, resolver} =
          if value do
            if resolver.current_function == :initializer do
              raise ResolverException,
                message: "Can't return a value from an intializer.",
                line: line
            end

            resolve(value, resolver)
          else
            {nil, resolver}
          end

        {%Return{value: value, line: line}, resolver}

      %Var{name: name, initializer: initializer, line: line} ->
        resolver = declare(resolver, name, line)

        {initializer, resolver} =
          if initializer do
            resolve(initializer, resolver)
          else
            {nil, resolver}
          end

        resolver = define(resolver, name)

        {%Var{name: name, initializer: initializer, line: line}, resolver}

      %While{condition: condition, body: body} ->
        {condition, resolver} = resolve(condition, resolver)
        {body, resolver} = resolve(body, resolver)

        {%While{condition: condition, body: body}, resolver}

      %Assign{name: name, value: value, line: line} ->
        {value, resolver} = resolve(value, resolver)
        distance = resolve_distance(resolver, name)

        {%Assign{name: name, value: value, line: line, distance: distance}, resolver}

      %Binary{left: left, operator: operator, right: right, line: line} ->
        {left, resolver} = resolve(left, resolver)
        {right, resolver} = resolve(right, resolver)

        {%Binary{left: left, operator: operator, right: right, line: line}, resolver}

      %Call{callee: callee, arguments: arguments, line: line} ->
        {callee, resolver} = resolve(callee, resolver)
        {arguments, resolver} = Enum.map_reduce(arguments, resolver, &resolve/2)

        {%Call{callee: callee, arguments: arguments, line: line}, resolver}

      %Get{object: object, name: name, line: line} ->
        {object, resolver} = resolve(object, resolver)

        {%Get{object: object, name: name, line: line}, resolver}

      %Grouping{expression: expression} ->
        {expression, resolver} = resolve(expression, resolver)

        {%Grouping{expression: expression}, resolver}

      %Literal{value: value} ->
        {%Literal{value: value}, resolver}

      %Logical{left: left, operator: operator, right: right} ->
        {left, resolver} = resolve(left, resolver)
        {right, resolver} = resolve(right, resolver)

        {%Logical{left: left, operator: operator, right: right}, resolver}

      %Set{object: object, name: name, value: value, line: line} ->
        {value, resolver} = resolve(value, resolver)
        {object, resolver} = resolve(object, resolver)

        {%Set{object: object, name: name, value: value, line: line}, resolver}

      %This{line: line} ->
        if resolver.current_class == :none do
          raise ResolverException, message: "Can't use 'this' outside of a class.", line: line
        end

        distance = resolve_distance(resolver, "this")
        {%This{line: line, distance: distance}, resolver}

      %Unary{operator: operator, right: right} ->
        {right, resolver} = resolve(right, resolver)

        {%Unary{operator: operator, right: right}, resolver}

      %Variable{name: name, line: line} ->
        with [locals | _rest] <- resolver.scopes,
             :declared <- locals[name] do
          raise ResolverException,
            message: "Can't read local variable '#{name}' in its own initializer.",
            line: line
        else
          _ ->
            distance = resolve_distance(resolver, name)
            {%Variable{name: name, line: line, distance: distance}, resolver}
        end
    end
  end

  defp resolve_function(
         resolver,
         %Function{name: name, params: params, body: body, line: line},
         function_type
       ) do
    enclosing_function = resolver.current_function
    resolver = %{resolver | current_function: function_type}

    resolver = begin_scope(resolver)

    resolver =
      Enum.reduce(params, resolver, fn name, resolver ->
        resolver
        |> declare(name, line)
        |> define(name)
      end)

    {body, resolver} = resolve(body, resolver)
    resolver = end_scope(resolver)

    resolver = %{resolver | current_function: enclosing_function}
    {%Function{name: name, params: params, body: body, line: line}, resolver}
  end

  defp resolve_distance(resolver, name) do
    Enum.find_index(resolver.scopes, fn locals -> Map.has_key?(locals, name) end)
  end

  defp declare(resolver, name, line) do
    case resolver.scopes do
      [] ->
        resolver

      [locals | rest] ->
        if Map.has_key?(locals, name) do
          raise ResolverException,
            message: "Already variable with this name in this scope.",
            line: line
        end

        locals = Map.put(locals, name, :declared)
        %{resolver | scopes: [locals | rest]}
    end
  end

  @spec define(t(), String.t()) :: t()
  defp define(resolver, name) do
    case resolver.scopes do
      [] ->
        resolver

      [locals | rest] ->
        locals = Map.put(locals, name, :defined)
        %{resolver | scopes: [locals | rest]}
    end
  end

  @spec begin_scope(t()) :: t()
  defp begin_scope(resolver) do
    %{resolver | scopes: [%{} | resolver.scopes]}
  end

  @spec end_scope(t()) :: t()
  defp end_scope(resolver) do
    [_local | scopes] = resolver.scopes
    %{resolver | scopes: scopes}
  end
end
