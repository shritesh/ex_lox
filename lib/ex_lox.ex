defmodule ExLox do
  alias ExLox.{Parser, Scanner}

  @type error :: {non_neg_integer() | :eof, String.t()}

  def repl() do
    case IO.gets("> ") do
      :eof ->
        nil

      source ->
        run(source)
        repl()
    end
  end

  def run_file(filename) do
    source = File.read!(filename)

    run(source)
  end

  defp run(source) do
    with {:ok, tokens} <- Scanner.scan(source),
         {:ok, expr} <- Parser.parse(tokens) do
      IO.inspect(expr)
    else
      {:error, errors} when is_list(errors) ->
        Enum.each(errors, &print_error/1)

      {:error, error} ->
        print_error(error)
    end
  end

  defp print_error({:eof, message}) do
    IO.puts(:stderr, "[end of file] Error: #{message}")
  end

  defp print_error({line, message}) do
    IO.puts(:stderr, "[line #{line}] Error: #{message}")
  end
end
