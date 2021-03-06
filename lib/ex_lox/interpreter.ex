defmodule ExLox.Interpreter do
  alias __MODULE__
  alias ExLox.{Environment, Expr, Func, Instance, Klass, MutableMap, Stmt}

  alias ExLox.Expr.{
    Assign,
    Binary,
    Call,
    Get,
    Grouping,
    Literal,
    Logical,
    Set,
    Super,
    This,
    Unary,
    Variable
  }

  alias ExLox.Stmt.{Block, Class, Expression, Function, If, Print, Return, Var, While}

  @type t :: %Interpreter{env: Environment.t(), globals: Environment.t()}
  @enforce_keys [:env, :globals]
  defstruct [:env, :globals]

  @spec new :: t()
  def new do
    MutableMap.init()

    globals = Environment.new()
    Environment.define(globals, "clock", fn -> System.os_time(:millisecond) / 1000.0 end)

    Environment.define(globals, "char", fn ->
      input = IO.getn("")
      if is_binary(input), do: input
    end)

    Environment.define(globals, "string", fn ->
      input = IO.gets("")
      if is_binary(input), do: String.replace_suffix(input, "\n", "")
    end)

    Environment.define(globals, "number", fn ->
      with input when is_binary(input) <- IO.gets(""),
           {number, _} <- Float.parse(input) do
        number
      else
        _ -> nil
      end
    end)

    %Interpreter{
      globals: globals,
      env: globals
    }
  end

  defmodule RuntimeException do
    defexception [:message, :line]
  end

  @spec interpret(t(), list(Stmt.t())) :: {:ok, t()} | {:error, ExLox.error()}
  def interpret(interpreter, statements) do
    try do
      interpreter = Enum.reduce(statements, interpreter, &execute/2)
      {:ok, interpreter}
    rescue
      e in [RuntimeException] ->
        {:error, {e.line, e.message}}
    end
  end

  @spec execute(Stmt.t(), t()) :: t()
  defp execute(stmt, interpreter) do
    case stmt do
      %Block{statements: statements} ->
        execute_block(statements, Environment.from(interpreter.env), interpreter)
        interpreter

      %Expression{expression: expression} ->
        {_, interpreter} = evaluate(expression, interpreter)
        interpreter

      %Function{name: name, params: params, body: body} ->
        func = %Func{params: params, body: body, closure: interpreter.env, initializer?: false}
        Environment.define(interpreter.env, name, func)
        interpreter

      %If{condition: condition, then_branch: then_branch, else_branch: else_branch} ->
        {condition, interpreter} = evaluate(condition, interpreter)

        cond do
          truthy?(condition) -> execute(then_branch, interpreter)
          else_branch -> execute(else_branch, interpreter)
          true -> interpreter
        end

      %Class{name: name, superclass: superclass, methods: methods} ->
        {superclass, interpreter} =
          if superclass do
            case evaluate(superclass, interpreter) do
              {%Klass{} = superclass, interpreter} ->
                env = Environment.from(interpreter.env)
                Environment.define(env, "super", superclass)
                interpreter = %{interpreter | env: env}
                {superclass, interpreter}

              _ ->
                raise RuntimeException,
                  message: "Superclass must be a class.",
                  line: superclass.line
            end
          else
            {nil, interpreter}
          end

        methods =
          Enum.into(methods, %{}, fn %Function{name: name, params: params, body: body} ->
            {name,
             %Func{
               params: params,
               body: body,
               closure: interpreter.env,
               initializer?: name == "init"
             }}
          end)

        interpreter =
          if superclass do
            %{interpreter | env: interpreter.env.enclosing}
          else
            interpreter
          end

        klass = %Klass{name: name, methods: methods, superklass: superclass}
        Environment.define(interpreter.env, name, klass)
        interpreter

      %Print{expression: expression} ->
        {value, interpreter} = evaluate(expression, interpreter)

        value
        |> stringify()
        |> IO.puts()

        interpreter

      %Return{value: value} ->
        {value, interpreter} =
          if value do
            evaluate(value, interpreter)
          else
            {nil, interpreter}
          end

        throw({value, interpreter})

      %Var{name: name, initializer: nil} ->
        Environment.define(interpreter.env, name, nil)
        interpreter

      %Var{name: name, initializer: initializer} ->
        {value, interpreter} = evaluate(initializer, interpreter)
        Environment.define(interpreter.env, name, value)
        interpreter

      %While{condition: condition, body: body} = stmt ->
        {result, interpreter} = evaluate(condition, interpreter)

        if truthy?(result) do
          interpreter = execute(body, interpreter)
          execute(stmt, interpreter)
        else
          interpreter
        end
    end
  end

  @spec execute_block(list(Stmt.t()), Environment.t(), t()) :: t()
  defp execute_block(statements, env, interpreter) do
    interpreter = %{interpreter | env: env}
    Enum.reduce(statements, interpreter, &execute/2)
  end

  @spec evaluate(Expr.t(), t()) :: {any(), t()}
  defp evaluate(expr, interpreter) do
    case expr do
      %Assign{name: name, value: value, line: line, distance: distance} ->
        {value, interpreter} = evaluate(value, interpreter)

        result =
          if distance do
            Environment.assign_at(interpreter.env, distance, name, value)
          else
            Environment.assign(interpreter.globals, name, value)
          end

        case result do
          :ok ->
            {value, interpreter}

          :error ->
            raise RuntimeException,
              message: "Undefined variable '#{name}'.",
              line: line
        end

      %Binary{operator: operator, left: left, right: right, line: line} ->
        {left, interpreter} = evaluate(left, interpreter)
        {right, interpreter} = evaluate(right, interpreter)

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

        {result, interpreter}

      %Call{callee: callee, arguments: arguments, line: line} ->
        {callee, interpreter} = evaluate(callee, interpreter)
        {arguments, interpreter} = Enum.map_reduce(arguments, interpreter, &evaluate/2)

        case callee do
          native_fn when is_function(native_fn, length(arguments)) ->
            result = apply(native_fn, arguments)
            {result, interpreter}

          native_fn when is_function(native_fn) ->
            {:arity, arity} = Elixir.Function.info(native_fn, :arity)

            raise RuntimeException,
              message: "Expected #{arity} arguments but got #{length(arguments)}.",
              line: line

          %Func{params: params} when length(params) == length(arguments) ->
            call(callee, arguments, interpreter)

          %Func{params: params} ->
            raise RuntimeException,
              message: "Expected #{length(params)} arguments but got #{length(arguments)}.",
              line: line

          %Klass{} ->
            if Klass.arity(callee) != length(arguments) do
              raise RuntimeException,
                message:
                  "Expected #{Klass.arity(callee)} arguments but got #{length(arguments)}.",
                line: line
            end

            call(callee, arguments, interpreter)

          _ ->
            raise RuntimeException,
              message: "Can only call functions and classes.",
              line: line
        end

      %Get{object: object, name: name, line: line} ->
        {object, interpreter} = evaluate(object, interpreter)

        case object do
          %Instance{} ->
            case Instance.get(object, name) do
              {:ok, value} ->
                {value, interpreter}

              :error ->
                raise RuntimeException, message: "Undefined property '#{name}'.", line: line
            end

          _ ->
            raise RuntimeException, message: "Only instances have properties.", line: line
        end

      %Grouping{expression: expr} ->
        evaluate(expr, interpreter)

      %Literal{value: value} ->
        {value, interpreter}

      %Logical{left: left, operator: operator, right: right} ->
        {left, interpreter} = evaluate(left, interpreter)

        case {operator, truthy?(left)} do
          {:or, true} -> {left, interpreter}
          {:and, false} -> {left, interpreter}
          {_, _} -> evaluate(right, interpreter)
        end

      %Set{object: object, name: name, value: value, line: line} ->
        {object, interpreter} = evaluate(object, interpreter)

        case object do
          %Instance{} ->
            {value, interpreter} = evaluate(value, interpreter)
            Instance.set(object, name, value)
            {value, interpreter}

          _ ->
            raise RuntimeException, message: "Only instances have fields", line: line
        end

      %Super{line: line, method: method, distance: distance} ->
        {:ok, superclass} = Environment.get_at(interpreter.env, distance, "super")
        {:ok, object} = Environment.get_at(interpreter.env, distance - 1, "this")

        case Klass.find_method(superclass, method) do
          nil -> raise RuntimeException, message: "Undefined property '#{method}'.", line: line
          method -> {Func.bind(method, object), interpreter}
        end

      %This{line: line, distance: distance} ->
        lookup_variable(interpreter, "this", line, distance)

      %Unary{operator: :not, right: right} ->
        {expr, interpreter} = evaluate(right, interpreter)
        {!truthy?(expr), interpreter}

      %Unary{operator: :neg, right: right} ->
        {expr, interpreter} = evaluate(right, interpreter)
        {-expr, interpreter}

      %Variable{name: name, line: line, distance: distance} ->
        lookup_variable(interpreter, name, line, distance)
    end
  end

  @spec lookup_variable(t(), String.t(), non_neg_integer(), nil | integer()) :: {any(), t()}
  defp lookup_variable(interpreter, name, line, distance) do
    result =
      if distance do
        Environment.get_at(interpreter.env, distance, name)
      else
        Environment.get(interpreter.globals, name)
      end

    case result do
      {:ok, val} ->
        {val, interpreter}

      :error ->
        raise RuntimeException,
          message: "Undefined variable '#{name}'.",
          line: line
    end
  end

  @spec call(Klass.t(), list(any()), t()) :: {any(), t()}
  defp call(%Klass{} = klass, args, interpreter) do
    instance = Instance.new(klass)

    if initializer = Klass.find_method(klass, "init") do
      Func.bind(initializer, instance)
      |> call(args, interpreter)
    end

    {instance, interpreter}
  end

  @spec call(Func.t(), list(any()), t()) :: {any(), t()}
  defp call(%Func{} = func, args, interpreter) do
    env = Environment.from(func.closure)

    Enum.zip(func.params, args)
    |> Enum.each(fn {name, arg} ->
      Environment.define(env, name, arg)
    end)

    try do
      execute_block(func.body, env, interpreter)

      if func.initializer? do
        {:ok, this} = Environment.get_at(func.closure, 0, "this")
        {this, interpreter}
      else
        {nil, interpreter}
      end
    catch
      {value, _} ->
        if func.initializer? do
          {:ok, this} = Environment.get_at(func.closure, 0, "this")
          {this, interpreter}
        else
          {value, interpreter}
        end
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
  defp stringify(fun) when is_function(fun), do: "<fn>"
  defp stringify(%Func{params: params}), do: "<fn/#{length(params)}>"
  defp stringify(%Klass{name: name}), do: name
  defp stringify(%Instance{klass: klass}), do: "#{stringify(klass)} instance"
  defp stringify(obj), do: to_string(obj)
end
