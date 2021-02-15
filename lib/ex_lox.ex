defmodule ExLox do
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
    IO.puts(source)
  end
end
