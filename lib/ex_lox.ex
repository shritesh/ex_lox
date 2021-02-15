defmodule ExLox do
  alias ExLox.{Interpreter, Parser, Resolver, Scanner}

  @type error :: {non_neg_integer() | :eof, String.t()}

  def repl(interpreter \\ Interpreter.new()) do
    case IO.gets("> ") do
      :eof ->
        nil

      source ->
        interpreter = run(interpreter, source)
        repl(interpreter)
    end
  end

  def run_file(filename) do
    source = File.read!(filename)

    run(Interpreter.new(), source)
  end

  defp run(interpreter, source) do
    with {:ok, tokens} <- Scanner.scan(source),
         {:ok, statements} <- Parser.parse(tokens),
         {:ok, statements} <- Resolver.resolve(statements),
         {:ok, interpreter} <- Interpreter.interpret(interpreter, statements) do
      interpreter
    else
      {:error, errors} when is_list(errors) ->
        Enum.each(errors, &print_error/1)
        interpreter

      {:error, error} ->
        print_error(error)
        interpreter
    end
  end

  defp print_error({:eof, message}) do
    IO.puts(:stderr, "[end of file] Error: #{message}")
  end

  defp print_error({line, message}) do
    IO.puts(:stderr, "[line #{line}] Error: #{message}")
  end
end
