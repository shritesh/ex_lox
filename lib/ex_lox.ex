defmodule ExLox do
  alias ExLox.Scanner

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
    case Scanner.scan(source) do
      {:ok, tokens} -> IO.inspect(tokens)
      {:error, errors} -> Enum.each(errors, &print_error/1)
    end
  end

  defp print_error({line, message}) do
    IO.puts(:stderr, "[line #{line}] Error: #{message}")
  end
end
