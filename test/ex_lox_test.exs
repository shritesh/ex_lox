defmodule ExLoxTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  for filename <- File.ls!("test/cases") do
    @filename "test/cases/" <> filename

    if String.ends_with?(@filename, ".lox") do
      test "#{filename}" do
        expectation =
          @filename
          |> String.replace_suffix(".lox", ".txt")
          |> File.read!()

        assert capture_io(fn -> ExLox.run_file(@filename) end) == expectation
      end
    end
  end
end
