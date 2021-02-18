defmodule ExLoxTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  describe "examples" do
    for filename <- Path.wildcard("test/examples/*.lox") do
      @filename filename

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
